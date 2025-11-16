function EEG = load_and_organize_raw_data(subjectnr, cfg)
% LOAD_AND_ORGANIZE_RAW_DATA - Load raw EEG data and organize into project structure
%
% This function loads raw EEG data for a given subject and organizes the file
% into the project's directory structure following BIDS-like conventions. It
% handles multiple EEG systems (BrainVision, BioSemi) and automatically moves
% files from 'sourcedata' to the organized 'raw' directory structure.
%
% File Organization Strategy:
%   1. First checks destination folder (raw/group/sub-XX/eeg/) in case file
%      was already organized in a previous run
%   2. If not found, checks sourcedata folder for raw data files
%   3. Loads the EEG data using appropriate loader for the system
%   4. Moves files from sourcedata to destination (if loading from source)
%   5. Also moves associated CSV files if present
%
% Inputs:
%   subjectnr - Numeric subject identifier (e.g., 1, 2, 3, ...)
%               Used to construct filenames and directory paths
%   
%   cfg       - Configuration struct containing:
%               .data_dir              : Root data directory path
%               .participants_info     : Struct with fields:
%                 .name                : Group name ('infants', 'adults')
%                 .eeg_system          : EEG system type ('BrainVision' or 'BioSemi')
%
% Output:
%   EEG - EEGLAB EEG structure containing loaded raw data with fields:
%         .data      : Continuous EEG data (channels × timepoints)
%         .srate     : Sampling rate in Hz
%         .chanlocs  : Channel locations structure
%         .event     : Event structure with stimulus markers
%         .etc       : Additional metadata
%
% Supported EEG Systems:
%   BrainVision: Loads .xdf files using pop_loadxdf
%                Filename: sub-PXXX_ses-S001_task-Default_run-001_eeg.xdf
%   
%   BioSemi:     Loads .bdf files using pop_readbdf
%                Filename: subXX_*.bdf (supports wildcards)
%
% Directory Structure:
%   Before:  data_dir/sourcedata/sub-XX_*.{xdf,bdf,csv}
%   After:   data_dir/raw/group/sub-XX/eeg/sub-XX_*.{xdf,bdf,csv}
%
% Dependencies:
%   - EEGLAB must be installed and on the MATLAB path
%   - XDF plugin (for BrainVision): pop_loadxdf
%   - BioSemi plugin: pop_readbdf or pop_biosig
%
% Error Conditions:
%   - Unknown EEG system specified in cfg
%   - No matching files found in sourcedata
%   - File not found in either sourcedata or destination
%
% Example:
%   cfg.data_dir = '/path/to/project/data';
%   cfg.participants_info.name = 'infants';
%   cfg.participants_info.eeg_system = 'BrainVision';
%   EEG = load_and_organize(5, cfg);
%   % Loads: sourcedata/sub-P005_ses-S001_task-Default_run-001_eeg.xdf
%   % Moves to: raw/infants/sub-05/eeg/
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/07/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  DETERMINE EEG SYSTEM AND CONSTRUCT FILENAME
%  ===================================================================

% Define filename pattern and loading function based on EEG system type
if strcmp(cfg.participants_info.eeg_system, 'BrainVision')
    % --- BrainVision System (.xdf files) ---
    % Filename format: sub-PXXX_ses-S001_task-Default_run-001_eeg.xdf
    % Uses 3-digit zero-padded subject number with 'P' prefix
    eegfile = sprintf('sub-P%03i_ses-S001_task-Default_run-001_eeg.xdf', subjectnr);
    
    % Set appropriate loading function for XDF format
    load_func = @pop_loadxdf;
    
elseif strcmp(cfg.participants_info.eeg_system, 'BioSemi')
    % --- BioSemi System (.bdf files) ---
    % Filename format: subXX_*.bdf (may have additional naming variations)
    % Uses 2-digit zero-padded subject number
    
    % Construct wildcard pattern to handle filename variations
    pattern = sprintf('sub%02i_*.bdf', subjectnr);
    
    % Search sourcedata folder for matching files
    files = dir(fullfile(cfg.data_dir, 'sourcedata', pattern));
    
    % Check if any matching files were found
    if isempty(files)
        error('No BDF file found matching pattern: %s', pattern);
    end
    
    % Use first matching file if multiple exist
    eegfile = files(1).name;
    
    % Set appropriate loading function for BDF format
    load_func = @pop_readbdf;  % Alternative: @pop_biosig
    
