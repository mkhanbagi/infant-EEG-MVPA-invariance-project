function cfg = parse_varargin(cfg, varargin)
% PARSE_VARARGIN - Update configuration struct with name-value pairs
%
% This function updates fields of a configuration struct (cfg) based on
% name-value pairs passed via varargin. It provides a flexible way to
% override default configuration values when calling functions.
%
% Only existing fields in cfg can be updated. Attempting to set a non-existent
% field will throw an error to prevent typos and maintain config structure.
%
% Inputs:
%   cfg      - Struct containing default configuration parameters
%              Must have pre-defined fields to be updated
%   
%   varargin - Variable-length list of name-value pairs
%              Format: 'fieldname1', value1, 'fieldname2', value2, ...
%              Field names must be strings matching existing cfg fields
%
% Output:
%   cfg - Updated configuration struct with modified field values
%
% Error Conditions:
%   - Throws error if attempting to set a field that doesn't exist in cfg
%   - Throws error if varargin has odd length (unpaired name-value)
%
% Usage Examples:
%   % Initialize config with defaults
%   cfg = struct();
%   cfg.project_path = '';
%   cfg.downsample = 500;
%   cfg.HighPass = 0.1;
%   cfg.LowPass = 40;
%   
%   % Update specific fields
%   cfg = parse_varargin(cfg, 'project_path', '/data/project', 'downsample', 250);
%   % Result: cfg.project_path = '/data/project', cfg.downsample = 250
%   
%   % Attempt to set non-existent field (will error)
%   cfg = parse_varargin(cfg, 'unknown_field', 123);
%   % Error: Unknown parameter: unknown_field
%
% Common Use Case:
%   function result = my_analysis(cfg, varargin)
%       % Allow user to override config defaults
%       cfg = parse_varargin(cfg, varargin{:});
%       % Continue with analysis using updated cfg
%       ...
%   end
%
% Notes:
%   - Field names are case-sensitive
%   - Values can be any MATLAB data type
%   - Original cfg structure is preserved (only specified fields updated)
%   - Empty varargin is handled gracefully (cfg returned unchanged)
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/07/2025]
% Modified: [13/10/2025]


%% ===================================================================
%  PARSE NAME-VALUE PAIRS
%  ===================================================================

% Only process if name-value pairs were provided
if ~isempty(varargin)
    
    % Loop through varargin in steps of 2 (name-value pairs)
    % k points to each parameter name, k+1 points to its value
    for k = 1:2:length(varargin)
        
        % --- Extract parameter name and value ---
        param_name = varargin{k};      % Field name to update
        param_value = varargin{k+1};   % New value for the field
        
        % --- Validate that field exists in cfg ---
        if isfield(cfg, param_name)
            % Field exists: update with new value
            cfg.(param_name) = param_value;
            
        else
            % Field doesn't exist: throw error to prevent typos
            % This catches mistakes like 'downsample' vs 'downsampling'
            error('Unknown parameter: %s. Check spelling and ensure field exists in cfg.', ...
                  param_name);
        end
    end
    
else
    % No parameters provided - return cfg unchanged
    % This is not an error, just means no overrides requested
end

end