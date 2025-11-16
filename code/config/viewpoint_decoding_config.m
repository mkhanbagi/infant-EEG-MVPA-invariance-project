% VIEWPOINT_DECODING_CONFIG - Configuration for EEG decoding analysis
%
% Author: [Mahdiyeh Khanbagi]
% Created: [20/07/2025]
% Modified: [11/10/2025]
%
% Generates configuration parameters for multivariate pattern analysis (MVPA)
% using CoSMoMVPA toolbox. Defines stimulus categories, decoding targets,
% and cross-validation schemes.
%
% Usage:
%   cfg = viewpoint_decoding_config()
%
% Output:
%   cfg - Configuration struct containing:
%         - Stimulus metadata and categorizations
%         - Decoding analysis parameters
%         - Cross-validation settings
%         - Participant information
%
% Note: Requires helper functions assign_class_labels() and decode_size()

function cfg = viewpoint_decoding_config()

cfg = struct();

%% ===================================================================
%  PROJECT PATHS
%  ===================================================================
cfg.project_path = fullfile(getenv('HOME'), 'Documents', 'PhD', 'Project', 'viewpoint');
cfg.data_dir =  fullfile(cfg.project_path, 'data', 'raw');
cfg.preproc_dir  = fullfile(cfg.project_path, 'data', 'preprocessed');

%% ===================================================================
%  STIMULUS CONFIGURATION (112 total stimuli)
%  ===================================================================
cfg.total_nstimuli = 112;

% --- Category-based grouping ---
% Animate objects (56 stimuli: 7 animals × 8 viewpoints)
cfg.stimnum.category.animate = [ ...
    9:40, 49:72 ...  % Deer, Dog, Dolphin, Llama, Lion, Pigeon, Rabbit
];

% Inanimate objects (56 stimuli: 7 objects × 8 viewpoints)
cfg.stimnum.category.inanimate = [ ...
    1:8, 41:48, 73:112 ...  % Chair, Lamp, Sofa, Plane, Tower, Train, Xylophone
];

% --- Identity-based grouping (14 objects × 8 viewpoints each) ---
cfg.stimnum.identity.chair      = [1, 2, 3, 4, 5, 6, 7, 8];
cfg.stimnum.identity.deer       = [9, 10, 11, 12, 13, 14, 15, 16];
cfg.stimnum.identity.dog        = [17, 18, 19, 20, 21, 22, 23, 24];
cfg.stimnum.identity.dolphin    = [25, 26, 27, 28, 29, 30, 31, 32];
cfg.stimnum.identity.llama      = [33, 34, 35, 36, 37, 38, 39, 40];
cfg.stimnum.identity.lamp       = [41, 42, 43, 44, 45, 46, 47, 48];
cfg.stimnum.identity.lion       = [49, 50, 51, 52, 53, 54, 55, 56];
cfg.stimnum.identity.pigeon     = [57, 58, 59, 60, 61, 62, 63, 64];
cfg.stimnum.identity.rabbit     = [65, 66, 67, 68, 69, 70, 71, 72];
cfg.stimnum.identity.sofa       = [73, 74, 75, 76, 77, 78, 79, 80];
cfg.stimnum.identity.plane      = [81, 82, 83, 84, 85, 86, 87, 88];
cfg.stimnum.identity.tower      = [89, 90, 91, 92, 93, 94, 95, 96];
cfg.stimnum.identity.train      = [97, 98, 99, 100, 101, 102, 103, 104];
cfg.stimnum.identity.xylophone  = [105, 106, 107, 108, 109, 110, 111, 112];

% --- Viewpoint-based grouping (8 rotation angles) ---
cfg.stimnum.viewpoint.left_one    = [1, 13, 21, 29, 37, 41, 53, 59, 69, 77, 85, 93, 97, 109];      % -84°
cfg.stimnum.viewpoint.left_two    = [2, 14, 22, 30, 38, 42, 54, 60, 70, 78, 86, 94, 98, 110];      % -60°
cfg.stimnum.viewpoint.left_three  = [3, 15, 23, 31, 39, 43, 55, 61, 71, 79, 87, 95, 99, 111];      % -36°
cfg.stimnum.viewpoint.left_four   = [4, 16, 24, 32, 40, 44, 56, 62, 72, 80, 88, 96, 100, 112];     % -12°
cfg.stimnum.viewpoint.right_one   = [5, 9, 17, 25, 33, 45, 49, 63, 65, 73, 81, 89, 101, 105];      % +12°
cfg.stimnum.viewpoint.right_two   = [6, 10, 18, 26, 34, 46, 50, 64, 66, 74, 82, 90, 102, 106];     % +36°
cfg.stimnum.viewpoint.right_three = [7, 11, 19, 27, 35, 47, 51, 57, 67, 75, 83, 91, 103, 107];     % +60°
cfg.stimnum.viewpoint.right_four  = [8, 12, 20, 28, 36, 48, 52, 58, 68, 76, 84, 92, 104, 108];     % +84°

