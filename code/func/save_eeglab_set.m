function save_eeglab_set(EEG, subjectnr, cfg)
% SAVE_EEGLAB_SET - Save EEG dataset in EEGLAB .set format
%
% This function saves an EEGLAB EEG structure to disk using the standard
% .set format. It handles directory creation and supports both single-file
% and two-file save modes (where large datasets are split into .set and .fdt).
%
% The file is saved in an organized directory structure following BIDS-like
% conventions: preproc_dir/group/sub-XX/eeglab/
%
% Inputs:
%   EEG       - EEGLAB EEG structure to be saved
%               Must contain standard EEGLAB fields (.data, .chanlocs, etc.)
%   
%   subjectnr - Numeric subject identifier (e.g., 1, 2, 3, ...)
%               Used for constructing filename and directory path
%   
%   cfg       - Configuration struct containing:
%               .preproc_dir        : Root directory for preprocessed data
%               .participants_info  : Struct with .name field (group name)
%               .savemode           : Save format option
%                                     'onefile'  : Single .set file (default)
%                                     'twofiles' : Separate .set and .fdt files
%
% Output:
%   None - Saves file(s) to disk
%
% File Naming:
%   Filename: sub##.set (where ## is zero-padded subject number)
%   Examples: sub01.set, sub05.set, sub23.set
%
% Save Modes:
%   'onefile':  All data stored in single .set file
%               - Simpler file management
%               - Slower for very large datasets
%   
%   'twofiles': Data split into .set (metadata) and .fdt (raw data)
%               - Faster loading for large files
%               - Two files must stay together
%
% Directory Structure:
%   Output path: preproc_dir/group/sub-XX/eeglab/sub##.set
%   Example:     /data/preprocessed/infants/sub-05/eeglab/sub05.set
%
% Example Usage:
%   % Load configuration
%   cfg = preprocessing_config();
%   cfg.savemode = 'onefile';
%   
%   % Save preprocessed EEG data
%   save_eeglab_set(EEG_epoch, 5, cfg);
%   % Saves to: /data/preprocessed/infants/sub-05/eeglab/sub05.set
%   
%   % Save in two-file mode for large dataset
%   cfg.savemode = 'twofiles';
%   save_eeglab_set(EEG_epoch, 5, cfg);
%   % Saves: sub05.set (metadata) + sub05.fdt (data)
%
% Dependencies:
%   - EEGLAB toolbox must be installed and on the MATLAB path
%   - Requires pop_saveset function from EEGLAB
%
% See also: POP_SAVESET, POP_LOADSET, RUN_PREPROCESS
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/07/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  CONSTRUCT FILENAME AND FILEPATH
%  ===================================================================

% Create standardized filename with zero-padded subject number
% Format: sub##.set (e.g., sub01.set, sub05.set, sub23.set)
filename = sprintf('sub%02i.set', subjectnr);

% Build full directory path following organized structure
% Structure: preproc_dir/group/sub-XX/eeglab/
% Example: /data/preprocessed/infants/sub-05/eeglab/
filepath = fullfile(cfg.preproc_dir, ...                        % Root preprocessed directory
                    cfg.participants_info.name, ...             % Group name (infants/adults)
                    sprintf('sub-%02i', subjectnr), ...        % Subject folder (sub-05)
                    'eeglab');                                  % EEGLAB data subfolder

%% ===================================================================
%  ENSURE OUTPUT DIRECTORY EXISTS
%  ===================================================================

% Create directory if it doesn't exist
% This prevents errors when saving to a new subject's folder
if ~exist(filepath, 'dir')
    mkdir(filepath);
    fprintf('[INFO] Created directory: %s\n', filepath);
end

%% ===================================================================
%  SAVE EEG DATASET
%  ===================================================================

% Save using EEGLAB's pop_saveset function
% Parameters:
%   EEG        : EEG structure to save
%   'filename' : Name of output file (e.g., 'sub05.set')
%   'filepath' : Directory where file should be saved
%   'savemode' : Save format ('onefile' or 'twofiles')
%
% Note: pop_saveset automatically handles:
%   - Creating .fdt file if savemode = 'twofiles'
%   - Compression of large datasets
%   - Preservation of all EEG metadata
pop_saveset(EEG, ...
            'filename', filename, ...
            'filepath', filepath, ...
            'savemode', cfg.savemode);

%% ===================================================================
%  CONFIRMATION MESSAGE
%  ===================================================================

% Display success message with file details
fprintf('[INFO] Saved EEGLAB file for subject %02i: %s (mode: %s)\n', ...
        subjectnr, filename, cfg.savemode);
fprintf('       Full path: %s\n', fullfile(filepath, filename));

% Additional info for two-file mode
if strcmp(cfg.savemode, 'twofiles')
    fprintf('       Includes: %s (metadata) + %s (data)\n', ...
            filename, strrep(filename, '.set', '.fdt'));
end

end