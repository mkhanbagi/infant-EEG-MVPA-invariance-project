function [pw_val, RDM, null] = run_pairwise(ds, cfg, varargin)
% RUN_PAIRWISE - Perform pairwise decoding for representational similarity analysis
%
% This function conducts pairwise decoding analyses by iterating over all
% possible condition pairs (e.g., all identity pairs, all category pairs).
% It constructs a Representational Dissimilarity Matrix (RDM) where each entry
% represents how well the classifier can discriminate between two conditions.
%
% Inputs:
%   ds       - CoSMoMVPA dataset structure with sample attributes
%              Must contain all stimuli/conditions for pairwise comparison
%
%   cfg      - Configuration struct from decoding_config containing:
%              .RDM_config          : RDM-specific settings (if not overridden)
%                .target_class      : Cell array of decoding types to run
%                .crossval_method   : Cell array of cross-validation methods
%                .pw_permutation    : Number of permutations (0 = none)
%                .save_RDM          : Whether to save full RDM matrix
%                .RDM_size          : Number of conditions (e.g., 4 identities)
%              .participants_info   : Subject and group information
%              .project_path        : Root directory for outputs
%              .savefile            : Whether to save results
%              .plot_results        : Whether to generate plots
%
%   varargin - Optional name-value pairs to override cfg.RDM_config:
%              'target_class'      : Cell array of decoding types
%              'crossval_method'   : Cell array of CV methods
%              'pw_permutation'    : Number of permutations
%              'save_RDM'          : Whether to save RDM
%              'RDM_size'          : Number of conditions
%
% Outputs:
%   pw_val - Average pairwise decoding accuracy across all condition pairs
%            Vector of length = number of time points
%            Represents overall discriminability in the neural representation
%
%   RDM    - Representational Dissimilarity Matrix
%            3D array: (conditions × conditions × timepoints)
%            RDM(i,j,t) = decoding accuracy for pair (i,j) at time t
%            Symmetric matrix with diagonal undefined
%
%   null   - Null distribution from permutation testing (if requested)
%            Empty if pw_permutation = 0
%
% RDM Structure:
%   - Each entry RDM(i,j,:) represents how dissimilar conditions i and j are
%   - Higher values = more discriminable = more dissimilar representations
%   - Matrix is symmetric: RDM(i,j,:) = RDM(j,i,:)
%   - Diagonal is not computed (condition vs itself)
%
% Example Usage:
%   % Run pairwise identity decoding
%   cfg.RDM_config.target_class = {'identity'};
%   cfg.RDM_config.crossval_method = {'all_all'};
%   cfg.RDM_config.RDM_size = 4;  % 4 identities
%   [avg_pw, RDM, null] = run_pairwise(ds, cfg);
%
%   % Override config with custom parameters
%   [avg_pw, RDM] = run_pairwise(ds, cfg, 'RDM_size', 8, 'save_RDM', 1);
%
% Notes:
%   - Computes upper triangle only (i < j) for efficiency
%   - Results are mirrored to lower triangle for complete symmetric matrix
%   - Supports permutation testing for statistical significance
%   - Can save both observed RDM and null distribution
%
% See also: APPLY_DECODING, COSMO_SEARCHLIGHT, COSMO_SLICE
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [09/09/2025]
% Modified: [13/10/2025]


%% ===================================================================
%  PARSE OPTIONAL INPUTS
%  ===================================================================

% Set up input parser for optional name-value pairs
p = inputParser;
addParameter(p, 'target_class', '', @ischar);        % Decoding types to run
addParameter(p, 'crossval_method', '', @iscell);     % CV methods to use
addParameter(p, 'pw_permutation', '', @isnumeric);   % Number of permutations
addParameter(p, 'pw_mode', '', @ischar);             % Pairs to include
addParameter(p, 'save_RDM', '', @isnumeric);         % Save full RDM matrix
parse(p, varargin{:});

% Extract parsed parameters
target_class = p.Results.target_class;
crossval_method = p.Results.crossval_method;

%% ===================================================================
%  DETERMINE RDM CONFIGURATION
%  ===================================================================

% Check if user provided custom parameters or should use config defaults
if all(cellfun(@(x) isempty(x), {target_class, crossval_method}))
    % --- Case 1: Use RDM configuration from config file ---
    % No custom parameters provided, use defaults from cfg
    target_class = cfg.RDM_config.target_class;
    crossval_method = cfg.RDM_config.crossval_method;
    pw_permutation = cfg.RDM_config.pw_permutation;
    pw_mode = cfg.RDM_config.pw_mode;
    save_RDM = cfg.RDM_config.save_RDM;

else
    % --- Case 2: Use custom parameters from varargin ---
    % User provided overrides via function arguments
    target_class = p.Results.target_class;
    crossval_method = p.Results.crossval_method;
    pw_permutation = p.Results.pw_permutation;
    pw_mode = p.Results.pw_mode;
    save_RDM = p.Results.save_RDM;
