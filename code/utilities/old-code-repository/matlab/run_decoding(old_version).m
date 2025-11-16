function results = run_decoding_occlususion(ds, cfg, varargin)
% RUN_DECODING Flexible EEG/MVPA decoding pipeline with configurable analysis types
%
% Performs time-series decoding analysis on EEG data using a configuration-based approach.
% Automatically handles different data folders (infants/adults)
% and skips invalid analysis combinations (e.g., one-block-out CV with single block data).
%
%
% Inputs:
%   subjectnr : integer
%       Subject number to analyze (e.g., 1, 2, ...)
%   cfg       : struct
%       Configuration structure from decoding_config(), containing:
%       - decode_type: Which data dimension to decode (category vs. ID)
%       - preproc_dir: Path to preprocessed data
%       - isgood: List of valid blocks per subject
%   varargin  : optional name-value pairs
%       'decode_type' : string (e.g., 'category', 'size_2class')
%           Specific analysis type to run (skips iteration if provided)
%       'decode_mode' : string (e.g., 'one_block_out')
%           Specific cross-validation method to use
%
% Output:
%   results : struct
%       Structure containing decoding results with fields named as:
%       [decode_type]_[decode_mode] (e.g., 'category_one_block_out')
%       Each field contains the output from apply_decoding()
%
% Usage Examples:
%   1. Run all configured analyses for subject 1:
%       results = run_decoding(1, cfg);
%
%   2. Run specific analysis with custom CV:
%       results = run_decoding(1, cfg, 'decode_type', 'category', ...
%                                        'decode_mode', 'one_object_out');
%
%   3. Run only size decoding:
%       results = run_decoding(1, cfg, 'decode_type', 'size_2class');
%
% See also:
%   decoding_config, apply_decoding, decode_size

data_folder = cfg.participants_info.name;
subjectnr = cfg.participants_info.subjectnr;

%% === Parse Optional Inputs ===
p = inputParser;
addParameter(p, 'decode_type', '', @ischar);
addParameter(p, 'decode_mode', '', @ischar);
addParameter(p, 'partitioner', '', @ischar);
parse(p, varargin{:});

decode_type   = p.Results.decode_type;
decode_mode = p.Results.decode_mode;
partitioner = p.Results.partitioner;

%% === Iterate Through Decoding Types and Modes and Partitioning Versions ===

% === Initialize results ===
results = struct();

% === Case 1: user specified a decode_type (override) ===
if ~isempty(decode_type)
    decode_type_idx = find(strcmp({cfg.decode_type.name}, decode_type));  % Find the specified decode_type in cfg
    if isempty(decode_type_idx)
        error('Decode type "%s" not found in config', decode_type);
    end

    % Make a copy of the selected decode_type
    cfg_current = cfg;
    cfg_current.decode_type = cfg.decode_type(decode_type_idx);

    % Override decode_mode if given
    if isempty(decode_mode)
        decode_mode_name = fieldnames(cfg_current.decode_type.chunk_func);
        decode_mode_name = decode_mode_name{1};
    else
        decode_mode_name = decode_mode;
    end
    outfn = sprintf('%s_%s', decode_type, decode_mode_name);
    cfg_current.decode_type.chunk_func = cfg_current.decode_type.chunk_func.(decode_mode_name);

    % Override partitioner if given
    if isempty(partitioner)
        if isempty(cfg_current.decode_type.custom_partitioner)
            partitioner_name = '';
        else
            partitioner_name = cfg.current_version;
        end
    else
        partitioner_name = partitioner;
    end

    if ~isempty(partitioner_name)
        cfg_current.decode_type.partitioner_func = cfg_current.decode_type.custom_partitioner.(partitioner_name);
        outfn = sprintf('%s_%s', outfn, partitioner_name);
    else
        outfn = sprintf('%s_%s', outfn, cfg.versions_to_run);
    end


    % Run just this config
    results = apply_decoding(ds, cfg_current);

    % === Save Results ===
    if cfg.savefile || (isfield(cfg, 'overwrite') && cfg.overwrite)
        resfn = fullfile(cfg.project_path, 'results', data_folder, ...
            sprintf('sub-%02i_%s', subjectnr, outfn));
        save_results(results, resfn);
    end
    % === Plot Results ===
    if cfg.plot_results || (isfield(cfg, 'overwrite') && cfg.overwrite)
        figfn = fullfile(cfg.project_path, 'analysis/visualisation', data_folder, 'decoding', ...
            sprintf('sub-%02i_%s.png', subjectnr,  outfn));
        results.chance = 1/cfg_current.decode_type.n_classes;
        plot_results(results, figfn);
    end

    % === Case 2: run everything from cfg ===
else
    % Iterate through all decode types and chunk methods in cfg
    for decode_type_idx = 1:length(cfg.decode_type)

        % Create cfg_current for this iteration
        cfg_current = cfg;
        cfg_current.decode_type = cfg.decode_type(decode_type_idx);
        current_decode_type = cfg_current.decode_type.name;
        if strcmp(current_decode_type, 'occl_level')
            cfg_current.current_version = 'all_all';
        elseif strcmp(current_decode_type, 'occl_pos') || strcmp(current_decode_type, 'occl_sfreq')
            cfg_current.current_version = 'occl_only';
        end

        decode_modes = fieldnames(cfg_current.decode_type.chunk_func);
        for decode_modes_idx = 1:length(decode_modes)
            current_decode_mode = decode_modes{decode_modes_idx};
            cfg_current.decode_type.chunk_func = cfg.decode_type(decode_type_idx).chunk_func.(current_decode_mode);

            % Skip one-block-out if subject has only 1 block
            if strcmp(current_decode_mode, 'one_block_out') && isscalar(cfg.participants_info.isgood{cfg.participants_info.subjectnr})
                fprintf('Skipping one_block_out for sub-%02d (only 1 block)\n', subjectnr);
                continue;  % Skip to next decode_mode
            end

            if ~isempty(cfg_current.decode_type.custom_partitioner)
                if isfield(cfg_current.decode_type.custom_partitioner, cfg_current.current_version)
                     cfg_current.decode_type.partitioner_func = cfg_current.decode_type.custom_partitioner.(cfg_current.current_version);
                end
            end
               
            outfn = sprintf('%s_%s_%s', ...
                current_decode_type, current_decode_mode, cfg_current.current_version);
           

            fprintf('Decoding %s for subject %02d\n', outfn, subjectnr);
            results.(outfn) = apply_decoding(ds, cfg_current);

            % === Save Results ===
            res = results.(outfn);
            if cfg.savefile || (isfield(cfg, 'overwrite') && cfg.overwrite)
                resfn = fullfile(cfg.project_path, 'results', data_folder, ...
                    sprintf('sub-%02i_%s', subjectnr, outfn));
                save_results(res, resfn);
            end
            % === Plot Results ===
            if cfg.plot_results || (isfield(cfg, 'overwrite') && cfg.overwrite)
                figfn = fullfile(cfg.project_path, 'analysis/visualisation', data_folder, 'decoding', ...
                    sprintf('sub-%02i_%s.png', subjectnr, outfn));
                res.chance = 1/cfg_current.decode_type.n_classes;  % Dynamic chance level
                plot_results(res, figfn);
            end
        end
    end
end