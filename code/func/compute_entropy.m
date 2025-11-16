%% IMAGE ENTROPY ANALYSIS TOOL
% Computes Shannon entropy for all JPEG images in a directory and analyzes
% the distribution of entropy values across the stimulus set.
%
% Entropy measures the amount of information/randomness in an image:
%   - Low entropy: Simple, uniform images (fewer unique pixel values)
%   - High entropy: Complex, detailed images (more unique pixel values)
%
% Features:
%   - Robust file handling (ignores hidden files like .DS_Store)
%   - Automatic RGB-to-grayscale conversion for color images
%   - Multiple visualization options (histograms with Gaussian fits)
%   - Statistical comparison of high/low entropy groups via median split
%   - Detailed progress reporting during processing
%   - Saves results in multiple formats (figure, CSV, MAT file)
%
% Output Files:
%   - entropy_analysis.png: Visualization of entropy distribution
%   - entropy_results.csv: Table with filename and entropy for each image
%   - entropy_workspace.mat: Complete workspace with all variables
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
e = zeros(n_files, 1);              % Entropy values for each image
file_info = cell(n_files, 2);       % Store [filename, entropy] pairs

fprintf('Processing %d images in: %s\n\n', n_files, stim_dir);

%% ===================================================================
%  ENTROPY COMPUTATION
%  ===================================================================

% Process each image file
for k = 1:n_files
    try
        % --- Load image ---
        filename = fullfile(stim_dir, files(k).name);
        I = imread(filename);
        
        % --- Convert to grayscale if necessary ---
        % Entropy computation requires grayscale (single-channel) images
        if size(I, 3) == 3
            % RGB image detected: convert to grayscale
            % Uses weighted average: 0.299*R + 0.587*G + 0.114*B
            I = rgb2gray(I);
        elseif ~ismatrix(I)
            % Unexpected format (e.g., 4-channel RGBA or other)
            error('Unsupported image format in file: %s', filename);
        end
        
        % --- Compute Shannon entropy ---
        % entropy(I) computes: -sum(p .* log2(p))
        % where p is the probability distribution of pixel intensities
        current_entropy = entropy(I);
        
        % Store results
        e(k) = current_entropy;
        file_info{k,1} = files(k).name;
        file_info{k,2} = current_entropy;
        
        % Progress update
        fprintf('Processed %3d/%d: %s (Entropy = %.3f)\n', ...
                k, n_files, files(k).name, current_entropy);
            
    catch ME
        % Handle errors gracefully (e.g., corrupted file, read error)
        warning('Error processing %s: %s', files(k).name, ME.message);
        e(k) = NaN;  % Mark failed files with NaN for exclusion from analysis
    end
end

fprintf('\n'); % Add blank line after processing

%% ===================================================================
%  STATISTICAL ANALYSIS
%  ===================================================================

% Remove failed files (NaN values) from analysis
valid_entropies = e(~isnan(e));

% --- Median Split Classification ---
% Divide images into two groups based on median entropy
% This creates balanced high/low entropy groups for comparison
median_entropy = median(valid_entropies);

% Classify each image as high or low entropy
high_entropy_mask = valid_entropies > median_entropy;
low_entropy_mask = ~high_entropy_mask;

% Extract entropy values for each group
high_entropy = valid_entropies(high_entropy_mask);
low_entropy = valid_entropies(low_entropy_mask);

% Display summary statistics
fprintf('=== ENTROPY ANALYSIS SUMMARY ===\n');
fprintf('Total images processed: %d\n', length(valid_entropies));
fprintf('Median entropy: %.3f\n\n', median_entropy);

fprintf('Low Entropy Group (n=%d):\n', length(low_entropy));
fprintf('  Range: [%.3f, %.3f]\n', min(low_entropy), max(low_entropy));
fprintf('  Mean ± SD: %.3f ± %.3f\n\n', mean(low_entropy), std(low_entropy));

fprintf('High Entropy Group (n=%d):\n', length(high_entropy));
fprintf('  Range: [%.3f, %.3f]\n', min(high_entropy), max(high_entropy));
fprintf('  Mean ± SD: %.3f ± %.3f\n\n', mean(high_entropy), std(high_entropy));