end

%% ===================================================================
%  GENERATE TYPE-METHOD COMBINATIONS
%  ===================================================================
combinations = sprintf('%s_%s', target_class, crossval_method);
% ---------------------------------------------------------------
% Parse combination string to extract type and method
% ---------------------------------------------------------------
% Split by underscore
% Examples: 'identity_all_all' or 'occl_level_intact_occl'
parts = split(combinations, '_');

% Reconstruct decode type name
if ismember(numel(parts), [3,4])
    % Standard case: single-word type
    decode_type = parts{1};
    decode_method = strjoin(parts(2:end), '_');
elseif numel(parts) == 5
    % Multi-word type (e.g., 'occl_level')
    decode_type = strjoin(parts(1:2), '_');
    decode_method = strjoin(parts(end-2:end), '_');
end

%% ===================================================================
%  Run COMBINATIONS - Prepare configuration for current combination
%  ===================================================================

cfg_current = cfg;

% Select matching decode type from config
type_match = strcmp({cfg_current.decode_type.name}, decode_type);
cfg_current.decode_type = cfg_current.decode_type(type_match);

% Set current version
cfg_current.decode_type.current_version = decode_method;

% Update chunk function if needed
if ~(ismember(decode_type, {'size_2class', 'size_3class'})) && ~strcmp(cfg.project, 'occlusion')
    cfg_current.decode_type.chunk_func = cfg_current.decode_type.chunk_func.(decode_method);
end

