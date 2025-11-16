function plot_results(res, figfn)
% PLOT_RESULTS - Visualize decoding accuracy over time and save figure
%
% This function creates a time series plot of decoding accuracy from CoSMoMVPA
% results, showing both raw and smoothed accuracy trajectories along with the
% chance level. The figure is automatically saved to the specified location.
%
% Inputs:
%   res   - CoSMoMVPA result structure containing:
%           .samples         : Decoding accuracy at each time point (1 × timepoints)
%           .a.fdim.values{1}: Time vector in milliseconds
%           .chance          : Chance level accuracy (e.g., 0.5 for 2-class)
%   
%   figfn - Full path for output figure file
%           Should end in .png (e.g., '/path/to/results/sub-01_category.png')
%           Parent directory must exist or saveas will fail
%
% Output:
%   Saves figure as PNG file at location specified by figfn
%   Figure shows:
%     - Black dashed line: Chance level
%     - Black solid line: Raw decoding accuracy (window=1)
%     - Red thick line: Smoothed accuracy (10-point moving average)
%
% Plot Elements:
%   X-axis: Time in milliseconds (hardcoded range: -100 to 800ms)
%   Y-axis: Decoding accuracy (0 to 1, or as determined by data)
%   
% Notes:
%   - Always overwrites existing figure at figfn (no overwrite protection)
%   - Uses figure(1) which may interfere with other open figures
%   - Time range [-100, 800] is hardcoded (may not suit all experiments)
%   - No error handling for missing directories
%
% Example:
%   % After running CoSMoMVPA searchlight
%   res.samples = accuracies;
%   res.chance = 0.25;  % 4-class problem
%   res.a.fdim.values{1} = -100:10:800;  % Time vector
%   
%   figpath = '/results/figures/sub-05_identity.png';
%   plot_results(res, figpath);
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [22/07/2025]
% Modified: [13/10/2025]


%% ===================================================================
%  INITIALIZE FIGURE
%  ===================================================================

% Create or clear figure 1
% Using figure(1) may overwrite other plots if user has figure 1 open
figure(1); clf

%% ===================================================================
%  EXTRACT DATA FROM RESULTS STRUCTURE
%  ===================================================================

% Extract chance level accuracy (baseline performance)
% For n-class classification: chance = 1/n
% Examples: 0.5 for binary, 0.25 for 4-class, 0.33 for 3-class
chance = res.chance;

% Extract time vector (in milliseconds)
% Typically ranges from pre-stimulus (negative) to post-stimulus (positive)
% Common range: -100ms (baseline) to 800ms (response period)
tv = res.a.fdim.values{1};

%% ===================================================================
%  PLOT DECODING RESULTS
%  ===================================================================

% --- Plot chance level reference line ---
% Creates a horizontal line at chance level across entire time series
% 'k--' = black dashed line
% chance+0*tv creates a vector of chance values same length as tv
plot(tv, chance + 0*tv, 'k--'); 
hold on;

% --- Plot raw decoding accuracy (window size = 1) ---
% Note: movmean with window=1 is redundant (returns original data)
% This effectively plots res.samples without any smoothing
% 'k' = black solid line
plot(tv, movmean(res.samples, 1), 'k');

% --- Plot smoothed decoding accuracy (10-point moving average) ---
% Smooths accuracy trajectory to reduce noise and show trend
% Window of 10 timepoints averages over local fluctuations
% 'r' = red color, 'LineWidth', 2 = thick line for emphasis
plot(tv, movmean(res.samples, 10), 'r', 'LineWidth', 2);

%% ===================================================================
%  FORMAT PLOT
%  ===================================================================

% Set x-axis limits to standard ERP time window
% -100ms: Pre-stimulus baseline period
% +800ms: Post-stimulus response period
% Note: This is hardcoded and may not suit all experimental designs
xlim([-100 800]);

% Add labels and legend (optional - currently not included)
% Uncomment to add for better readability:
% xlabel('Time (ms)');
% ylabel('Decoding Accuracy');
% legend('Chance', 'Raw', 'Smoothed (10pt)', 'Location', 'best');
% title('Decoding Accuracy Over Time');

%% ===================================================================
%  SAVE FIGURE
%  ===================================================================

% Save current figure (gcf = get current figure) to PNG file
% Will overwrite existing file without warning
% Parent directory must exist or this will error
saveas(gcf, figfn);

% Optional: Close figure after saving to free memory
% close(gcf);

end