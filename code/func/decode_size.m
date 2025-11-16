function ds = decode_size(ds, config, mode)
% DECODE_SIZE - Assign target and chunk labels for size decoding analysis
%
% This function prepares a dataset for size-based decoding by assigning
% appropriate target labels (size classes) and chunks (cross-validation folds).
% It supports both 2-class (small vs. large) and 3-class (small, medium, large)
% size decoding.
%
% Inputs:
%   ds     - CoSMoMVPA dataset structure with sample attributes:
%            .sa.stimnum  : Stimulus numbers for each sample
%            .sa.blocknum : Block numbers for each sample
%   
%   config - Configuration struct containing:
%            .participants_info.subjectnr : Current subject number
%            .participants_info.isgood    : Valid blocks per subject
%            .stimnum.size                : Size values for each stimulus number
%   
%   mode   - String specifying classification mode:
%            '2class' : Binary classification (small vs. large only)
%            '3class' : Three-way classification (small, medium, large)
%
% Output:
%   ds - Updated dataset with assigned labels:
%        .sa.targets : Size class labels (1, 2, or 3)
%        .sa.chunks  : Block numbers for cross-validation
%        For '2class' mode, dataset is also sliced to include only
%        small and large stimuli (medium size excluded)
%
% Size Classification:
%   - Stimuli are grouped by their physical size property
%   - Size values are extracted from config.stimnum.size
%   - Labels are assigned: 1 = smallest, 2 = medium, 3 = largest
%   - For 2-class: only smallest and largest are retained
%
% Example:
%   % For 2-class size decoding (small vs. large)
%   ds_size = decode_size(ds, cfg, '2class');
%   
%   % For 3-class size decoding (small vs. medium vs. large)
%   ds_size = decode_size(ds, cfg, '3class');
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [22/07/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  EXTRACT CONFIGURATION PARAMETERS
%  ===================================================================
% --- Extract subject number ---
[tf, ~, subjectnr] = hasFieldDeep(config, 'subjectnr');
if tf
    subjectnr = subjectnr{1};
end

% --- Extract valid blocks for this subject ---
[tf, ~, blocks] = hasFieldDeep(config, 'isgood');
if tf
    blocks = blocks{1};
end


%% ===================================================================
%  DETERMINE VALID BLOCKS
%  ===================================================================

% Handle both cell array (multiple subjects) and numeric array (single subject)
if iscell(blocks)
    % Multiple subjects: extract blocks for current subject
    blocks_incl = blocks{subjectnr};
elseif isnumeric(blocks)
    % Single subject or already extracted
    blocks_incl = blocks;
end


%% ===================================================================
%  LOAD SUBJECT INFO AND EXTRACT SIZE INFORMATION
%  ===================================================================

[ds_orig, size_stimnum] = load_subject_data(config, subjectnr);

if isfield(config.decode_type, 'preprocess_func') && ~isempty(config.decode_type.preprocess_func)
    preproc_func = config.decode_type.preprocess_func;
    ds_orig = preproc_func(ds_orig, config);
end

%% ===================================================================
%  EXTRACT SIZE INFORMATION FOR VALID BLOCKS
%  ===================================================================

% Find which samples belong to valid blocks
% Uses logical indexing to create a mask
mask_blocks = ismember(ds_orig.sa.blocknum, blocks_incl);

% Extract size information only for samples in valid blocks
size_info = size_stimnum(mask_blocks);

%% ===================================================================
%  ASSIGN SIZE CLASS LABELS
%  ===================================================================

% Get unique size values present in the data
% Example: [1, 2, 3] for small, medium, large
size_values = unique(size_info);

% Create numeric labels for each size class
% 1 = first size, 2 = second size, 3 = third size
size_labels = 1:length(size_values);

% Initialize target labels vector (same length as dataset)
target_labels = zeros(size(ds.sa.stimnum));

% Assign class labels based on size values
% Loop through each unique size and assign corresponding label
for i = 1:numel(size_values)
    % Find all samples with current size value
    size_match = (size_info == size_values(i));
    
    % Assign label to matching samples
    target_labels(size_match) = size_labels(i);
end

%% ===================================================================
%  UPDATE DATASET WITH LABELS
%  ===================================================================

% Assign target labels (size classes) to dataset
ds.sa.targets = target_labels;

% Assign chunks (block numbers) for cross-validation
% Each block becomes a separate fold in cross-validation
ds.sa.chunks = ds.sa.blocknum;

%% ===================================================================
%  MODE-SPECIFIC PROCESSING
%  ===================================================================

if strcmp(mode, '2class')
    % --- 2-Class Mode: Binary classification (small vs. large) ---
    % Exclude medium-sized stimuli to create clear separation
    
    % Identify smallest and largest size values
    small = min(size_values);  % Smallest size in the dataset
    large = max(size_values);  % Largest size in the dataset
    
    % Create logical index for stimuli that are either small OR large
    % Addition of logical arrays works like OR operation
    size_idx = ismember(size_info, small) + ismember(size_info, large);
    
    % Slice dataset to include only small and large stimuli
    % This removes medium-sized stimuli from the analysis
    ds = cosmo_slice(ds, logical(size_idx));
    
    fprintf('[INFO] 2-class size decoding: %d samples retained (small + large only)\n', ...
            size(ds.samples, 1));
    
elseif strcmp(mode, '3class')
    % --- 3-Class Mode: Three-way classification ---
    % No slicing needed - all size categories are retained
    fprintf('[INFO] 3-class size decoding: %d samples (all size categories)\n', ...
            size(ds.samples, 1));
else
    % Unknown mode specified
    error('Mode must be either ''2class'' or ''3class''');
end

end