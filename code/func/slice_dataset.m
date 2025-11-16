function ds = slice_dataset(ds, slice_method, criteria)
% SLICE_DATASET - Slice CoSMoMVPA dataset by trials or blocks
%
% This function extracts a subset of samples from a CoSMoMVPA dataset based
% on either trial indices or block numbers. It's commonly used to include
% only valid trials/blocks in the analysis or to exclude bad data.
%
% Inputs:
%   ds           - CoSMoMVPA dataset structure with sample attributes:
%                  .sa.stimnum  : Stimulus number for each sample
%                  .sa.blocknum : Block number for each sample
%                  .samples     : Data matrix (samples × features)
%   
%   slice_method - String specifying slicing method:
%                  'trials' : Slice based on trial/stimulus numbers
%                  'blocks' : Slice based on block numbers
%   
%   criteria     - Slicing criteria (format depends on slice_method):
%                  
%                  For 'trials' method:
%                    - Scalar: Keeps all samples where stimnum <= criteria
%                              Example: 64 → keeps stimnum 1-64
%                    - Vector: Keeps samples at specified indices
%                              Example: [10:50] → keeps samples 10-50
%                  
%                  For 'blocks' method:
%                    - Cell array: Must contain vector of block numbers
%                                  Example: {[1, 2, 5]} → keeps blocks 1, 2, 5
%                    Note: Requires cell array format (user-unfriendly but
%                          necessary for current implementation)
%
% Output:
%   ds - Sliced CoSMoMVPA dataset containing only selected samples
%        All dataset fields are properly updated (samples, sa, fa)
%
% Usage Examples:
%   % Keep all stimuli up to stimulus 64
%   ds = slice_dataset(ds, 'trials', 64);
%   
%   % Keep specific trial range (samples 100-300)
%   ds = slice_dataset(ds, 'trials', 100:300);
%   
%   % Keep only samples from blocks 1, 2, and 3
%   % Note: Must use cell array format for blocks
%   ds = slice_dataset(ds, 'blocks', {[1, 2, 3]});
%   
%   % Keep only valid blocks for current subject
%   valid_blocks = cfg.participants_info.isgood{subjectnr};
%   ds = slice_dataset(ds, 'blocks', {valid_blocks});
%
% Common Use Cases:
%   - Exclude bad blocks identified during preprocessing
%   - Limit analysis to specific stimulus range
%   - Extract subset of trials for cross-validation
%   - Remove practice trials or outliers
%
% Notes:
%   - Uses CoSMoMVPA's cosmo_slice internally (preserves all metadata)
%   - 'blocks' method requires cell array (not a plain vector)
%   - Empty result possible if criteria don't match any samples
%
% See also: COSMO_SLICE, COSMO_REMOVE_USELESS_DATA
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [21/07/2025]
% Modified: [13/10/2025]


%% ===================================================================
%  SLICE BY METHOD
%  ===================================================================

switch slice_method
    
    % -----------------------------------------------------------------
    % METHOD 1: SLICE BY TRIALS/STIMULUS NUMBERS
    % -----------------------------------------------------------------
    case 'trials'
        
        if isscalar(criteria)
            % --- Case 1a: Threshold slicing ---
            % Keep all samples where stimulus number <= criteria
            % 
            % Example: criteria = 64
            %   Keeps: stimnum 1, 2, 3, ..., 64
            %   Removes: stimnum > 64 (if any exist)
            %
            % Useful for: Limiting to standard stimulus set size
            ds = cosmo_slice(ds, ds.sa.stimnum <= criteria);
            
        elseif isnumeric(criteria)
            % --- Case 1b: Index-based slicing ---
            % Keep samples at specific indices in criteria vector
            %
            % Example: criteria = [10, 15, 20:30, 45]
            %   Keeps: samples at positions 10, 15, 20-30, 45
            %
            % Useful for: Selecting specific trial subset, removing outliers
            ds = cosmo_slice(ds, criteria);
            
        else
            % Invalid criteria type for trials method
            error('Invalid criteria for ''trials'': must be scalar or numeric vector.');
        end
        
    % -----------------------------------------------------------------
    % METHOD 2: SLICE BY BLOCK NUMBERS
    % -----------------------------------------------------------------
    case 'blocks'
        
        if iscell(criteria)
            % --- Keep samples belonging to specified blocks ---
            % Note: Requires cell array format: {[block1, block2, ...]}
            %       This is somewhat user-unfriendly but matches current API
            %
            % Example: criteria = {[1, 2, 5]}
            %   Keeps: all samples where blocknum is 1, 2, or 5
            %   Removes: samples from all other blocks
            %
            % Useful for: Excluding bad blocks identified during preprocessing
            ds = cosmo_slice(ds, ismember(ds.sa.blocknum, criteria{1,1}));
            
        else
            % Criteria must be cell array for blocks method
            % Note: Error message says "must be a cell array" but doesn't
            %       explain the specific format {[...]}
            error('Invalid criteria for ''blocks'': must be a cell array.');
        end
        
    % -----------------------------------------------------------------
    % INVALID METHOD
    % -----------------------------------------------------------------
    otherwise
        % Unknown slice method specified
        % Note: Error message says "Invalid criteria" but is actually
        %       checking slice_method, not criteria parameter
        error('Invalid slice_method: must be ''trials'' or ''blocks''.');
end

end