% ---------------------------------------------------------------
% Skip if subject has only 1 block (can't do one-block-out CV)
% ---------------------------------------------------------------

if strcmp(decode_method, 'one_block_out') || strcmp(cfg.project, 'occlusion') && ...
        isscalar(cfg.participants_info.isgood{cfg.participants_info.subjectnr})
    fprintf('⚠️  Skipping one_block_out for sub-%02d (only 1 block exists)\n', ...
        cfg.participants_info.subjectnr);
    return  % Exit function early
end

%% ===============================================================
%  INITIALIZE STORAGE FOR PAIRWISE RESULTS
%  ===============================================================

% Counter for number of pairwise comparisons
nIter = 0;

% Initialize average pairwise decoding vector (1 × timepoints)
pw_val = zeros(1, length(ds.a.fdim.values{1,2}));

% Initialize RDM (conditions × conditions × timepoints)
pairs_to_incl = cfg.pw_mode.(pw_mode);

if size(pairs_to_incl, 1) > 1
    set1 = pairs_to_incl(1,:);
    set2 = pairs_to_incl(2,:);
else
    set1 = pairs_to_incl;
    set2 = pairs_to_incl;
end

RDM_size = [length(set1), length(set2)];
RDM = zeros([RDM_size length(ds.a.fdim.values{1,2})]);
visited = zeros(RDM_size);

% Initialize null distribution storage if permutation testing requested
if (pw_permutation)
    pw_null = zeros(size(pw_val));
    RDM_null = zeros(size(RDM));
end

%% ===============================================================
%  PERFORM ALL PAIRWISE COMPARISONS
%  ===============================================================

% Double loop over all condition pairs
% Only compute upper triangle (i < j) for efficiency
ii = 0;

for i = set1
    jj = 0;
    ii = ii+1;

    for j = set2
        jj = jj+1;
        
        % Skip diagonal and already-seen  pairs - avoids computing the
        % lower half of the matrix
        if i == j || visited(ii,jj) || visited(jj,ii)
            continue
        else
        
        visited(ii,jj) = 1;
        visited(jj,ii) = 1;
        
        % -----------------------------------------------
        % Configure pairwise decoding for this pair
        % -----------------------------------------------

        % Enable pairwise mode in config
        cfg_current.RDM_config.run_pw = true;

        % Specify which pair to decode (e.g., identity 1 vs identity 3)
        cfg_current.RDM_config.pairs = [i,j];

        % -----------------------------------------------
        % Run decoding for this pair
        % -----------------------------------------------

        % apply_decoding will slice dataset to only include samples
        % from conditions i and j, then perform classification
        [res, null] = apply_decoding(cfg.ds, cfg_current);

        % -----------------------------------------------
        % Accumulate results
        % -----------------------------------------------

        % Add to average pairwise decoding
        pw_val = pw_val + res.samples;

        % Store in RDM (both upper and lower triangle)
        % Matrix is symmetric: RDM(i,j) = RDM(j,i)
        RDM(ii, jj, :) = res.samples;
        RDM(jj, ii, :) = res.samples;

        % Store null distribution if available
        if ~isempty(null)
            pw_null = pw_null + null;

            % Average across permutations for this pair
            RDM_null(ii, jj, :) = mean(null, 1);
            RDM_null(jj, ii, :) = mean(null, 1);
        end
        end
        
        % Increment iteration counter
        nIter = nIter + 1;
    end
end

%% ===============================================================
%  COMPUTE AVERAGE PAIRWISE DECODING
%  ===============================================================

% Divide accumulated values by number of pairs to get average
pw_results = pw_val / nIter;

% Average null distribution if permutation testing was performed
if (pw_permutation)
    pw_null = pw_null / nIter;
end

% Print completion message
fprintf('Pairwise decoding of sub-%02i: %s - %s complete\n', ...
    cfg.participants_info.subjectnr, combinations, pw_mode);

%% ===============================================================
%  SAVE RESULTS TO FILE
%  ===============================================================

% --- Save average pairwise decoding results ---
if cfg.savefile
    fprintf('Saving pairwise results...\n');

    % Construct filename
    resfn = fullfile(cfg.project_path, 'derivatives', ...
        sprintf('%s_sub-%02i_pw_%s_%s.csv', cfg.participants_info.name, ...
        cfg.participants_info.subjectnr, combinations, pw_mode));

    % Save as CSV (transpose to get timepoints as rows)
    writematrix(pw_results', resfn);
end

% --- Save null distribution (if available) ---
if pw_permutation && cfg.permut_config.save_null
    fprintf('Saving null distribution...\n');

    % Construct filename
    nullfn = fullfile(cfg.project_path, 'derivatives', ...
        sprintf('%s_sub-%02i_pw_%s_%s_null.csv', cfg.participants_info.name, ...
        cfg.participants_info.subjectnr, combinations{n}, pw_mode));

    % Save null distribution
    writematrix(pw_null, nullfn);
end

%% ===============================================================
%  GENERATE PLOTS
%  ===============================================================

% --- Plot average pairwise decoding results ---
if cfg.plot_results
    % Construct figure filename
    figfn = fullfile(cfg.project_path, 'figures', 'decoding', ...
        sprintf('%s_sub-%02i_pw_%s_%s.png', cfg.participants_info.name, ...
        cfg.participants_info.subjectnr, combinations, pw_mode));

    % Prepare results structure for plotting
    chance_level = 0.5;  % Binary classification for pairwise
    res_to_plot = res;
    res_to_plot.samples = pw_results;
    res_to_plot.chance = chance_level;

    % Generate and save plot
    plot_results(res_to_plot, figfn);
end

% --- Plot permutation-corrected results (if available) ---
if pw_permutation && cfg.permut_config.plot_results
    % Construct figure filename
    figure_filename = fullfile(cfg.project_path, 'figures', ...
        'permutation', sprintf('%s_sub-%02i_pw_%s_%s_corrected.png', ...
        cfg.participants_info.name, cfg.participants_info.subjectnr, combinations{n}, pw_mode));

    % Extract data for plotting
    chance = 0.5;
    observed = pw_results;

    % Get time vector
    tv_idx = find(strcmp(ds.a.fdim.labels, 'time'));
    tv = ds.a.fdim.values{tv_idx};

    % --- Perform cluster-based correction ---
    % Get 95th percentile threshold across permutations
    corrected_null = prctile(pw_null, 95, 2);

    % Calculate p-values
    pvals = mean(observed <= corrected_null);

    % Identify significant time points
    sigidx = pvals < 0.05;

    % --- Create figure ---
    figure; clf;

    % Plot observed accuracy
    plot(tv, observed, 'LineWidth', 2); hold on;

    % Plot chance level
    plot(tv, chance + 0*tv, 'k--'); hold on;

    % Mark significant time points
    plot(tv(sigidx), tv(sigidx)*0 + (chance*0.95), 'x', 'Marker', '*', 'MarkerSize', 10);

    % Save and close figure
    saveas(gcf, figure_filename);
    close(gcf);
end

%% ===============================================================
%  SAVE RDM MATRICES
%  ===============================================================

% --- Save observed RDM ---
if save_RDM
    % Construct filename
    rdmfn = fullfile(cfg.project_path, 'derivatives', ...
        sprintf('%s_sub-%02i_RDM_%s_%s', cfg.participants_info.name, ...
        cfg.participants_info.subjectnr, combinations, pw_mode));

    % Save as MAT file (use -v7.3 for large arrays)
    save(rdmfn, 'RDM', '-v7.3');
end

% --- Save null RDM (if available) ---
if pw_permutation && save_RDM
    % Construct filename
    rdmfn = fullfile(cfg.project_path, 'derivatives', ...
        sprintf('%s_sub-%02i_RDM_%s_%s_null', cfg.participants_info.name, ...
        cfg.participants_info.subjectnr, combinations{n}, pw_mode));

    % Save null RDM
    save(rdmfn, 'RDM_null', '-v7.3');
end

% Clean up null output if not requested
if nargout < 3
    clear null;
end
end