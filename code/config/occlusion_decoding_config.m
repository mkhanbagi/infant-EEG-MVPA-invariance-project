% OCCLUSION_DECODING_CONFIG - Configuration for occlusion EEG decoding analysis
%
% Author: [Mahdiyeh Khanbagi]
% Created: [20/07/2025]
% Modified: [13/10/2025]
%
% Returns a configuration struct (cfg) with parameters for decoding CoSMoMVPA
% datasets in the occlusion experiment. This config defines stimulus properties,
% decoding targets, and analysis parameters.
%
% Output:
%   cfg - Struct containing all configuration settings for decoding analysis
%
% Usage:
%   cfg = occlusion_decoding_config();
%
% Project Structure:
%   The occlusion experiment investigates how infants and adults process
%   occluded objects. Stimuli include 4 identities (bear, penguin, rocket, tower)
%   in 2 colors (blue, pink), presented either intact or with occluders at
%   different positions (right, left) and spatial frequencies (low, high).
%   Three is three different decoding schemes:
%         I)  'all_all'        = Train and test on all stimuli
%         II) 'intact_intact'  = Train and test only on intact stimuli
%         III)'intact_occl'    = Train on intact, test on occluded stimuli
%
% Note: Requires helper functions assign_class_labels() and decode_size()

function cfg = occlusion_decoding_config()

cfg = struct();

%% ===================================================================
%  PROJECT PATHS
%  ===================================================================
cfg.project_path = fullfile(getenv('HOME'), 'Documents', 'PhD', 'Project', 'occlusion');
cfg.data_dir =  fullfile(cfg.project_path, 'data');
cfg.preproc_dir = fullfile(cfg.project_path, 'data', 'preprocessed');

%% ===================================================================
%  STIMULUS ORGANIZATION (64 total stimuli)
%  ===================================================================
cfg.total_nstimuli = 64;

% --- Category-level grouping ---
% Stimuli are divided into face/non-face categories
cfg.stimnum.category.face    = (1:32)';    % Face stimuli (bear, penguin)
cfg.stimnum.category.nonface = (33:64)';   % Non-face stimuli (rocket, tower)

% --- Identity-level grouping ---
% Each identity consists of 16 stimuli (8 blue + 8 pink variations)
cfg.stimnum.identity.bear    = (1:16)';    % Bear identity
cfg.stimnum.identity.penguin = (17:32)';   % Penguin identity
cfg.stimnum.identity.rocket  = (33:48)';   % Rocket identity
cfg.stimnum.identity.tower   = (49:64)';   % Tower identity

% --- Color-level grouping ---
% Each identity has blue and pink variants
cfg.stimnum.color.blue = [1:8, 17:24, 33:40, 49:56]';   % Blue stimuli across all identities
cfg.stimnum.color.pink = [9:16, 25:32, 41:48, 57:64]';  % Pink stimuli across all identities

%% ===================================================================
%  OCCLUSION CONDITION LABELING
%  ===================================================================

% Preallocate occlusion labels for all 64 stimulus presentations
% Labels: 1 = occluded, 2 = intact (unoccluded)
labels = zeros(cfg.total_nstimuli, 1);

% Define occlusion pattern within each batch of 8 stimuli
% Pattern repeats 8 times (for 8 batches = 64 total stimuli)
for batch = 0:7
    % Calculate starting index for current batch
    start_idx = batch * 8;

    % Occluded stimuli: positions 1-2 and 7-8 within each batch
    labels(start_idx + (1:2)) = 1;   % First 2 stimuli: occluded
    labels(start_idx + (7:8)) = 1;   % Last 2 stimuli: occluded

    % Intact stimuli: positions 3-6 within each batch
    labels(start_idx + (3:6)) = 2;   % Middle 4 stimuli: intact
end

% Store stimulus indices based on occlusion level
cfg.stimnum.occl_level.occluded = find(labels == 1);  % All occluded stimulus indices
cfg.stimnum.occl_level.intact   = find(labels == 2);  % All intact stimulus indices

%% ===================================================================
%  OCCLUDER PROPERTIES
%  ===================================================================

