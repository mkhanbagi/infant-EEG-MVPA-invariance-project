% preprocessing_config - EEG preprocessing configuration generator
%
% Author: [Mahdiyeh Khanbagi]
% Created: [20/07/2025]
% Modified: [11/10/2025]
%
% Generates configuration parameters for EEG preprocessing pipeline.
% Handles both infant (BrainVision) and adult (Biosemix) participant data.
%
% Usage:
%   cfg = preprocessing_config(project_name)
%
% Input:
%   project_name - Name of the project folder (string)
%
% Output:
%   cfg - Configuration struct containing:
%         - Path definitions
%         - Filtering parameters
%         - Participant information from LabNotebook.csv
%         - Output format options

function cfg = preprocessing_config(project_name)

cfg = struct();

%% ===================================================================
%  PATH CONFIGURATION
%  ===================================================================
cfg.project_root   = fullfile(getenv('HOME'), 'Documents', 'PhD', 'Project');
cfg.project_path   = fullfile(cfg.project_root, project_name);
cfg.data_dir       = fullfile(cfg.project_path, 'data');
cfg.rawdata_dir    = fullfile(cfg.data_dir, 'raw');
cfg.preproc_dir    = fullfile(cfg.data_dir, 'preprocessed');

%% ===================================================================
%  SIGNAL PROCESSING PARAMETERS
%  ===================================================================
cfg.HighPass        = 0.5;   % High-pass filter cutoff (Hz) - removes slow drifts
cfg.LowPass         = 40;    % Low-pass filter cutoff (Hz) - removes high-freq noise
cfg.downsample      = 250;   % Target sampling rate (Hz); 0 = no downsampling
cfg.clean_rawdata   = 0;     % Use EEGLAB Clean Rawdata plugin (0=off, 1=on)

%% ===================================================================
%  PARTICIPANT INFORMATION
%  ===================================================================
% Load participant metadata from LabNotebook.csv
notebook_path = fullfile(cfg.project_path, 'docs', 'LabNotebook.csv');

if ~isfile(notebook_path)
    error('LabNotebook.csv not found at: %s', notebook_path);
end

% Import participant data
opts = detectImportOptions(notebook_path);
dataTable = readtable(notebook_path, opts);

% Select relevant columns
relevant_cols = {
    'x_ID', ...                                    % Participant ID
    'Gender', ...                                  % Participant gender
    'DateOfBirth', ...                             % Birth date
    'Age_months_', ...                             % Age in months
    'Age_days_', ...                               % Age in days
    'No_BlocksRecorded', ...                       % Total blocks recorded
    'BlocksIncludedInTheFinalAnalysis', ...        % Valid blocks (comma-separated)
    'Includ_OrExclud_' ...                         % Inclusion/exclusion status
};
dataTable = dataTable(:, relevant_cols);

% Parse block inclusion info (convert "1,2,3" string to [1 2 3] array)
dataTable.BlocksIncludedInTheFinalAnalysis = cellfun(@str2num, ...
    dataTable.BlocksIncludedInTheFinalAnalysis, 'UniformOutput', false);

% Initialize participant groups
cfg.participants_info = struct([]);

% --- Infant Group ---
cfg.participants_info(end+1).name        = 'infants';
cfg.participants_info(end).eeg_system    = 'BrainVision';
cfg.participants_info(end).n_subjects    = height(dataTable);
cfg.participants_info(end).isgood        = dataTable.BlocksIncludedInTheFinalAnalysis;  % Cell array of valid blocks per subject
cfg.participants_info(end).labnotebook   = dataTable;

% --- Adult Group ---
cfg.participants_info(end+1).name        = 'adults';
cfg.participants_info(end).eeg_system    = 'Biosemix';
cfg.participants_info(end).n_subjects    = 20;      
cfg.participants_info(end).isgood        = 1:50;   
cfg.participants_info(end).labnotebook   = [];

%% ===================================================================
%  OUTPUT OPTIONS
%  ===================================================================
cfg.setfile    = 1;           % Save EEGLAB .set format (0=no, 1=yes)
cfg.savemode   = 'onefile';   % Save mode: 'onefile' or 'twofiles' (.set/.fdt)
cfg.cosmofile  = 1;           % Export to CoSMoMVPA format (0=no, 1=yes)
cfg.overwrite  = 0;           % Overwrite existing files (0=no, 1=yes)

end