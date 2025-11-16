%% run_all_subjects_viewpoint.m
%% =======================================================================
%% VIEWPOINT EXPERIMENT - COMPLETE ANALYSIS PIPELINE
%% =======================================================================
% Description: Master script for running preprocessing, decoding, and RDM
%              analysis for the viewpoint experiment
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/07/2025]
% Modified: [18/09/2025]
%% =======================================================================
%% SETUP AND INITIALISATION
%% =======================================================================
clc; clear; close all;
%% CONFIGURATION SECTION
%% =======================================================================
% Project paths - MODIFY THESE FOR YOUR SYSTEM
project_root = '~/Documents/PhD/Project';
project_name = 'viewpoint';
cosmomvpa_path = '/Users/22095708/Documents/MATLAB/toolboxes/CoSMoMVPA';
eeglab_path = '/Users/22095708/Documents/MATLAB/toolboxes/eeglab2025.0.0';

% Add project to MATLAB path
addpath(genpath(project_root));
addpath(genpath(cosmomvpa_path));
fprintf('[SETUP] Added project path: %s\n', project_root);

%% INITIALISE LOGGING
%% ===================================================================

timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
log_file = fullfile(project_root, project_name, 'docs/logs', sprintf('run_all_%s.log', timestamp));
if ~exist(fileparts(log_file), 'dir')
    mkdir(fileparts(log_file));
end
diary(log_file);
fprintf('=== PIPELINE STARTED: %s ===\n', datetime('now'));

%% ANALYSIS CONFIGURATION
%% ===================================================================
% Pipeline control - Set to 1 to run, 0 to skip
pipelines_to_run = struct(...
    'Preprocessing', 0, ...    % Preprocessing with EEGLAB
    'Decoding', 0, ...         % Decoding analysis
    'Permutation', 0, ...      % Permutation testing
    'RSA', 1);                 % RDM generation

% Target group and subject selection
group_to_run = struct('infants', 1, 'adults', 0);
subjects_to_run = []; % [1 2 3 4 5 6] OR [] for all subjects

% Decoding parameters
decodings_to_run = {'identity'}; % {'category', 'identity', 'size_2class', 'size_3class'}
versions_to_run = struct('one_rotation_out', 1, 'one_block_out', 1);

active_versions = fieldnames(versions_to_run);
active_versions = active_versions(cell2mat(struct2cell(versions_to_run))~=0);

% RSA configurations
RDM_config = {'target_class', 'identity', ...
    'crossval_method', 'one_rotation_out', ...
    'pw_permutation', 0, 'pw_mode', 'all', 'save_RDM', 1, }; % Options for pw_mode: {'animate_only', 'inanimate_only', 'hetero', 'all'}

% === Permutation Config ===
permutation_config = struct('k', 100, 'save_null', 1, 'plot_results', 1);

%% PIPELINE EXECUTION
%% ==================================================================
active_groups = fieldnames(group_to_run); active_groups = active_groups(cell2mat(struct2cell(group_to_run)) ~= 0);
if isempty(subjects_to_run), subject_list_name = "all"; else, subject_list_name= strjoin({'sub-', mat2str(subjects_to_run)}, ' '); end
active_pipelines = fieldnames(pipelines_to_run); active_pipelines = active_pipelines(cell2mat(struct2cell(pipelines_to_run)) ~=0);

%% Display analysis configurations
%% =======================================================================
fprintf('\n=== ANALYSIS CONFIGURATION ===\n');
% Pipelines
fprintf('Pipeline: %s\n', strjoin(active_pipelines, ', '));

% Groups
fprintf('Groups: %s\n', strjoin(active_groups, ', '));

% Subjects
fprintf('Subjects: %s available\n', subject_list_name);

fprintf('================================\n');

%% I. PREPROCESSING PIPELINE
%% =======================================================================
if pipelines_to_run.Preprocessing
    fprintf('\n=== STARTING PREPROCESSING ===\n');

    addpath('/Users/22095708/Documents/MATLAB/toolboxes/eeglab2025.0.0');
    eeglab nogui;

    config_file = @preprocessing_config;
    cfg = config_file(project_name);
    cfg.participants_info = cfg.participants_info(ismember({cfg.participants_info.name}, active_groups));

    if strcmp(subject_list_name, 'all')
        subject_list = 1:cfg.participants_info.n_subjects;
    else
        subject_list = subjects_to_run;
    end

    for subjectnr = subject_list
        fprintf('[PREPROC] Processing subject %02d...\n', subjectnr);
        try
            run_preprocess(subjectnr, cfg);
            fprintf('[PREPROC] ✓ Subject %02d completed\n', subjectnr);
        catch ME
            fprintf('[PREPROC] ✗ Subject %02d failed: %s\n', subjectnr, ME.message);
            continue; % Continue with next subject
        end
    end
    fprintf('[PREPROC] Preprocessing completed for %d subjects\n', length(subject_list));