else
    % Unknown EEG system specified
    error('Unknown EEG system: %s. Supported systems: BrainVision, BioSemi', ...
          cfg.participants_info.eeg_system);
end

%% ===================================================================
%  CONSTRUCT FILE PATHS
%  ===================================================================

% Build destination directory path following BIDS-like structure
% Structure: data_dir/raw/group/sub-XX/eeg/
destination_dir = fullfile(cfg.data_dir, ...                          % Raw data directory
                          'raw', ...                                  % Group (infants/adults)
                          sprintf('%s_sub-%02i', cfg.participants_info.name, ... 
                          subjectnr), ...                             % Subject number
                          'eeg');                                     % EEG modality folder

% Construct full paths for source and destination EEG files
out_eegfile = fullfile(destination_dir, eegfile);                    % Final organized location
source_eegfile = fullfile(cfg.data_dir, 'sourcedata', eegfile);      % Original sourcedata location

%% ===================================================================
%  LOAD EEG DATA (with smart file location handling)
%  ===================================================================

% Try to load from destination first (in case already organized),
% then fall back to sourcedata (for initial organization)

if exist(out_eegfile, 'file')
    % --- Case 1: File already organized ---
    % File exists in destination (already moved in previous run)
    fprintf('[INFO] Loading EEG data from organized location:\n');
    fprintf('       %s\n', out_eegfile);
    EEG = load_func(out_eegfile);
    
elseif exist(source_eegfile, 'file')
    % --- Case 2: File in sourcedata (needs organization) ---
    % File exists in sourcedata folder, load and organize
    fprintf('[INFO] Loading EEG data from sourcedata:\n');
    fprintf('       %s\n', source_eegfile);
    EEG = load_func(source_eegfile);
    
    % Create destination directory if it doesn't exist
    if ~exist(destination_dir, 'dir')
        mkdir(destination_dir);
        fprintf('[INFO] Created directory: %s\n', destination_dir);
    end
    
    % Move EEG file from sourcedata to organized structure
    movefile(source_eegfile, out_eegfile);
    fprintf('[INFO] Moved EEG file to: %s\n', out_eegfile);
    
    %% ---------------------------------------------------------------
    %  HANDLE ASSOCIATED CSV FILES
    %  ---------------------------------------------------------------
    % Some EEG systems include CSV files with behavioral/marker data
    % Look for and move any associated CSV files for this subject
    
    % Construct CSV search pattern
    csvpattern = sprintf('sub-%02i_*.csv', subjectnr);
    
    % Search for matching CSV files in sourcedata
    csvfiles = dir(fullfile(cfg.data_dir, 'sourcedata', csvpattern));
    
    if ~isempty(csvfiles)
        % CSV file(s) found - move to destination
        source_csvfile = fullfile(cfg.data_dir, 'sourcedata', csvfiles(1).name);
        out_csvfile = fullfile(destination_dir, csvfiles(1).name);
        
        movefile(source_csvfile, out_csvfile);
        fprintf('[INFO] Moved CSV file to: %s\n', out_csvfile);
    end
    
else
    % --- Case 3: File not found ---
    % File doesn't exist in either location - cannot proceed
    error(['Raw EEG file not found for subject %02i.\n', ...
           'Checked locations:\n', ...
           '  1. %s\n', ...
           '  2. %s'], ...
           subjectnr, out_eegfile, source_eegfile);
end

%% ===================================================================
%  COMPLETION MESSAGE
%  ===================================================================

fprintf('[SUCCESS] Subject %02i data loaded and organized\n', subjectnr);
fprintf('          Channels: %d\n', EEG.nbchan);
fprintf('          Sampling rate: %.1f Hz\n', EEG.srate);
fprintf('          Duration: %.1f seconds\n', EEG.xmax);

end