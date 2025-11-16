function ds = convert_to_cosmo(EEG_epoch, stimnum, blocknum, subjectnr, cfg)
% CONVERT_TO_COSMO - Convert EEGLAB epoched data to CoSMoMVPA format
%
% This function transforms epoched EEGLAB EEG data into a CoSMoMVPA-compatible
% dataset structure. It handles the complex dimension transformations required
% to convert from EEGLAB's (channels × time × trials) format to CoSMoMVPA's
% (samples × features) format, where each trial becomes a sample and each
% channel-time combination becomes a feature.
%
% Inputs:
%   EEG_epoch - EEGLAB epoched EEG structure with fields:
%               .data     : 3D array (channels × time × trials)
%               .chanlocs : Channel location structure with .labels
%               .times    : Time vector in milliseconds
%   
%   stimnum   - Vector of stimulus numbers for each epoch
%               Length must match number of trials
%               Example: [1, 5, 23, 12, ...] for 64-stimulus experiment
%   
%   blocknum  - Vector of block/run numbers for each epoch
%               Length must match number of trials
%               Used for cross-validation fold assignment
%   
%   subjectnr - Numeric subject identifier (e.g., 1, 2, 3)
%               Used for constructing output filename
%   
%   cfg       - Configuration struct containing:
%               .preproc_dir        : Root directory for preprocessed data
%               .participants_info  : Struct with .name field (e.g., 'infants', 'adults')
%
% Output:
%   ds - CoSMoMVPA dataset structure with fields:
%        .samples  : (trials × features) matrix of EEG data
%                    Features = channels × timepoints
%        .sa       : Sample attributes (per trial)
%          .stimnum  : Stimulus number for each trial
%          .blocknum : Block number for each trial
%        .fa       : Feature attributes (per channel-time combination)
%          .chan     : Channel index for each feature
%          .time     : Time point for each feature
%        .a        : Dataset-level attributes
%          .fdim     : Feature dimensions (channel names, time values)
%          .meeg     : MEEG-specific metadata
%
% Output File:
%   Saves dataset as: preproc_dir/group/sub-XX/cosmo/sub-XX_cosmomvpa.mat
%   Uses -v7.3 format for compatibility with large datasets (>2GB)
%
% Dependencies:
%   - CoSMoMVPA toolbox (https://cosmomvpa.org)
%     Required functions: cosmo_flatten, cosmo_check_dataset
%
% Example:
%   cfg.preproc_dir = '/path/to/data';
%   cfg.participants_info.name = 'infants';
%   ds = convert_to_cosmo(EEG, stimnum, blocknum, 5, cfg);
%   % Saves: /path/to/data/infants/sub-05/cosmo/sub-05_cosmomvpa.mat
%
% Notes:
%   - EEGLAB stores data as (channels × time × trials)
%   - CoSMoMVPA requires (samples × features) where samples = trials
%   - The permute() operation reorders dimensions to (trials × channels × time)
%   - cosmo_flatten() then reshapes to (trials × channels*time)
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/07/2025]
% Modified: [13/10/2025]


%% ===================================================================
%  CONSTRUCT OUTPUT FILEPATH
%  ===================================================================

% Create standardized filename following BIDS-like naming convention
% Format: sub-XX_cosmomvpa.mat (zero-padded subject number)
cosmofile = sprintf('sub-%02i_cosmomvpa.mat', subjectnr);

% Build complete directory path
% Structure: preproc_dir/group/sub-XX/cosmo/
% Example: /data/preprocessed/infants/sub-05/cosmo/
file_path = fullfile(cfg.preproc_dir, ...                             % Root preprocessed data dir
                     cfg.participants_info.name, ...                  % Group name (infants/adults)
                     sprintf('sub-%02i', subjectnr), ...              % Subject folder
                     'cosmo');                                        % CoSMoMVPA subfolder

%% ===================================================================
%  DIMENSION TRANSFORMATION
%  ===================================================================

% --- Step 1: Permute dimensions ---
% EEGLAB format: (channels × time × trials)
% Need format:   (trials × channels × time) for cosmo_flatten
%
% permute([3 1 2]) reorders dimensions:
%   Dimension 1 (channels) → becomes dimension 2
%   Dimension 2 (time)     → becomes dimension 3  
%   Dimension 3 (trials)   → becomes dimension 1
data_permuted = permute(EEG_epoch.data, [3 1 2]);

% --- Step 2: Flatten to CoSMoMVPA format ---
% cosmo_flatten reshapes (trials × channels × time) into (trials × features)
% where features = channels * timepoints
%
% Arguments:
%   data_permuted           : Input array to flatten
%   {'chan', 'time'}        : Names of feature dimensions to flatten
%   {channel_labels, times} : Values for each feature dimension
%   2                       : Starting dimension index (dimensions 2 and 3 become features)
ds = cosmo_flatten(data_permuted, ...
                   {'chan', 'time'}, ...                                % Feature dimension names
                   {{EEG_epoch.chanlocs.labels}, EEG_epoch.times}, ...  % Feature dimension values
                   2);                                                  % Start flattening from dim 2

%% ===================================================================
%  ADD METADATA
%  ===================================================================

% Initialize MEEG-specific metadata structure
% Required for CoSMoMVPA to recognize this as an MEEG dataset
ds.a.meeg = struct();

% --- Assign sample attributes (one value per trial) ---
% These are used for labeling and cross-validation

% Stimulus number: which stimulus was presented in this trial
% May need to truncate if there's a mismatch in lengths (safety check)
ds.sa.stimnum = stimnum(1:size(ds.samples, 1));

% Block number: which experimental block/run this trial came from
% Used for cross-validation (e.g., leave-one-block-out)
ds.sa.blocknum = blocknum(1:size(ds.samples, 1));

%% ===================================================================
%  VALIDATE DATASET
%  ===================================================================

% Verify that the dataset structure is valid for MEEG analysis
% This checks:
%   - Required fields exist (.samples, .sa, .fa, .a)
%   - Dimensions are consistent
%   - MEEG-specific requirements are met
cosmo_check_dataset(ds, 'meeg');

%% ===================================================================
%  SAVE TO FILE
%  ===================================================================

% Create output directory if it doesn't exist
if ~exist(file_path, 'dir')
    mkdir(file_path);
    fprintf('[INFO] Created directory: %s\n', file_path);
end

% Construct full file path
filename = fullfile(file_path, cosmofile);

% Save dataset using -v7.3 format
% -v7.3 is required for datasets larger than 2GB
% This format uses HDF5 and allows partial loading of large datasets
save(filename, 'ds', '-v7.3');

% Confirmation message
fprintf('[INFO] Saved CoSMoMVPA dataset for subject %02i\n', subjectnr);
fprintf('       File: %s\n', filename);
fprintf('       Size: %d samples × %d features\n', size(ds.samples, 1), size(ds.samples, 2));