% --- Low-level visual features ---
% Entropy (image complexity)
cfg.stimnum.entropy.low = [ ...
    1:16, 26:31, 33:48, 51:54, 62:63, 73:74, 79:81, 84, 88, 105:106, 110:112];
cfg.stimnum.entropy.high = [ ...
    17:25, 32, 49:50, 55:61, 64:72, 75:78, 82:83, 85:87, 89:104, 107:109];

% Luminance (brightness)
cfg.stimnum.luminance.low = [ ...
    2:7, 17:19, 25, 32, 41:44, 46:50, 55:72, 81, 88:104, 108:109];
cfg.stimnum.luminance.high = [ ...
    1, 8:16, 20:24, 26:31, 33:40, 45, 51:54, 62:63, 73:87, 105:107, 110:112];

%% ===================================================================
%  DATA PROCESSING CONFIGURATION
%  ===================================================================
cfg.slice_method = 'blocks';  % How to organize data: 'trials' or 'blocks'

cfg.pw_mode.animate_only = [2, 3, 4, 5, 7, 8, 9] ;
cfg.pw_mode.inanimate_only = [1, 6, 10, 11, 12, 13, 14];
cfg.pw_mode.hetero = [2, 3, 4, 5, 7, 8, 9; 1, 6, 10, 11, 12, 13, 14];
cfg.pw_mode.all = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

%% ===================================================================
%  DECODING ANALYSIS CONFIGURATIONS
%  ===================================================================
% Each analysis type defines:
%   - name: Analysis identifier
%   - n_classes: Number of categories to decode
%   - target_func: How to assign class labels
%   - chunk_func: Cross-validation scheme(s)
%   - label_func: Human-readable label generation

cfg.decode_type = struct([]);

% --- 1. Category Decoding (Animate vs Inanimate) ---
cfg.decode_type(end+1).name = 'category';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).target_func = @(ds, stimnum) double(ismember(ds.sa.stimnum, stimnum.animate));
cfg.decode_type(end).chunk_func = struct( ...
    'one_block_out',    @(ds) ds.sa.blocknum, ...                               % Leave-one-block-out CV
    'one_rotation_out', @(ds, viewpoint) assign_class_labels(ds.sa.stimnum, viewpoint));  % Leave-one-viewpoint-out CV
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
        cellstr(categorical(ds.sa.targets, [1 0], {'animate', 'inanimate'}))));

% --- 2. Identity Decoding (14 unique objects) ---
cfg.decode_type(end+1).name = 'identity';
cfg.decode_type(end).n_classes = 14;
cfg.decode_type(end).target_func = @(ds, identity) assign_class_labels(ds.sa.stimnum, identity);
cfg.decode_type(end).chunk_func = struct( ...
    'one_block_out',    @(ds) ds.sa.blocknum, ...
    'one_rotation_out', @(ds, viewpoint) assign_class_labels(ds.sa.stimnum, viewpoint));
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
        cellstr(categorical(ds.sa.targets, 1:14, fieldnames(cfg.stimnum.identity)'))));

% --- 3. Entropy Decoding (High vs Low complexity) ---
cfg.decode_type(end+1).name = 'entropy';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).target_func = @(ds, stimnum) double(ismember(ds.sa.stimnum, stimnum.high));
cfg.decode_type(end).chunk_func = struct('one_block_out', @(ds) ds.sa.blocknum);
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
        cellstr(categorical(ds.sa.targets, [1 0], {'high', 'low'}))));

% --- 4. Luminance Decoding (High vs Low brightness) ---
cfg.decode_type(end+1).name = 'luminance';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).target_func = @(ds, stimnum) double(ismember(ds.sa.stimnum, stimnum.high));
cfg.decode_type(end).chunk_func = struct('one_block_out', @(ds) ds.sa.blocknum);
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
        cellstr(categorical(ds.sa.targets, [1 0], {'high', 'low'}))));