% --- Occluder Position ---
% Defines whether the occluder appears on the left or right side
% Values: 0 = no occluder, 1 = right-side occluder, 2 = left-side occluder
pos_pattern = [1, 2, 0, 0, 0, 0, 1, 2]';           % One cycle (8 stimuli)
pos_pattern_sequence = repmat(pos_pattern, 8, 1);  % Repeat for all 64 stimuli

cfg.stimnum.occl_pos.right = find(pos_pattern_sequence == 1);  % Right occluder stimuli
cfg.stimnum.occl_pos.left  = find(pos_pattern_sequence == 2);  % Left occluder stimuli

% --- Occluder Spatial Frequency ---
% Defines the visual frequency content of the occluder
% Values: 0 = no occluder, 1 = low spatial frequency, 2 = high spatial frequency
sfreq_pattern = [1, 1, 0, 0, 0, 0, 2, 2]';           % One cycle (8 stimuli)
sfreq_pattern_sequence = repmat(sfreq_pattern, 8, 1); % Repeat for all 64 stimuli

cfg.stimnum.occl_sfreq.low  = find(sfreq_pattern_sequence == 1);  % Low frequency occluders
cfg.stimnum.occl_sfreq.high = find(sfreq_pattern_sequence == 2);  % High frequency occluders

%% ===================================================================
%  STIMULUS REMAPPING (for participants 1-18)
%  ===================================================================

% Some participants saw a different stimulus-to-trigger mapping
% This section loads the remapping table to handle these cases

% Load trigger remapping file
remapping_filename = fullfile(cfg.project_path, 'docs', 'triggers_remapped.csv');
opts = detectImportOptions(remapping_filename);
cfg.trigger_map = readtable(remapping_filename, opts);

% Extract remapped indices for each stimulus property (removing NaN values)
cfg.map_key.category.face    = cfg.trigger_map{:,"Face"}(~isnan(cfg.trigger_map{:,"Face"}));
cfg.map_key.category.nonface = cfg.trigger_map{:,"Nonface"}(~isnan(cfg.trigger_map{:,"Nonface"}));

cfg.map_key.identity.bear    = cfg.trigger_map{:,"Bear"}(~isnan(cfg.trigger_map{:,"Bear"}));
cfg.map_key.identity.penguin = cfg.trigger_map{:,"Penguin"}(~isnan(cfg.trigger_map{:,"Penguin"}));
cfg.map_key.identity.rocket  = cfg.trigger_map{:,"Rocket"}(~isnan(cfg.trigger_map{:,"Rocket"}));
cfg.map_key.identity.tower   = cfg.trigger_map{:,"Tower"}(~isnan(cfg.trigger_map{:,"Tower"}));

cfg.map_key.color.blue = cfg.trigger_map{:,"Blue"}(~isnan(cfg.trigger_map{:,"Blue"}));
cfg.map_key.color.pink = cfg.trigger_map{:,"Pink"}(~isnan(cfg.trigger_map{:,"Pink"}));

cfg.map_key.occl_level.occluded = cfg.trigger_map{:,"Occluded"}(~isnan(cfg.trigger_map{:,"Occluded"}));
cfg.map_key.occl_level.intact   = cfg.trigger_map{:,"Intact"}(~isnan(cfg.trigger_map{:,"Intact"}));

cfg.map_key.occl_pos.right = cfg.trigger_map{:,"Right"}(~isnan(cfg.trigger_map{:,"Right"}));
cfg.map_key.occl_pos.left  = cfg.trigger_map{:,"Left"}(~isnan(cfg.trigger_map{:,"Left"}));

cfg.map_key.occl_sfreq.high = cfg.trigger_map{:,"High"}(~isnan(cfg.trigger_map{:,"High"}));
cfg.map_key.occl_sfreq.low  = cfg.trigger_map{:,"Low"}(~isnan(cfg.trigger_map{:,"Low"}));

