%% IMAGE LUMINANCE ANALYSIS TOOL
% Computes average luminance (brightness) for all JPEG images in a directory
% and analyzes the distribution of luminance values across the stimulus set.
%
% Luminance measures the perceived brightness/lightness of an image:
%   - Low luminance: Dark images (pixel values closer to 0)
%   - High luminance: Bright images (pixel values closer to 1)
%
% Features:
%   - Robust file handling (ignores hidden files like .DS_Store)
%   - Automatic RGB-to-grayscale conversion for color images
%   - Normalized luminance values in [0,1] range (0=black, 1=white)
%   - Multiple visualization options (histograms with Gaussian fits)
%   - Statistical comparison of high/low luminance groups via median split
%   - Detailed progress reporting during processing
%   - Saves results in multiple formats (PNG, FIG, CSV, MAT)
%
% Output Files:
%   - luminance_analysis.png: Visualization of luminance distribution
%   - luminance_analysis.fig: MATLAB figure file (editable)
%   - luminance_results.csv: Table with filename and luminance for each image
%   - luminance_stats.mat: Statistics struct with group comparisons
%   - luminance_workspace.mat: Complete workspace with all variables
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [29/04/2025]
% Modified: [13/10/2025]

clc;
clear;
close all;

%% ===================================================================
%  CONFIGURATION
%  ===================================================================

% Define project directory structure
project_root = '/Users/22095708/Documents/PhD/Project/viewpoint/';
stim_dir = fullfile(project_root, 'task/stimuli');                       % Input: stimulus images
output_dir = fullfile(project_root, 'analysis/stat/stimulus-set-stat');  % Output: results

% Ensure output directory exists
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% ===================================================================
%  FILE PROCESSING
%  ===================================================================

% Get all JPEG files in stimulus directory
% Case-insensitive search (*.jpeg, *.JPEG, *.jpg, *.JPG all work)
files = dir(fullfile(stim_dir, '*.jpeg'));

% Remove hidden files (e.g., .DS_Store on macOS)
% Hidden files start with '.' and can cause processing errors
files = files(~startsWith({files.name}, '.'));

% Initialize storage for results
n_files = length(files);
luminance_values = zeros(n_files, 1);    % Average luminance for each image
file_info = cell(n_files, 2);            % Store [filename, luminance] pairs

fprintf('Processing %d images in: %s\n\n', n_files, stim_dir);

%% ===================================================================
%  LUMINANCE COMPUTATION
%  ===================================================================

% Process each image file
for k = 1:n_files
    try
        % --- Load image ---
        filename = fullfile(stim_dir, files(k).name);
        I = imread(filename);
        
        % --- Convert to grayscale if necessary ---
        % Luminance analysis requires grayscale (single-channel) images
        if size(I, 3) == 3
            % RGB image detected: convert to grayscale
            % Uses standard luminance weights: 0.299*R + 0.587*G + 0.114*B
            I = rgb2gray(I);
        elseif ~ismatrix(I)
            % Unexpected format (e.g., 4-channel RGBA or other)
            error('Unsupported image format in file: %s', filename);
        end
        
        % --- Normalize to [0,1] range ---
        % im2double converts integer pixel values to double precision
        % and scales to [0,1] range (0=black, 1=white)
        % This ensures consistent luminance values across different bit depths
        I = im2double(I);
        
        % --- Compute average luminance ---
        % Mean of all pixel values gives overall brightness
        % Alternative: median(I(:)) for robustness to outliers
        current_luminance = mean(I(:));
        
        % Store results
        luminance_values(k) = current_luminance;
        file_info{k,1} = files(k).name;
        file_info{k,2} = current_luminance;
        
        % Progress update
        fprintf('Processed %3d/%d: %s (Luminance = %.3f)\n', ...
                k, n_files, files(k).name, current_luminance);
            
    catch ME
        % Handle errors gracefully (e.g., corrupted file, read error)
        warning('Error processing %s: %s', files(k).name, ME.message);
        luminance_values(k) = NaN;  % Mark failed files with NaN for exclusion
    end
end

fprintf('\n'); % Add blank line after processing

%% ===================================================================
%  STATISTICAL ANALYSIS
%  ===================================================================

% Remove failed files (NaN values) from analysis
valid_luminance = luminance_values(~isnan(luminance_values));

% --- Median Split Classification ---
% Divide images into two groups based on median luminance
% This creates balanced high/low luminance groups for comparison
median_luminance = median(valid_luminance);

% Classify each image as high or low luminance
high_lum_mask = valid_luminance > median_luminance;
low_lum_mask = ~high_lum_mask;

% Extract luminance values for each group
high_luminance = valid_luminance(high_lum_mask);
low_luminance = valid_luminance(low_lum_mask);

%% ===================================================================
%  VISUALIZATION
%  ===================================================================

% Define common visual parameters for consistency
edge_color = [0.2 0.2 0.2];        % Dark gray edges for histograms
font_size = 12;                     % Standard font size for labels
blue_color = [0 0.447 0.741];      % MATLAB default blue (low luminance)
red_color = [0.85 0.325 0.098];    % MATLAB default red/orange (high luminance)

% Create figure window with centered positioning
fig = figure('Position', [100 100 1000 500], 'Name', 'Luminance Distribution Analysis');
movegui(fig, 'center');

% ---------------------------------------------------------------
% SUBPLOT 1: Overlaid Histograms
% ---------------------------------------------------------------
% Shows the raw distribution of luminance values for both groups
subplot(1,2,1);
hold on;

