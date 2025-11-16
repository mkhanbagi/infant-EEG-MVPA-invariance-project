function EEG = apply_filters_and_clean(EEG, cfg)
% APPLY_FILTERS_AND_CLEAN - Apply preprocessing pipeline to raw EEG data
%
% This function applies a standard preprocessing pipeline including optional
% automatic artifact cleaning, bandpass filtering, re-referencing, and
% downsampling to prepare raw EEG data for further analysis.
%
% Inputs:
%   EEG - EEGLAB EEG structure containing raw or previously loaded data
%         Must contain fields: .data, .srate, .chanlocs, etc.
%   
%   cfg - Configuration struct with the following fields:
%         .clean_rawdata - (logical) Whether to apply Clean Rawdata plugin
%                          for automatic artifact rejection (true/false)
%         .HighPass      - (numeric) High-pass filter cutoff in Hz (e.g., 0.1, 1)
%                          Removes slow drifts and DC offsets
%         .LowPass       - (numeric) Low-pass filter cutoff in Hz (e.g., 40, 100)
%                          Removes high-frequency noise and line noise
%         .downsample    - (numeric) Target sampling rate in Hz
%                          Set to 0 to skip downsampling
%                          Common values: 250, 500 Hz
%
% Output:
%   EEG - Preprocessed EEGLAB EEG structure ready for epoching/analysis
%
% Dependencies:
%   - EEGLAB must be installed and on the MATLAB path
%   - Clean Rawdata plugin must be installed (if cfg.clean_rawdata = true)
%     Available at: https://github.com/sccn/clean_rawdata
%
% Preprocessing Pipeline Order:
%   1. Automatic artifact cleaning (optional)
%   2. High-pass filtering
%   3. Low-pass filtering  
%   4. Re-referencing to average
%   5. Downsampling (optional)
%
% Example:
%   cfg.clean_rawdata = true;
%   cfg.HighPass = 0.1;
%   cfg.LowPass = 40;
%   cfg.downsample = 250;
%   EEG = apply_filters_and_clean(EEG, cfg);
%
% Note:
%   - Filters use EEGLAB's pop_eegfiltnew (FIR filter with Hamming window)
%   - Re-referencing uses average reference across all channels
%   - Clean Rawdata parameters are optimized for infant/adult EEG
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [20/07/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  AUTOMATIC ARTIFACT CLEANING (Optional)
%  ===================================================================

if cfg.clean_rawdata
    % Apply Clean Rawdata plugin for automatic artifact rejection
    % This identifies and removes/interpolates bad channels and time segments
    
    EEG = pop_clean_rawdata(EEG, ...
        'FlatlineCriterion', 5, ...                 % Remove channels flat for >5 seconds
        'ChannelCriterion', 0.85, ...               % Remove channels correlated <0.85 with neighbors
        'LineNoiseCriterion', 4, ...                % Remove channels with >4 SD line noise
        'Highpass', [0.25 0.75], ...                % Transition band for highpass (Hz)
        'BurstCriterion', 20, ...                   % Remove windows with >20 SD burst artifacts
        'WindowCriterion', 0.3, ...                 % Remove windows if >30% of channels are bad
        'BurstRejection', 'off', ...                % Don't reject burst artifacts (only flag)
        'Distance', 'Euclidian', ...                % Distance metric for channel correlation
        'WindowCriterionTolerances', [-Inf 7], ...  % Tolerance for window rejection
        'fusechanrej', 1);                          % Fuse channel rejection across methods
end

%% ===================================================================
%  BANDPASS FILTERING
%  ===================================================================

% --- High-pass filter ---
% Removes slow drifts, DC offset, and very low-frequency noise
% Common cutoffs: 0.1 Hz (liberal), 0.5-1 Hz (standard)
EEG = pop_eegfiltnew(EEG, cfg.HighPass, []);

% --- Low-pass filter ---
% Removes high-frequency noise and anti-aliases before downsampling
% Common cutoffs: 40 Hz (ERP studies), 100 Hz (high-freq studies)
EEG = pop_eegfiltnew(EEG, [], cfg.LowPass);

%% ===================================================================
%  RE-REFERENCING (if not already done in cleaning step)
%  ===================================================================

% Re-reference to average of all channels (common average reference)
% Only perform if Clean Rawdata was not used (to avoid double re-referencing)
if ~cfg.clean_rawdata
    EEG = pop_reref(EEG, []);
else
    % Re-reference to average after cleaning
    % The 'interpchan' option interpolates removed channels before re-referencing
    EEG = pop_reref(EEG, [], 'interpchan', []);
end

%% ===================================================================
%  DOWNSAMPLING (Optional)
%  ===================================================================

% Reduce sampling rate to decrease data size and computational load
% Should be done AFTER filtering to avoid aliasing
if cfg.downsample > 0
    EEG = pop_resample(EEG, cfg.downsample);
    fprintf('Data downsampled to %d Hz\n', cfg.downsample);
end

end