end

%% II. DECODING PIPELINE
%% =======================================================================
if pipelines_to_run.Decoding || pipelines_to_run.Permutation
    fprintf('\n=== STARTING DECODING ANALYSIS ===\n');

    config_file = @viewpoint_decoding_config;
    cfg = config_file();
    cfg.project = project_name;
    cfg.participants_info = cfg.participants_info(ismember({cfg.participants_info.name}, active_groups));

    if strcmp(subject_list_name, 'all')
        subject_list = 1:cfg.participants_info.n_subjects;
    else
        subject_list = subjects_to_run;
    end

    % === Shuffled-label Analysis (if "perm" on) ===
    if (pipelines_to_run.Permutation), cfg.permut_config = permutation_config; end

    for subjectnr = subject_list

        % Process each subject
        fprintf('[DECODE] Processing subject %02d/%d...\n', subjectnr, length(subject_list));

        try
            cfg.participants_info.subjectnr = subjectnr;
            % Load dataset
            [cfg.ds, size_info] = load_subject_data(cfg, subjectnr);
            cfg.stimnum.size = size_info;

            for v = 1: numel(active_versions)
                current_version = active_versions{v};
                if versions_to_run.(current_version)
                    config = cfg;
                    config.current_version = current_version;

                    if ~isempty(decodings_to_run)
                        var_input = {'type', decodings_to_run};
                    else
                        var_input = {};
                    end

                    fprintf('[DECODE] Decoding Version: %s for subject %02d:...\n', current_version, subjectnr);
                    results{subjectnr}.(current_version) = run_decoding_viewpoint(config.ds, config, var_input{:});
                end
            end
            fprintf('[DECODE] ✓ Subject %02d completed\n', subjectnr);

        catch ME
            fprintf('[DECODE] ✗ Subject %02d failed: %s\n', subjectnr, ME.message);
            continue;
        end
    end
    fprintf('[DECODE] Decoding completed for %d subjects\n',  length(subject_list));
end
%% III. Run RSA pipeline
%% =======================================================================
if pipelines_to_run.RSA
    % Load configuration
    config_file = @viewpoint_decoding_config;
    cfg = config_file();

    % Parse RDM configuration
    p = inputParser;
    addParameter(p, 'target_class', '', @ischar);
    addParameter(p, 'crossval_method', '', @ischar);
    addParameter(p, 'pw_permutation', '', @isnumeric);
    addParameter(p ,'pw_mode', '', @ischar);
    addParameter(p, 'save_RDM', '', @isnumeric);
    parse(p, RDM_config{:});
    cfg.RDM_config = p.Results;

    fprintf('[RDM] Configuration: %s\n', jsonencode(cfg.RDM_config));

    % Setup permutation for pairwise decoding
    if cfg.RDM_config.pw_permutation
        cfg.permut_config = permutation_config;
        fprintf('[RDM] Pairwise permutation testing enabled\n');
    end

    cfg.participants_info = cfg.participants_info(ismember({cfg.participants_info.name}, active_groups));  
    if strcmp(subject_list_name, 'all')
        subject_list = 1:cfg.participants_info.n_subjects;
    else
        subject_list = subjects_to_run;
    end
    
    % Initialize storage
    pw_results = cell(max(subject_list), 1);
    RDM = cell(max(subject_list), 1);
    null = cell(max(subject_list), 1);

    % Process each subject
    for subjectnr = subject_list
        cfg.participants_info.subjectnr = subjectnr;
        fprintf('[RDM] Processing subject %02d/%d...\n', subjectnr, length(subject_list));
        try
            % Load dataset
            [cfg.ds, size_info] = load_subject_data(cfg, subjectnr);
            cfg.stimnum.size = size_info;

            % Run pairwise classification
            if cfg.RDM_config.pw_permutation
                [pw_results{subjectnr}, RDM{subjectnr}, null{subjectnr}] = run_pairwise(cfg.ds, cfg);
            else
                [pw_results{subjectnr}, RDM{subjectnr}] = run_pairwise(cfg.ds, cfg);
            end

            fprintf('[RDM] ✓ Subject %02d completed\n', subjectnr);

        catch ME
            fprintf('[RDM] ✗ Subject %02d failed: %s\n', subjectnr, ME.message);
            continue;
        end
    end

    fprintf('[RDM] RDM generation completed for %d subjects\n', length(subject_list));
end