% Plot histograms with transparency for overlap visibility
% Fixed bin width ensures consistent comparison
h1 = histogram(low_luminance, 'FaceColor', blue_color, ...
               'EdgeColor', edge_color, 'FaceAlpha', 0.6, 'BinWidth', 0.02);
h2 = histogram(high_luminance, 'FaceColor', red_color, ...
               'EdgeColor', edge_color, 'FaceAlpha', 0.6, 'BinWidth', 0.02);

hold off;

% Labels and formatting
xlabel('Normalized Luminance [0,1]', 'FontSize', font_size);
ylabel('Count', 'FontSize', font_size);
title('Luminance Distribution by Group', 'FontSize', font_size+2);
legend([h1, h2], {'Low Luminance', 'High Luminance'}, 'Location', 'northwest');
grid on;
xlim([0 1]);  % Set explicit limits for [0,1] normalized range

% ---------------------------------------------------------------
% SUBPLOT 2: Histograms with Gaussian Fits
% ---------------------------------------------------------------
% Overlays theoretical normal distributions to assess normality
subplot(1,2,2);
hold on;

% Define common bin edges for fair comparison
edges = linspace(min(valid_luminance), max(valid_luminance), 15);

% Plot normalized histograms (probability density)
% 'Normalization', 'pdf' scales histograms to match Gaussian curves
histogram(low_luminance, edges, 'FaceColor', blue_color, ...
          'EdgeColor', edge_color, 'FaceAlpha', 0.4, ...
          'Normalization', 'pdf');
histogram(high_luminance, edges, 'FaceColor', red_color, ...
          'EdgeColor', edge_color, 'FaceAlpha', 0.4, ...
          'Normalization', 'pdf');

% Overlay theoretical Gaussian distributions
% Useful for checking if luminance follows normal distribution
x_vals = linspace(min(valid_luminance), max(valid_luminance), 100);

% Low luminance Gaussian fit
plot(x_vals, normpdf(x_vals, mean(low_luminance), std(low_luminance)), ...
     'Color', blue_color*0.8, 'LineWidth', 2.5, 'LineStyle', '-');

% High luminance Gaussian fit
plot(x_vals, normpdf(x_vals, mean(high_luminance), std(high_luminance)), ...
     'Color', red_color*0.8, 'LineWidth', 2.5, 'LineStyle', '-');

% Labels and formatting
xlabel('Normalized Luminance [0,1]', 'FontSize', font_size);
ylabel('Probability Density', 'FontSize', font_size);
title('Gaussian Fit Comparison', 'FontSize', font_size+2);
legend('Low Luminance', 'High Luminance', 'Low Fit', 'High Fit', ...
       'Location', 'northwest');
grid on;
hold off;
xlim([0 1]);  % Set explicit limits for [0,1] normalized range

%% ===================================================================
%  COMPILE STATISTICS
%  ===================================================================

% Create structured statistics for easy access and saving
stats = struct();
stats.median = median_luminance;         % Median split threshold
stats.mean_low = mean(low_luminance);    % Mean of low luminance group
stats.std_low = std(low_luminance);      % Standard deviation of low group
stats.mean_high = mean(high_luminance);  % Mean of high luminance group
stats.std_high = std(high_luminance);    % Standard deviation of high group
stats.n_low = numel(low_luminance);      % Number of images in low group
stats.n_high = numel(high_luminance);    % Number of images in high group

%% ===================================================================
%  SAVE RESULTS
%  ===================================================================

% --- Save visualization (PNG for viewing, FIG for editing) ---
png_path = fullfile(output_dir, 'luminance_analysis.png');
fig_path = fullfile(output_dir, 'luminance_analysis.fig');
saveas(fig, png_path);
saveas(fig, fig_path);
fprintf('Figures saved to:\n  %s\n  %s\n', png_path, fig_path);

% --- Save numerical results as CSV ---
% Creates a table with filename and luminance for each image
% Useful for importing into other software (R, Python, Excel)
results_table = table({files.name}', luminance_values, ...
                      'VariableNames', {'Filename', 'Luminance'});
csv_path = fullfile(output_dir, 'luminance_results.csv');
writetable(results_table, csv_path);
fprintf('CSV results saved to: %s\n', csv_path);

% --- Save statistics struct ---
% Quick access to summary statistics without loading full workspace
stats_path = fullfile(output_dir, 'luminance_stats.mat');
save(stats_path, 'stats');
fprintf('Statistics saved to: %s\n', stats_path);

% --- Save complete workspace ---
% Saves all variables for later analysis in MATLAB
mat_path = fullfile(output_dir, 'luminance_workspace.mat');
save(mat_path);
fprintf('Workspace saved to: %s\n', mat_path);

%% ===================================================================
%  DISPLAY SUMMARY
%  ===================================================================

fprintf('\n=== LUMINANCE ANALYSIS SUMMARY ===\n');
fprintf('Analysis complete. All results saved to: %s\n\n', output_dir);
fprintf('Median luminance: %.3f\n', median_luminance);
fprintf('Low luminance group (n=%d): μ=%.3f, σ=%.3f\n', ...
        stats.n_low, stats.mean_low, stats.std_low);
fprintf('High luminance group (n=%d): μ=%.3f, σ=%.3f\n', ...
        stats.n_high, stats.mean_high, stats.std_high);