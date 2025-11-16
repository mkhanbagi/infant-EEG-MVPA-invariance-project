function results = run_decoding_viewpoint(ds, cfg, varargin)
% RUN_DECODING_VIEWPOINT - Execute MVPA decoding analyses on EEG dataset
%
% This function runs multivariate pattern analysis (MVPA) decoding on a 
% CoSMoMVPA dataset. It can run multiple decoding types (e.g., category, 
% identity) and versions (e.g., train/test configurations) either automatically
% based on the config file or selectively based on user input.
%
% Inputs:
%   ds       - CoSMoMVPA dataset structure containing EEG data
%   cfg      - Configuration struct from viewpoint_decoding_config()
%   varargin - Optional name-value pairs:
%              'type'    : Cell array of decoding types to run (e.g., {'category'})
%              'version' : String specifying version to run (e.g., 'all_all')
%
% Output:
%   results  - Cell array containing decoding results for each analysis
%
% Usage Examples:
%   results = run_decoding_viewpoint(ds, cfg);                          % Run all analyses
%   results = run_decoding_viewpoint(ds, cfg, 'type', {'category'});    % Run specific type
%   results = run_decoding_viewpoint(ds, cfg, 'version', 'all_all');    % Run specific version
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [09/09/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  PARSE OPTIONAL INPUTS
%  ===================================================================

p = inputParser;
addParameter(p, 'type', '', @iscell);      % Specific decoding type(s) to run
addParameter(p, 'version', '', @ischar);   % Specific version to run
parse(p, varargin{:});

type    = p.Results.type;     % Decoding type (e.g., 'category', 'identity')
version = p.Results.version;  % Analysis version (e.g., 'all_all', 'intact_intact')

%% ===================================================================
%  EXTRACT PARTICIPANT INFORMATION
%  ===================================================================

% Get participant group name (e.g., 'infants' or 'adults')
group = cfg.participants_info.name;

% Get current subject number being processed
subjectnr = cfg.participants_info.subjectnr;

%% ===================================================================
%  DETERMINE WHICH ANALYSES TO RUN
%  ===================================================================

% Initialize results cell array
results = {};

% --- Case 1: Run all decoding types and versions from config file ---
if isempty(type)
    % Get all available decoding types from config
    types = {cfg.decode_type.name};
    
    % Determine which versions to run
    if ~isfield(cfg, 'current_version') || isempty(cfg.current_version)
        versions = cfg.versions_to_run;  % Use default versions from config
    else
        versions = cfg.current_version;  % Use specified current version
    end

% --- Case 2: Run specific decoding type(s) provided by user ---
else
    types = type;  % Use user-specified type(s)
    
    % Determine versions for the specified type
    if isempty(version)
        if ~isfield(cfg, 'current_version') || isempty(cfg.current_version)
            versions = cfg.versions_to_run;
        else
            versions = cfg.current_version;
        end
    else
        versions = {version};  % Use user-specified version
    end
end

%% ===================================================================
%  GENERATE ALL TYPE-VERSION COMBINATIONS
%  ===================================================================

% Initialize combinations cell array
% Each combination will be formatted as: 'decodetype_train_test'
% Example: 'category_all_all', 'identity_intact_occl'
combinations = {};

% Loop through each decoding type
for i = 1:length(types)
    current_type = types{i};
    
    % Special case: For types other than category/identity, use 'one_block_out'
    % This applies to analyses like size, color, etc.
    if ~ismember(current_type, {'category', 'identity'})
        versions = {'one_block_out'};
    end
    
    % Ensure versions is a cell array for consistency
    if ~iscell(versions)
        versions = {versions};
    end
    
    % Create grid of all type-version combinations
    [Type_grid, Version_grid] = ndgrid(1, 1:length(versions));
    
    % Generate filename for each combination
    num_combinations = numel(Type_grid);
    for j = 1:num_combinations
        version_idx = Version_grid(j);
        
        % Format: 'type_version'
        filename = sprintf('%s_%s', current_type, versions{version_idx});
        combinations{end+1} = filename;
    end
end

%% ===================================================================
%  ITERATE THROUGH ALL COMBINATIONS AND RUN DECODING
%  ===================================================================

for i = 1:length(combinations)
    % ---------------------------------------------------------------
    % Parse the combination string to extract type and method
    % ---------------------------------------------------------------
    
    % Split combination by underscore
    % Examples:
    %   'category_all_all'        -> ['category', 'all', 'all']
    %   'occl_level_intact_occl'  -> ['occl', 'level', 'intact', 'occl']
    parts = split(combinations{i}, '_');
    
    % Reconstruct decode_type name
    if numel(parts) == 4
        % Standard case: single-word type (e.g., 'category')
        decode_type = parts{1};
    elseif numel(parts) == 5
        % Multi-word type (e.g., 'occl_level')
        decode_type = strjoin(parts(1:2), '_');
    end
    
    % Extract decode method (train_test configuration)
    % Last 3 parts form the method (e.g., 'all_all' or 'intact_occl')
    decode_method = strjoin(parts(end-2:end), '_');
    
    % ---------------------------------------------------------------
    % Skip one-block-out if subject has only 1 valid block
    % ---------------------------------------------------------------
    
    % Check if using one_block_out cross-validation with insufficient blocks
    if strcmp(decode_method, 'one_block_out') && ...
            isscalar(cfg.participants_info.isgood{cfg.participants_info.subjectnr})
        
        fprintf('⚠️  Skipping one_block_out for sub-%02d (only 1 block exists)\n', subjectnr);
        results = struct();  % Return empty results
        return               % Exit function early
    end
    
    % ---------------------------------------------------------------
    % Prepare configuration for current decoding analysis
    % ---------------------------------------------------------------
    
    % Create a copy of config for this specific analysis
    cfg_current = cfg;
    
    % Select only the matching decode_type from config
    type_match = strcmp({cfg_current.decode_type.name}, decode_type);
    cfg_current.decode_type = cfg_current.decode_type(type_match);
    
    % Set current version being processed
    cfg_current.decode_type.current_version = decode_method;
    
    % Update chunk function for the current version
    % (Skip for size analyses which have fixed chunking)
    if ~(ismember(decode_type, {'size_2class', 'size_3class'}))
        cfg_current.decode_type.chunk_func = cfg_current.decode_type.chunk_func.(decode_method);
    end
    
    % ---------------------------------------------------------------
    % Run the decoding analysis
    % ---------------------------------------------------------------
    
    fprintf('Subject-%02i Decoding: "%s", Version: "%s"\n', ...
        subjectnr, decode_type, decode_method);
    
    % Execute decoding and store results
    results{i} = apply_decoding(ds, cfg_current);
    
    % ---------------------------------------------------------------
    % Save results to file
    % ---------------------------------------------------------------
    
    if cfg.savefile
        % Construct result filename
        % Format: 'group_sub-XX_decodetype_version.mat'
        resfn = fullfile(cfg.project_path, 'derivatives', ...
            sprintf('%s_sub-%02i_%s', group, subjectnr, combinations{i}));
        
        % Save results (overwrite flag is handled within save_results)
        save_results(results{i}, resfn);
    end
    
    % ---------------------------------------------------------------
    % Plot results
    % ---------------------------------------------------------------
    
    if cfg.plot_results
        % Construct figure filename
        % Format: 'group_sub-XX_decodetype_version.png'
        figfn = fullfile(cfg.project_path, 'figures', 'decoding', ...
            sprintf('%s_sub-%02i_%s.png', group, subjectnr, combinations{i}));
        
        % Get decoding configuration to extract chance level
        type_match = strcmp({cfg.decode_type.name}, decode_type);
        current_decode_config = cfg.decode_type(type_match);
        
        % Calculate chance level based on number of classes
        % (e.g., 50% for 2-class, 25% for 4-class)
        chance_level = 1 / current_decode_config.n_classes;
        
        % Add chance level to results for plotting
        res_to_plot = results{i};
        res_to_plot.chance = chance_level;
        
        % Generate and save plot
        plot_results(res_to_plot, figfn);
    end
end

end