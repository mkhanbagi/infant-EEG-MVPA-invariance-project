function [EEG_epoch, stimnum, blocknum] = epoch_eeg_data(EEG)
% EPOCH_EEG_DATA - Segment continuous EEG data into stimulus-locked epochs
%
% This function segments continuous EEG data into epochs time-locked to 
% stimulus presentations. It extracts stimulus event codes and their 
% corresponding block numbers, then creates epochs around each stimulus onset.
%
% Event Code Convention:
%   - Positive integers (>0) : Stimulus event codes (e.g., 1-64)
%   - -2                     : Block start markers
%   - Other negative values  : Ignored (non-stimulus events)
%
% Inputs:
%   EEG - EEGLAB EEG structure containing:
%         .data   : Continuous EEG data (channels × timepoints)
%         .event  : Event structure array with fields:
%                   .type    : Event code (string or numeric)
%                   .latency : Event onset time in samples
%         .srate  : Sampling rate in Hz
%         .times  : Time vector for each sample
%
% Outputs:
%   EEG_epoch - EEGLAB epoched EEG structure with:
%               .data   : 3D array (channels × timepoints × trials)
%               .epoch  : Epoch metadata (one per trial)
%               .times  : Time vector relative to stimulus onset
%               Epoch window: -100ms to +800ms around stimulus
%   
%   stimnum   - Column vector of stimulus numbers (length = number of epochs)
%               Contains the event code for each stimulus presentation
%               Example: [5, 12, 3, 45, ...] for 64-stimulus experiment
%   
%   blocknum  - Column vector of block numbers (length = number of epochs)
%               Indicates which experimental block each stimulus came from
%               Example: [1, 1, 1, 2, 2, 2, ...] for multi-block design
%
% Epoch Window:
%   [-100ms, +800ms] around stimulus onset
%   - Pre-stimulus baseline: -100ms to 0ms (used for baseline correction)
%   - Post-stimulus window: 0ms to 800ms (captures ERP/neural response)
%
% Dependencies:
%   - EEGLAB toolbox must be installed and on the MATLAB path
%     Required functions: pop_epoch, eeg_checkset
%
% Example:
%   % Load continuous EEG data
%   EEG = pop_loadset('sub-01_continuous.set');
%   
%   % Epoch around stimuli
%   [EEG_epoch, stimnum, blocknum] = epoch_eeg_data(EEG);
%   
%   % Check results
%   fprintf('Created %d epochs across %d blocks\n', ...
%           length(stimnum), max(blocknum));
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/09/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  EXTRACT EVENT CODES FROM EVENT STRUCTURE
%  ===================================================================

% Convert all event types to numeric values
% EEGLAB stores event.type as strings, so conversion is needed
% Example: {'1', '5', '-2', '23'} → [1, 5, -2, 23]
events = arrayfun(@str2double, {EEG.event.type});

%% ===================================================================
%  COMPUTE BLOCK NUMBERS USING CUMULATIVE SUM
%  ===================================================================

% Create block number for each event using cumulative sum trick
% Block markers (-2) act as counters that increment the block number
%
% How it works:
%   events:  [5, 12, -2, 23, 45, -2, 67, 3, ...]
%   == -2:   [0,  0,  1,  0,  0,  1,  0, 0, ...]
%   cumsum:  [0,  0,  1,  1,  1,  2,  2, 2, ...]
%
% Result: All events after the first -2 get block number 1,
%         all events after the second -2 get block number 2, etc.
blocknr = cumsum(events == -2);

%% ===================================================================
%  FILTER STIMULUS EVENTS
%  ===================================================================

% Identify stimulus events (positive integer codes only)
% This excludes block markers (-2) and any other negative codes
idx = events > 0;

% Extract stimulus numbers for valid stimulus events
% Convert to column vector for consistency with CoSMoMVPA format
stimnum = events(idx)';

% Extract corresponding block numbers for each stimulus
% Each stimulus is assigned to the block it occurred in
blocknum = blocknr(idx)';

%% ===================================================================
%  CREATE EPOCHS AROUND STIMULUS ONSETS
%  ===================================================================

% Epoch continuous data around stimulus events
% Window: [-0.1, 0.8] seconds relative to stimulus onset
%   -0.1s to 0s   : Pre-stimulus baseline period
%    0s to 0.8s   : Post-stimulus response period
%
% pop_epoch extracts time windows around events matching the specified types
% It creates a 3D array: (channels × timepoints × epochs)
EEG_epoch = pop_epoch(EEG, ...
                      {EEG.event(idx).type}, ...  % Event types to epoch around
                      [-0.1 0.8]);                 % Time window in seconds

%% ===================================================================
%  VALIDATE EPOCHED DATASET
%  ===================================================================

% Check dataset consistency and update dependent fields
% This function:
%   - Verifies data dimensions match epoch structure
%   - Updates time vectors
%   - Checks for missing or inconsistent fields
%   - Repairs minor inconsistencies if found
EEG_epoch = eeg_checkset(EEG_epoch);

%% ===================================================================
%  SUMMARY OUTPUT
%  ===================================================================

fprintf('[INFO] Epoching complete:\n');
fprintf('       %d epochs created\n', EEG_epoch.trials);
fprintf('       %d blocks identified\n', max(blocknum));
fprintf('       Epoch window: [%.1f, %.1f] seconds\n', ...
        EEG_epoch.xmin, EEG_epoch.xmax);
fprintf('       Timepoints per epoch: %d\n', EEG_epoch.pnts);

end