% cfg.map_key.pw_mode.face_only =  [cfg.map_key.identity.bear; cfg.map_key.identity.penguin];
% cfg.map_key.pw_mode.noneface_only = [cfg.map_key.identity.rocket; cfg.map_key.identity.tower];
% cfg.map_key.pw_mode.hetero = [[cfg.map_key.identity.bear; cfg.map_key.identity.penguin],[cfg.map_key.identity.rocket; cfg.map_key.identity.tower]];
% cfg.map_key.pw_mode.total = [cfg.map_key.identity.bear; cfg.map_key.identity.penguin;cfg.map_key.identity.rocket; cfg.map_key.identity.tower];

%% ===================================================================
%  DATA PROCESSING CONFIGURATION
%  ===================================================================
cfg.slice_method = 'blocks';  % How to organize data: 'trials' or 'blocks'

% [1 2 3 4] - > {'bear', 'penguin', 'rocket', 'tower'}
cfg.pw_mode.face_only = [1,2];
cfg.pw_mode.nonface_only = [3,4];
cfg.pw_mode.hetero = [1,2;3,4];
cfg.pw_mode.total = [1,2,3,4];

%% ===================================================================
%  ANALYSIS SETTINGS
%  ===================================================================

% Method for organizing trials into analysis units
cfg.slice_method = 'blocks';  % Options: 'trials', 'blocks'

% Attribute used to define cross-validation folds
cfg.fold_by = 'blocknum';  % Each block becomes a separate fold

% Analysis versions to run
% These define different train/test configurations
cfg.versions_to_run = {'all_all', 'intact_intact', 'intact_occl'};

%% ===================================================================
%  DECODING ANALYSES CONFIGURATION
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
cfg.decode_type(end).preprocess_func = @(ds, cfg) cosmo_slice(ds, find(ismember(ds.sa.stimnum, cfg.stimnum.occl_level.intact)));
cfg.decode_type(end).target_func = @(ds, stimnum) double(ismember(ds.sa.stimnum, stimnum.face));
cfg.decode_type(end).chunk_func =  @(ds) ds.sa.blocknum;
cfg.decode_type(end).custom_partitioner = @(ds, cfg) train_intact_test_occl(ds, cfg);
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
    cellstr(categorical(ds.sa.targets, [1 0], {'face', 'non-face'}))));


% --- 2. Identity Decoding (4 unique objects) ---
cfg.decode_type(end+1).name = 'identity';
cfg.decode_type(end).n_classes = 4;
cfg.decode_type(end).preprocess_func = @(ds, cfg) cosmo_slice(ds, find(ismember(ds.sa.stimnum, cfg.stimnum.occl_level.intact)));
cfg.decode_type(end).target_func = @(ds, identity) assign_class_labels(ds.sa.stimnum, identity);
cfg.decode_type(end).chunk_func =  @(ds) ds.sa.blocknum;
cfg.decode_type(end).custom_partitioner = @(ds, cfg) train_intact_test_occl(ds, cfg);
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
    cellstr(categorical(ds.sa.targets, [1 2 3 4], ...
    {'bear', 'penguin', 'rocket', 'tower'}))));


% --- 3. Color Decoding (Blue vs. Pink) ---
cfg.decode_type(end+1).name = 'color';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).preprocess_func = @(ds, cfg) cosmo_slice(ds, find(ismember(ds.sa.stimnum, cfg.stimnum.occl_level.intact)));
cfg.decode_type(end).target_func = @(ds, color) double(ismember(ds.sa.stimnum, color.blue));
cfg.decode_type(end).chunk_func = @(ds) ds.sa.blocknum;
cfg.decode_type(end).custom_partitioner = @(ds, cfg) train_intact_test_occl(ds, cfg);
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
    cellstr(categorical(ds.sa.targets, [0 1], {'pink', 'blue'}))));


% --- 4. Size Decoding (Small (300px) vs. Large (500px)) ---
cfg.decode_type(end+1).name = 'size';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).preprocess_func = @(ds, cfg) cosmo_slice(ds, find(ismember(ds.sa.stimnum, cfg.stimnum.occl_level.intact)));
cfg.decode_type(end).target_func =  @(ds, cfg) decode_size(ds, cfg,'2class').sa.targets;
cfg.decode_type(end).chunk_func = @(ds) ds.sa.blocknum;
cfg.decode_type(end).custom_partitioner = @(ds, cfg) train_intact_test_occl(ds, cfg);
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
    cellstr(categorical(ds.sa.targets, [0 1], {'small', 'large'}))));