% --- 5. Size Decoding (2-class: Large vs Small) ---
cfg.decode_type(end+1).name = 'size_2class';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).target_func = @(ds, cfg) decode_size(ds, cfg, '2class');
cfg.decode_type(end).chunk_func = [];
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
        cellstr(categorical(ds.sa.targets, [1 2], {'large', 'small'}))));

% --- 6. Size Decoding (3-class: Small vs Medium vs Large) ---
cfg.decode_type(end+1).name = 'size_3class';
cfg.decode_type(end).n_classes = 3;
cfg.decode_type(end).target_func = @(ds, cfg) decode_size(ds, cfg, '3class');
cfg.decode_type(end).chunk_func = [];
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
        cellstr(categorical(ds.sa.targets, [1 2 3], {'small', 'medium', 'large'}))));

% --- Optional: Viewpoint Decoding (8 rotation angles) ---
% Uncomment to enable viewpoint-invariant decoding analysis
% cfg.decode_type(end+1).name = 'viewpoint';
% cfg.decode_type(end).n_classes = 8;
% cfg.decode_type(end).target_func = @(ds, stimnum) assign_class_labels(ds.sa.stimnum, stimnum.viewpoint);
% cfg.decode_type(end).chunk_func = struct( ...
%     'one_block_out',  @(ds) ds.sa.blocknum, ...
%     'one_object_out', @(ds, identity) assign_class_labels(ds.sa.stimnum, identity));
% cfg.decode_type(end).label_func = @(ds) ...
%     setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
%         cellstr(categorical(ds.sa.targets, 1:8, fieldnames(cfg.stimnum.viewpoint)'))));

%% ===================================================================
%  CLASSIFIER
%  ===================================================================
cfg.classifier = @cosmo_classify_lda;  % Linear Discriminant Analysis

%% ===================================================================
%  PARTICIPANT INFORMATION
%  ===================================================================
% Load participant metadata from LabNotebook.csv
notebook_path = fullfile(cfg.project_path, 'docs', 'LabNotebook.csv');

% Verify file exists
if ~isfile(notebook_path)
    error('LabNotebook.csv not found at: %s', notebook_path);
end

% Import and process participant data
opts = detectImportOptions(notebook_path);
dataTable = readtable(notebook_path, opts);

relevant_cols = {
    'x_ID', 'Gender', 'DateOfBirth', 'Age_months_', 'Age_days_', ...
    'No_BlocksRecorded', 'BlocksIncludedInTheFinalAnalysis', 'Includ_OrExclud_'
};
dataTable = dataTable(:, relevant_cols);

% Parse block inclusion info (convert "1,2,3" string to [1 2 3] array)
dataTable.BlocksIncludedInTheFinalAnalysis = cellfun(@str2num, ...
    dataTable.BlocksIncludedInTheFinalAnalysis, 'UniformOutput', false);

% Initialize participant groups
cfg.participants_info = struct([]);

% -------------------------------------------------------------------
% GROUP 1: Infant Participants
% -------------------------------------------------------------------
cfg.participants_info(end+1).name = 'infants';
cfg.participants_info(end).to_run = true;                                        % Include in analysis
cfg.participants_info(end).eeg_system = 'BrainVision';                           % EEG file format 
cfg.participants_info(end).n_subjects = height(dataTable);                       % Number of infant participants
cfg.participants_info(end).isgood = dataTable.BlocksIncludedInTheFinalAnalysis;  % Valid blocks per participant
cfg.participants_info(end).labnotebook = dataTable;                              % Full participant info table

% -------------------------------------------------------------------
% GROUP 2: Adult Participants
% -------------------------------------------------------------------
cfg.participants_info(end+1).name = 'adults';
cfg.participants_info(end).to_run = true;           % Include in analysis
cfg.participants_info(end).eeg_system = 'BioSemi';  % EEG file format
cfg.participants_info(end).n_subjects = 20;         % Number of adult participants
cfg.participants_info(end).isgood = 1:50;           % Valid blocks/trials indicator
cfg.participants_info(end).labnotebook = [];        % No separate notebook for adults

%% ===================================================================
%  OUTPUT OPTIONS
%  ===================================================================
cfg.plot_results = 1;   % Generate visualization plots
cfg.savefile     = 1;   % Save results to file
cfg.overwrite    = 1;   % Overwrite existing results

end