%% ===================================================================
%  VISUALIZATION
%  ===================================================================

% Define common visual parameters for consistency
edge_color = [0.2 0.2 0.2];  % Dark gray edges for histograms
font_size = 12;               % Standard font size for labels
blue_color = [0 0.447 0.741];      % MATLAB default blue (low entropy)
orange_color = [0.85 0.325 0.098]; % MATLAB default orange (high entropy)

% Create figure with two subplots
figure('Position', [100 100 800 400], 'Name', 'Entropy Distribution');

% ---------------------------------------------------------------
% SUBPLOT 1: Overlaid Histograms
% ---------------------------------------------------------------
% Shows the raw distribution of entropy values for both groups
subplot(1,2,1);
hold on;

% Plot histograms with transparency for overlap visibility
h1 = histogram(low_entropy, 'FaceColor', blue_color, ...
               'EdgeColor', edge_color, 'FaceAlpha', 0.6);
h2 = histogram(high_entropy, 'FaceColor', orange_color, ...
               'EdgeColor', edge_color, 'FaceAlpha', 0.6);

hold off;

% Labels and formatting
xlabel('Entropy Value', 'FontSize', font_size);
ylabel('Count', 'FontSize', font_size);
title('Entropy Distribution by Group', 'FontSize', font_size+2);
legend([h1, h2], {'Low Entropy', 'High Entropy'}, 'Location', 'northwest');
grid on;

% ---------------------------------------------------------------
% SUBPLOT 2: Histograms with Gaussian Fits
% ---------------------------------------------------------------
% Overlays theoretical normal distributions to assess normality
subplot(1,2,2);
hold on;

% Define common bin edges for fair comparison
edges = linspace(min(valid_entropies), max(valid_entropies), 15);

% Plot normalized histograms (probability density)
% 'Normalization', 'pdf' scales histograms to match Gaussian curves
histogram(low_entropy, edges, 'FaceColor', blue_color, ...
          'EdgeColor', edge_color, 'FaceAlpha', 0.4, ...
          'Normalization', 'pdf');
histogram(high_entropy, edges, 'FaceColor', orange_color, ...
          'EdgeColor', edge_color, 'FaceAlpha', 0.4, ...
          'Normalization', 'pdf');

% Overlay theoretical Gaussian distributions
% Useful for checking if entropy follows normal distribution
x_vals = linspace(min(valid_entropies), max(valid_entropies), 100);

% Low entropy Gaussian fit
plot(x_vals, normpdf(x_vals, mean(low_entropy), std(low_entropy)), ...
     'Color', [0 0.3 0.6], 'LineWidth', 2);

% High entropy Gaussian fit
plot(x_vals, normpdf(x_vals, mean(high_entropy), std(high_entropy)), ...
     'Color', [0.7 0.2 0], 'LineWidth', 2);

% Labels and formatting
xlabel('Entropy Value', 'FontSize', font_size);
ylabel('Probability Density', 'FontSize', font_size);
title('Gaussian Fit Comparison', 'FontSize', font_size+2);
legend('Low Entropy', 'High Entropy', 'Low Fit', 'High Fit', ...
       'Location', 'northwest');
grid on;
hold off;

%% ===================================================================
%  SAVE RESULTS
%  ===================================================================

% --- Save visualization ---
fig_path = fullfile(output_dir, 'entropy_analysis.png');
saveas(gcf, fig_path);
fprintf('Figure saved to: %s\n', fig_path);

% --- Save numerical results as CSV ---
% Creates a table with filename and entropy for each image
% Useful for importing into other software (R, Python, Excel)
results_table = table({files.name}', e, 'VariableNames', {'Filename', 'Entropy'});
csv_path = fullfile(output_dir, 'entropy_results.csv');
writetable(results_table, csv_path);
fprintf('CSV results saved to: %s\n', csv_path);

% --- Save complete workspace ---
% Saves all variables for later analysis in MATLAB
mat_path = fullfile(output_dir, 'entropy_workspace.mat');
save(mat_path);
fprintf('Workspace saved to: %s\n', mat_path);

fprintf('\n=== Analysis Complete ===\n');
fprintf('All results saved to: %s\n', output_dir);