% --- 5. Occlusion Level (Occluded vs Intact) ---
cfg.decode_type(end+1).name = 'occl_level';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).preprocess_func = [];
cfg.decode_type(end).target_func = @(ds, occl_level) double(ismember(ds.sa.stimnum, occl_level.intact));
cfg.decode_type(end).chunk_func = @(ds) ds.sa.blocknum;
cfg.decode_type(end).custom_partitioner = [];
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
    cellstr(categorical(ds.sa.targets, [0 1], {'occluded', 'intact'}))));


% --- 6. Occluder Position (Left vs Right) ---
cfg.decode_type(end+1).name = 'occl_pos';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).preprocess_func = @(ds, cfg) ...
    cosmo_slice(ds, find(ismember(ds.sa.stimnum, cfg.stimnum.occl_level.occluded)));
cfg.decode_type(end).target_func = @(ds, occl_pos) ...
    double(ismember(ds.sa.stimnum, occl_pos.left));
cfg.decode_type(end).chunk_func = @(ds) ds.sa.blocknum;
cfg.decode_type(end).custom_partitioner = [];
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
    cellstr(categorical(ds.sa.targets, [0 1], {'left', 'right'}))));


% --- 7. Occluder Spatial Frequency (Low vs High) ---
cfg.decode_type(end+1).name = 'occl_sfreq';
cfg.decode_type(end).n_classes = 2;
cfg.decode_type(end).preprocess_func = @(ds, cfg) ...
    cosmo_slice(ds, find(ismember(ds.sa.stimnum, cfg.stimnum.occl_level.occluded)));
cfg.decode_type(end).target_func = @(ds, occl_sfreq) ...
    double(ismember(ds.sa.stimnum, occl_sfreq.high));
cfg.decode_type(end).chunk_func = @(ds) ds.sa.blocknum;
cfg.decode_type(end).custom_partitioner = [];
cfg.decode_type(end).label_func = @(ds) ...
    setfield(ds, 'sa', setfield(ds.sa, 'labels', ...
    cellstr(categorical(ds.sa.targets, [0 1], {'low', 'high'}))));

%% ===================================================================
%  CLASSIFIER CONFIGURATION
%  ===================================================================

cfg.classifier = @cosmo_classify_lda;  % Linear Discriminant Analysis

%% ===================================================================
%  PARTICIPANT INFORMATION
%  ===================================================================
% Load participant metadata from LabNotebook.csv
notebook_path = fullfile(cfg.project_path, 'docs', 'LabNotebook.csv');


cfg.participants_info = struct();

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
cfg.participants_info(end).to_run = true;                                       % Include in analysis
cfg.participants_info(end).eeg_system = 'BrainVision';                           % EEG file format 
cfg.participants_info(end).n_subjects = height(dataTable);                      % Number of infant participants
cfg.participants_info(end).isgood = dataTable.BlocksIncludedInTheFinalAnalysis; % Valid blocks per participant
cfg.participants_info(end).labnotebook = dataTable;                             % Full participant info table

% -------------------------------------------------------------------
% GROUP 2: Adult Participants
% -------------------------------------------------------------------
cfg.participants_info(end+1).name = 'adults';
cfg.participants_info(end).to_run = true;           % Include in analysis
cfg.participants_info(end).eeg_system = 'BioSemi';  % EEG file format
cfg.participants_info(end).n_subjects = 20;         % Number of adult participants
cfg.participants_info(end).isgood = 1:15;           % Valid blocks/trials indicator
cfg.participants_info(end).labnotebook = [];        % No separate notebook for adults

%% ===================================================================
%  OUTPUT OPTIONS
%  ===================================================================

cfg.plot_results = 1;  % Generate visualization plots (1=yes, 0=no)
cfg.savefile = 1;      % Save results to file (1=yes, 0=no)
cfg.overwrite = 1;     % Overwrite existing results (1=yes, 0=no)

end