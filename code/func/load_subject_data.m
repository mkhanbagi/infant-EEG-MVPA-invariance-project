%% =======================================================================
%% HELPER FUNCTIONS
%% =======================================================================
function [ds, size_info] = load_subject_data(cfg, subjectnr)
% LOAD_SUBJECT_DATA  Load a subject's CoSMoMVPA dataset and behavioral info.
%
%   [ds, size_info] = LOAD_SUBJECT_DATA(cfg, subjectnr)
%
% Inputs
%   cfg        : struct with required fields:
%                  - preproc_dir            : base directory for preprocessed data
%                  - project_path           : project root directory
%                  - participants_info.name : participant group/folder name
%   subjectnr  : scalar numeric subject index (e.g., 1, 2, 3, ...)
%
% Outputs
%   ds         : CoSMoMVPA dataset (loaded from MAT file)
%   size_info  : vector of stimulus sizes for valid trials (rows with non-NaN
%                stim onset times and non-NaN stimsize)
%
% Side effects
%   Prints brief status messages and raises errors if files are missing.
%
% Notes
%   - Trials with NaN 'time_stimon' are excluded (not presented/missing).
%   - From remaining trials, 'stimsize' NaNs are dropped for size_info.
%   - Uses fullfile to stay OS-portable.
%
% Example
%   [ds, sz] = load_subject_data(cfg, 7);

% -----------------------------
% Basic input validation
% -----------------------------
assert(isstruct(cfg),       'cfg must be a struct.');
assert(isscalar(subjectnr) && isnumeric(subjectnr) && subjectnr==fix(subjectnr) && subjectnr>0, ...
    'subjectnr must be a positive integer scalar.');

reqFields = {'preproc_dir','project_path','participants_info'};
cellfun(@(f) assert(isfield(cfg,f), 'cfg.%s is required.', f), reqFields);
assert(isfield(cfg.participants_info,'name'), 'cfg.participants_info.name is required.');

subj_tag = sprintf('sub-%02i', subjectnr);

% -----------------------------
% Build paths
% -----------------------------
% Path to CoSMoMVPA dataset MAT file
data_file = fullfile( ...
    cfg.preproc_dir, ...
    cfg.participants_info.name, ...
    subj_tag, ...
    'cosmo', ...
    sprintf('%s_cosmomvpa.mat', subj_tag) ...
    );

% Path to behavioral CSV file
if strcmp(cfg.project, 'viewpoint')
    csv_pattern = 'task-targets_events';
elseif strcmp(cfg.project, 'occlusion')
    csv_pattern = 'occlusion_events';
end
behav_file = fullfile( ...
    cfg.project_path, ...
    'data', 'raw', ...
    cfg.participants_info.name, ...
    subj_tag, ...
    'eeg', ...
    sprintf('%s_%s.csv', subj_tag, csv_pattern) ...
    );

% -----------------------------
% Load CoSMoMVPA dataset
% -----------------------------
if ~isfile(data_file)
    error('Dataset not found:\n  %s', data_file);
end
S = load(data_file);               % expect variable 'ds' inside
assert(isfield(S,'ds'), 'File does not contain variable ''ds'': %s', data_file);
ds = S.ds;
fprintf('[DATA] Loaded dataset: %s\n', data_file);

% -----------------------------
% Load behavioral table
% -----------------------------
if ~isfile(behav_file)
    error('Behavioral file not found:\n  %s', behav_file);
end
T = readtable(behav_file);

% Map column names by project (case-insensitive)
switch lower(string(cfg.project))
    case "viewpoint"
        onset_col = "time_stimon";
        size_col  = "stimsize";
    case "occlusion"
        onset_col = "StimOnset";
        size_col  = "StimSize";
    otherwise
        error('Unknown cfg.project value: %s', string(cfg.project));
end

% Defensive checks for required columns (case-sensitive to match table vars)
reqCols = {char(onset_col), char(size_col)};
for c = reqCols
    assert(ismember(c{1}, T.Properties.VariableNames), ...
        'Behavioral file missing required column ''%s'': %s', c{1}, behav_file);
end

% Coerce columns to numeric (handles string/cellstr gracefully)
onset_raw = T.(onset_col);
if iscell(onset_raw), onset_raw = string(onset_raw); end
if isstring(onset_raw) || ischar(onset_raw)
    onset_val = str2double(onset_raw);
else
    onset_val = double(onset_raw);
end

size_raw = T.(size_col);
if iscell(size_raw), size_raw = string(size_raw); end
if isstring(size_raw) || ischar(size_raw)
    size_val = str2double(size_raw);
else
    size_val = double(size_raw);
end

% Keep trials with a valid stimulus onset time
valid_onset = ~isnan(onset_val);
T = T(valid_onset, :);
onset_val = onset_val(valid_onset); %#ok<NASGU> % keep if you need it later
size_val  = size_val(valid_onset);

% Extract stimulus sizes for rows with valid (non-NaN) size
size_info = size_val(~isnan(size_val));
size_info = size_info(:);  % column vector

fprintf('[DATA] Loaded behavioral data: %d valid trials (with %s)\n', ...
    height(T), onset_col);
end
