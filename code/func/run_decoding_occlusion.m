function results = run_decoding_occlusion(ds, cfg, varargin)
% RUN_DECODING_OCCLUSION - Execute MVPA decoding analyses for occlusion experiment
%
% This function runs multivariate pattern analysis (MVPA) decoding on a
% CoSMoMVPA dataset for the occlusion project. It handles multiple decoding
% types (category, identity, occlusion properties) and different train/test
% configurations (all_all, intact_intact, intact_occl).
%
% Inputs:
%   ds       - CoSMoMVPA dataset structure containing EEG data
%   cfg      - Configuration struct from occlusion_decoding_config()
%   varargin - Optional name-value pairs:
%              'type'    : Cell array of decoding types to run (e.g., {'category'})
%              'version' : String specifying version to run (e.g., 'intact_occl')
%
% Output:
%   results  - Cell array containing decoding results for each analysis
%
% Usage Examples:
%   results = run_decoding_occlusion(ds, cfg);                             % Run all analyses
%   results = run_decoding_occlusion(ds, cfg, 'type', {'category'});       % Run specific type
%   results = run_decoding_occlusion(ds, cfg, 'version', 'intact_occl');   % Run specific version
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

type    = p.Results.type;     % Decoding type (e.g., 'category', 'occl_level')
version = p.Results.version;  % Analysis version (e.g., 'all_all', 'intact_occl')

%% ===================================================================
%  EXTRACT PARTICIPANT INFORMATION
%  ===================================================================

% Get participant group name (e.g., 'infants' or 'adults')
group = cfg.participants_info.name;

% Get current subject number being processed
subjectnr = cfg.participants_info.subjectnr;

%% ===================================================================
%  CHECK FOR SINGLE-BLOCK SUBJECTS
%  ===================================================================

% Skip analysis if subject has only 1 valid block
% (Cannot perform cross-validation with a single block)
if isscalar(cfg.participants_info.isgood{cfg.participants_info.subjectnr})
    fprintf('⚠️  Skipping analysis for sub-%02d (only 1 block exists - cannot perform cross-validation)\n', subjectnr);
    results = struct();  % Return empty results
    return               % Exit function gracefully
end

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
% Each combination will be formatted as: 'decodetype_version'
% Examples: 'category_intact_occl', 'occl_pos_occl_only'
combinations = {};

% Loop through each decoding type
for i = 1:length(types)
    current_type = types{i};

    % --- Special handling for occlusion-specific analyses ---
    % Occluder properties (position, spatial frequency) only make sense
    % when analyzing occluded stimuli
    if ismember(current_type, {'occl_pos', 'occl_sfreq'})
        versions = {'occl_only'};  % Only use occluded stimuli

        % Occlusion level detection uses all stimuli (both intact and occluded)
    elseif strcmp(current_type, 'occl_level')
        versions = {'all_all'};    % Use all stimuli for train/test
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
    % Parse the combination string to extract type and version
    % ---------------------------------------------------------------

    % Split combination by underscore
    % Examples:
    %   'category_intact_occl'  -> ['category', 'intact', 'occl']
    %   'occl_pos_occl_only'    -> ['occl', 'pos', 'occl', 'only']
    parts = split(combinations{i}, '_');

    % Reconstruct decode_type name
    if numel(parts) == 3
        % Standard case: single-word type (e.g., 'category')
        decode_type = parts{1};
    elseif numel(parts) == 4
        % Multi-word type (e.g., 'occl_pos', 'occl_level')
        decode_type = strjoin(parts(1:2), '_');
    end

    % Extract decode version (train_test configuration)
    % Last 2 parts form the version (e.g., 'intact_occl', 'occl_only', 'all_all')
    decode_version = strjoin(parts(end-1:end), '_');

    % ---------------------------------------------------------------
    % Prepare configuration for current decoding analysis
    % ---------------------------------------------------------------

    % Create a copy of config for this specific analysis
    cfg_current = cfg;

    % Select only the matching decode_type from config
    type_match = strcmp({cfg_current.decode_type.name}, decode_type);
    cfg_current.decode_type = cfg_current.decode_type(type_match);

    % Set current version being processed
    cfg_current.decode_type.current_version = decode_version;

    % ---------------------------------------------------------------
    % Handle preprocessing for custom partitioner scenarios
    % ---------------------------------------------------------------

    % If using custom partitioner with 'all_all' or 'intact_occl' versions,
    % disable the standard preprocessing (the partitioner will handle it)
    if ~isempty(cfg_current.decode_type.custom_partitioner) && ...
            ismember(cfg.current_version, {'all_all', 'intact_occl'})
        cfg_current.decode_type.preprocess_func = [];
    end

    % ---------------------------------------------------------------
    % Set up partitioner function
    % ---------------------------------------------------------------

    % Use custom partitioner only for 'intact_occl' version
    % (trains on intact stimuli, tests on occluded stimuli)
    if ~isempty(cfg_current.decode_type.custom_partitioner) && ...
            strcmp(cfg_current.decode_type.current_version, 'intact_occl')
        cfg_current.decode_type.partitioner_func = cfg_current.decode_type.custom_partitioner;
    else
        cfg_current.decode_type.partitioner_func = [];  % Use standard cross-validation
    end

    % ---------------------------------------------------------------
    % Run the decoding analysis
    % ---------------------------------------------------------------

    fprintf('Subject-%02i Decoding: "%s", Version: "%s"\n', ...
        subjectnr, decode_type, decode_version);

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