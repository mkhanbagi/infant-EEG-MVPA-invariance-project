function [EEG_epoch, ds] = run_preprocess(subjectnr, cfg, varargin)
% RUN_PREPROCESS - Complete EEG preprocessing pipeline for single subject
%
% This function executes the full preprocessing pipeline for a single subject's
% EEG data, from raw data loading through filtering, epoching, and conversion
% to analysis-ready formats (EEGLAB .set and CoSMoMVPA dataset).
%
% Processing Pipeline:
%   1. Load raw EEG data and organize into project structure
%   2. Apply filters (high-pass, low-pass), optional cleaning, re-referencing
%   3. Epoch continuous data around stimulus events
%   4. Save preprocessed data (optional: .set file, CoSMoMVPA file)
%
% Inputs:
%   subjectnr - Integer subject identifier (e.g., 1, 2, 3, ...)
%               Used for file naming and directory organization
%   
%   cfg       - Configuration struct from preprocessing_config() with fields:
%               .participants_info : Subject and group information
%               .data_dir         : Root data directory
%               .preproc_dir      : Preprocessed data output directory
%               .HighPass         : High-pass filter cutoff (Hz)
%               .LowPass          : Low-pass filter cutoff (Hz)
%               .downsample       : Target sampling rate (Hz, 0=skip)
%               .clean_rawdata    : Apply Clean Rawdata plugin (true/false)
%               .setfile          : Save EEGLAB .set file (true/false)
%               .cosmofile        : Save CoSMoMVPA dataset (true/false)
%               .overwrite        : Overwrite existing files (true/false)
%   
%   varargin  - Optional name-value pairs to override cfg fields
%               Examples: 'HighPass', 0.5, 'downsample', 250
%
% Outputs:
%   EEG_epoch - EEGLAB structure containing epoched EEG data
%               .data   : 3D array (channels × timepoints × trials)
%               .times  : Time vector relative to stimulus onset
%               .epoch  : Epoch metadata
%   
%   ds        - CoSMoMVPA dataset structure (if cfg.cosmofile = true)
%               .samples : 2D array (trials × features)
%               .sa      : Sample attributes (.stimnum, .blocknum)
%               Empty array [] if cosmofile = false
%
% File Outputs:
%   - EEGLAB .set file: preproc_dir/group/sub-XX/eeg/sub-XX_eeg.set
%   - CoSMoMVPA file:   preproc_dir/group/sub-XX/cosmo/sub-XX_cosmomvpa.mat
%
% Example Usage:
%   % Use default config settings
%   cfg = preprocessing_config();
%   [EEG, ds] = run_preprocess(5, cfg);
%   
%   % Override specific parameters
%   [EEG, ds] = run_preprocess(5, cfg, 'HighPass', 0.5, 'downsample', 250);
%   
%   % Skip CoSMoMVPA conversion
%   [EEG, ~] = run_preprocess(5, cfg, 'cosmofile', 0);
%
% Dependencies:
%   - EEGLAB toolbox
%   - CoSMoMVPA toolbox (if cosmofile = true)
%   - Clean Rawdata plugin (if clean_rawdata = true)
%
% See also: LOAD_AND_ORGANIZE, APPLY_FILTERS_AND_CLEAN, EPOCH_EEG_DATA,
%           CONVERT_TO_COSMO, SAVE_EEGLAB_SET
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/07/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  PARSE OPTIONAL ARGUMENTS
%  ===================================================================

% Override config fields with any name-value pairs provided via varargin
% This allows flexible parameter adjustment without modifying the config file
if ~isempty(varargin)
    cfg = parse_varargin(cfg, varargin);
end

%% ===================================================================
%  DISPLAY PREPROCESSING SETTINGS
%  ===================================================================

fprintf('[INFO] Starting preprocessing for subject %02i\n', subjectnr);

% Display overwrite mode for user awareness
if cfg.overwrite == 1
    fprintf('[INFO] Overwriting enabled. Existing files will be replaced.\n');
else
    fprintf('[INFO] Overwriting disabled. Existing files will be skipped.\n');
end

%% ===================================================================
%  STEP 1: LOAD RAW EEG DATA
%  ===================================================================

% Load raw EEG file and organize into project directory structure
% Automatically determines data location based on group (infant/adult)
% Moves files from sourcedata to organized raw directory if needed
%
% Note: Function name in code is load_and_organize_raw_data but may have
% been renamed to load_and_organize in project updates
EEG_raw = load_and_organize_raw_data(subjectnr, cfg);

fprintf('[INFO] Raw EEG data loaded: %d channels, %.1f Hz, %.1f seconds\n', ...
        EEG_raw.nbchan, EEG_raw.srate, EEG_raw.xmax);

%% ===================================================================
%  STEP 2: APPLY FILTERS AND CLEANING
%  ===================================================================

% Apply preprocessing filters and optional artifact cleaning:
%   - High-pass filter: Remove slow drifts and DC offset
%   - Low-pass filter: Remove high-frequency noise
%   - Clean Rawdata: Automatic artifact rejection (if enabled)
%   - Re-referencing: Average reference across channels
%   - Downsampling: Reduce sampling rate (if requested)
EEG_clean = apply_filters_and_clean(EEG_raw, cfg);

fprintf('[INFO] Filtering and cleaning complete\n');
fprintf('       High-pass: %.2f Hz, Low-pass: %.2f Hz\n', ...
        cfg.HighPass, cfg.LowPass);
if cfg.downsample > 0
    fprintf('       Downsampled to: %d Hz\n', cfg.downsample);
end

%% ===================================================================
%  STEP 3: EPOCH DATA AROUND STIMULUS EVENTS
%  ===================================================================

% Segment continuous EEG into stimulus-locked epochs
% Extracts stimulus numbers and block numbers from event markers
% Creates epochs from -100ms to +800ms around each stimulus onset
[EEG_epoch, stimnum, blocknum] = epoch_eeg_data(EEG_clean);

fprintf('[INFO] Epoching complete: %d epochs created\n', EEG_epoch.trials);
fprintf('       Epoch window: [%.1f, %.1f] seconds\n', ...
        EEG_epoch.xmin, EEG_epoch.xmax);

%% ===================================================================
%  STEP 4: SAVE EEGLAB .SET FILE (Optional)
%  ===================================================================

% Save preprocessed data in EEGLAB format (.set and .fdt files)
% Note: Currently saves EEG_raw (unprocessed), but this may be intended
% to save EEG_epoch (epoched data) or EEG_clean (continuous filtered data)
if cfg.setfile
    fprintf('[INFO] Saving EEGLAB .set file...\n');
    save_eeglab_set(EEG_raw, subjectnr, cfg);
end

%% ===================================================================
%  STEP 5: CONVERT TO COSMOMVPA FORMAT (Optional)
%  ===================================================================

% Convert epoched EEGLAB data to CoSMoMVPA format for MVPA decoding
% Creates dataset structure with:
%   - .samples: trials × features matrix (features = channels × timepoints)
%   - .sa: sample attributes (stimnum, blocknum for each trial)
%   - .fa: feature attributes (channel, time for each feature)
if cfg.cosmofile
    fprintf('[INFO] Converting to CoSMoMVPA format...\n');
    ds = convert_to_cosmo(EEG_epoch, stimnum, blocknum, subjectnr, cfg);
else
    % No CoSMoMVPA conversion requested
    ds = [];
end

%% ===================================================================
%  COMPLETION MESSAGE
%  ===================================================================

fprintf('[INFO] Preprocessing complete for subject %02i\n', subjectnr);
fprintf('       Ready for analysis!\n');

end