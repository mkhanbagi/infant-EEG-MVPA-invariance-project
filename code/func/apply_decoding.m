function [res, null] = apply_decoding(ds, cfg)
% APPLY_DECODING - Perform MVPA decoding analysis on EEG dataset
%
% This function performs multivariate pattern analysis (MVPA) decoding on a 
% CoSMoMVPA dataset. It handles data preprocessing, target/chunk assignment,
% searchlight analysis, and optional permutation testing for significance.
%
% Inputs:
%   ds  - CoSMoMVPA dataset structure containing EEG data with sample 
%         attributes (sa) and feature attributes (fa)
%   cfg - Configuration struct from decoding_config with fields:
%         .participants_info - Struct with subject information
%           .subjectnr       - Current subject number
%           .isgood          - Valid blocks/trials per subject
%           .name            - Group name (e.g., 'infants', 'adults')
%         .decode_type       - Struct defining current decoding analysis
%           .name            - Analysis name (e.g., 'category', 'identity')
%           .n_classes       - Number of classes for classification
%           .preprocess_func - Optional preprocessing function handle
%           .partitioner_func- Optional custom partitioning function
%           .current_version - Current analysis version being run
%         .slice_method      - Method for slicing data ('blocks' or 'trials')
%         .classifier        - Classifier function handle (e.g., @cosmo_classify_lda)
%         .project_path      - Root directory for saving outputs
%         .RDM_config        - Optional RSA configuration (for pairwise decoding)
%         .permut_config     - Optional permutation test configuration
%           .k               - Number of permutations
%           .save_null       - Whether to save null distribution
%           .plot_results    - Whether to plot corrected results
%
% Outputs:
%   res  - CoSMoMVPA result structure from searchlight decoding containing
%          decoding accuracies across time points
%   null - [Optional] Null distribution from permutation testing (nperm × ntimepoints)
%          Empty array if permutation testing not requested
%
% Usage:
%   res = apply_decoding(ds, cfg);                   % Standard decoding
%   [res, null] = apply_decoding(ds, cfg);           % With null distribution
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [09/09/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  DATASET PREPARATION
%  ===================================================================

% Extract current subject number
subjectnr = cfg.participants_info.subjectnr;

% --- Slice dataset to include only valid blocks/trials ---
% Uses the 'isgood' field to select which blocks/trials to include
% slice_method determines whether to slice by 'blocks' or 'trials'
ds = slice_dataset(ds, cfg.slice_method, cfg.participants_info.isgood(subjectnr));

% --- Apply additional preprocessing if specified ---
% Some analyses require extra preprocessing (e.g., selecting only intact stimuli
% for train-on-intact analyses, or selecting only occluded stimuli)
if isfield(cfg.decode_type, 'preprocess_func') && ~isempty(cfg.decode_type.preprocess_func)
    preproc_func = cfg.decode_type.preprocess_func;
    ds = preproc_func(ds, cfg);
end

%% ===================================================================
%  ASSIGN TARGETS AND CHUNKS
%  ===================================================================

% Assign class labels (targets) and cross-validation folds (chunks)
% Uses function handles defined in the config for flexibility
ds = assign_labels(ds, cfg);

%% ===================================================================
%  CUSTOM PARTITIONING (if required)
%  ===================================================================

% Some analyses require custom train/test splits beyond standard cross-validation
% Example: Train on intact stimuli, test on occluded stimuli
if isfield(cfg.decode_type, 'partitioner_func') && ~isempty(cfg.decode_type.partitioner_func)
    partitioner_func = cfg.decode_type.partitioner_func;
    custom_partitions = partitioner_func(ds, cfg);
else
    custom_partitions = '';  % Use standard cross-validation
end

%% ===================================================================
%  PAIRWISE DECODING (for RSA/RDM analyses)
%  ===================================================================

% If running representational similarity analysis (RSA), slice dataset
% to include only the stimulus pairs specified in the config
if isfield(cfg, 'RDM_config') && cfg.RDM_config.run_pw
    pairs = cfg.RDM_config.pairs;
    
    fn = fieldnames(cfg.stimnum.identity);
    pair_stimnums = [cfg.stimnum.identity.(fn{pairs(1)}),cfg.stimnum.identity.(fn{pairs(2)})];

    ds = cosmo_slice(ds, ismember(ds.sa.stimnum, pair_stimnums));
end

%% ===================================================================
%  BASELINE CORRECTION
%  ===================================================================

% Apply baseline correction using pre-stimulus interval (-100ms to 0ms)
% 'absolute' mode subtracts the baseline mean from each sample
ds = cosmo_meeg_baseline_correct(ds, [-100 0], 'absolute');

%% ===================================================================
%  DEFINE SEARCHLIGHT NEIGHBORHOOD
%  ===================================================================

% Create temporal neighborhood for searchlight analysis
% 'radius', 0 means decoding is performed at each individual time point
% (no temporal smoothing across adjacent time points)
nh = cosmo_interval_neighborhood(ds, 'time', 'radius', 0);

%% ===================================================================
%  CONFIGURE CLASSIFIER AND PARTITIONS
%  ===================================================================

% Build measure arguments (ma) structure containing classifier and
% cross-validation scheme
if isempty(custom_partitions)
    % Standard cross-validation (e.g., leave-one-block-out)
    ma = make_ma_struct(ds, cfg);
else
    % Custom partitioning (e.g., train-intact/test-occluded)
    ma = make_ma_struct(ds, cfg, custom_partitions);
end

%% ===================================================================
%  PERFORM SEARCHLIGHT DECODING
%  ===================================================================

% Run cross-validated classification at each time point
% Returns decoding accuracy across the time series
res = cosmo_searchlight(ds, nh, @cosmo_crossvalidation_measure, ma);

fprintf('[DONE] Decoded %s for subject %02d\n', cfg.decode_type.name, subjectnr);

%% ===================================================================
%  PERMUTATION TESTING (if required)
%  ===================================================================

% Perform permutation test to assess statistical significance
% by creating a null distribution through label shuffling
if isfield(cfg, 'permut_config')
    nperm = cfg.permut_config.k;  % Number of permutations
    res_shuffled = {};            % Store shuffled results
    
    fprintf('Running %d permutations for null distribution...\n', nperm);
    
    % --- Run decoding with shuffled labels ---
    for k = 1:nperm
        % Randomly shuffle target labels while maintaining dataset structure
        randomized_targets = cosmo_randomize_targets(ds, 'seed', k);
        ds.sa.targets = randomized_targets;
        
        % Rebuild classifier structure with shuffled labels
        if isempty(custom_partitions)
            ma = make_ma_struct(ds, cfg);
        else
            ma = make_ma_struct(ds, cfg, custom_partitions);
        end
        
        % Run decoding with shuffled labels
        res_shuffled{k} = cosmo_searchlight(ds, nh, @cosmo_crossvalidation_measure, ma);
    end
    
    % --- Compile null distribution ---
    % Stack all shuffled results into a single dataset
    ds_null = cosmo_stack(res_shuffled);
    null = ds_null.samples;  % Extract accuracy values (nperm × ntimepoints)
    
    % --- Save null distribution if requested ---
    % (Skip saving for pairwise decoding in RSA analyses)
    if (cfg.permut_config.save_null) && ~(isfield(cfg, 'RDM_config') && cfg.RDM_config.run_pw)
        % Construct filename for null distribution
        null_filename = sprintf('%s_%s_null', cfg.decode_type.name, cfg.decode_type.current_version);
        null_path = fullfile(cfg.project_path, 'derivatives', ...
            sprintf('%s_sub-%02i_%s.csv', cfg.participants_info.name, subjectnr, null_filename));
        
        % Save as CSV for easy access in other software
        writematrix(null, null_path);
        fprintf('Null distribution saved to: %s\n', null_path);
    end
    
    % --- Plot corrected results if requested ---
    % (Skip plotting for pairwise decoding in RSA analyses)
    if (cfg.permut_config.plot_results) && ~(isfield(cfg, 'RDM_config') && cfg.RDM_config.run_pw)
        % Calculate chance level for the current analysis
        chance = 1 / cfg.decode_type.n_classes;
        
        % Extract observed decoding accuracies
        ind_subj_res = res;
        observed = ind_subj_res.samples;
        
        % Extract time vector for x-axis
        tv_idx = find(strcmp(ind_subj_res.a.fdim.labels, 'time'));
        tv = ind_subj_res.a.fdim.values{tv_idx};
        
        % --- Perform cluster-based correction ---
        % Get 95th percentile of null distribution at each time point
        % This represents the maximum accuracy expected by chance
        corrected_null = prctile(null, 95, 2);
        
        % Calculate p-values: proportion of null samples >= observed
        pvals = mean(observed <= corrected_null);
        
        % Identify significant time points (p < 0.05)
        sigidx = pvals < 0.05;
        
        % --- Create visualization ---
        figure; clf;
        
        % Plot observed decoding accuracy
        plot(tv, observed, 'LineWidth', 2); hold on;
        
        % Plot chance level line
        plot(tv, chance + 0*tv, 'k--'); hold on;
        
        % Mark significant time points below the chance line
        plot(tv(sigidx), tv(sigidx)*0 + (chance*0.95), ...
            'Marker', '*', 'MarkerSize', 10, 'LineStyle', 'none');
        
        % Add labels and formatting
        xlabel('Time (ms)');
        ylabel('Decoding Accuracy');
        title(sprintf('Corrected Results: %s', cfg.decode_type.name));
        legend('Observed', 'Chance', 'Significant (p<0.05)');
        
        % --- Save figure ---
        figure_filename = sprintf('%s_%s_corrected', cfg.decode_type.name, cfg.decode_type.current_version);
        figure_path = fullfile(cfg.project_path, 'analysis/visualisation', ...
            'permutation', sprintf('%s_sub-%02i_%s.png', cfg.participants_info.name, subjectnr, figure_filename));
        
        % Ensure directory exists
        if ~exist(fileparts(figure_path), 'dir')
            mkdir(fileparts(figure_path));
        end
        
        saveas(gcf, figure_path);
        close(gcf);
        
        fprintf('Corrected results plot saved to: %s\n', figure_path);
    end
    
% --- No permutation testing ---
else
    null = [];  % Return empty array if permutations not requested
end

% --- Clean up output if null distribution not requested ---
if nargout < 2
    clear null;
end

end