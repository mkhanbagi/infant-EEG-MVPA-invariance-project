function ma = make_ma_struct(ds, cfg, custom_partitions)
% MAKE_MA_STRUCT - Create measure arguments (ma) struct for CoSMoMVPA decoding
%
% This function constructs the measure arguments structure required by
% CoSMoMVPA's cross-validation functions. The ma struct contains the classifier
% and balanced partitions needed for fair cross-validated classification.
%
% Measure arguments (ma) define how classification should be performed:
%   - Which classifier to use (LDA, SVM, etc.)
%   - How to split data into train/test folds (partitions)
%   - Whether partitions are balanced across classes
%
% Inputs:
%   ds                 - CoSMoMVPA dataset struct with fields:
%                        .samples  : Data matrix (trials × features)
%                        .sa       : Sample attributes (.targets, .chunks)
%                        .fa       : Feature attributes
%   
%   cfg                - Configuration struct containing:
%                        .classifier : Function handle to classifier
%                                      (e.g., @cosmo_classify_lda, @cosmo_classify_svm)
%   
%   custom_partitions  - (optional) Pre-computed partitions struct
%                        If provided, uses these custom train/test splits
%                        If not provided, generates n-fold partitions automatically
%                        Custom partitions are used for special cases like:
%                          - Train on intact, test on occluded stimuli
%                          - Leave-one-block-out cross-validation
%
% Output:
%   ma - Measure arguments struct with fields:
%        .classifier  : Classifier function handle
%        .partitions  : Balanced partitions struct containing:
%                       .train_indices : Cell array of training sample indices
%                       .test_indices  : Cell array of testing sample indices
%                       Each fold has balanced class representation
%
% Partition Balancing:
%   Balancing ensures equal numbers of samples per class in each fold
%   This prevents bias toward majority classes and ensures fair accuracy metrics
%   Example: If class 1 has 100 samples and class 2 has 20 samples,
%            balancing will randomly subsample class 1 to 20 samples per fold
%
% Usage Examples:
%   % Standard n-fold cross-validation
%   ma = make_ma_struct(ds, cfg);
%   
%   % With custom train/test partitions
%   custom_part = train_intact_test_occl(ds, cfg);
%   ma = make_ma_struct(ds, cfg, custom_part);
%   
%   % Use in searchlight analysis
%   results = cosmo_searchlight(ds, nh, @cosmo_crossvalidation_measure, ma);
%
% Dependencies:
%   - CoSMoMVPA toolbox functions:
%     cosmo_nfold_partitioner : Generates n-fold partitions
%     cosmo_balance_partitions : Balances class representation
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [11/09/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  INITIALIZE MEASURE ARGUMENTS STRUCT
%  ===================================================================

% Create empty struct to hold measure arguments
ma = struct();

%% ===================================================================
%  ASSIGN CLASSIFIER
%  ===================================================================

% Set classifier function from configuration
% Common classifiers in CoSMoMVPA:
%   - @cosmo_classify_lda  : Linear Discriminant Analysis (fast, assumes Gaussian)
%   - @cosmo_classify_svm  : Support Vector Machine (flexible, kernel-based)
%   - @cosmo_classify_nn   : Nearest Neighbor (simple, non-parametric)
%   - @cosmo_classify_naive_bayes : Naive Bayes (fast, assumes independence)
ma.classifier = cfg.classifier;

%% ===================================================================
%  GENERATE OR USE PROVIDED PARTITIONS
%  ===================================================================

% Check if custom partitions were provided as third argument
if nargin < 3 || isempty(custom_partitions)
    % --- Case 1: Standard n-fold cross-validation ---
    % No custom partitions provided, generate default n-fold partitions
    % 
    % cosmo_nfold_partitioner automatically:
    %   - Uses ds.sa.chunks to define folds (leave-one-chunk-out)
    %   - Each unique chunk value becomes a test fold
    %   - All other chunks are used for training
    %
    % Example: If ds.sa.chunks = [1,1,1,2,2,2,3,3,3]
    %          Fold 1: train on chunks 2+3, test on chunk 1
    %          Fold 2: train on chunks 1+3, test on chunk 2
    %          Fold 3: train on chunks 1+2, test on chunk 3
    partitions = cosmo_nfold_partitioner(ds);
    
else
    % --- Case 2: Custom partitioning ---
    % Use provided custom partitions for special train/test configurations
    %
    % Custom partitions allow for:
    %   - Training on one stimulus type, testing on another
    %     (e.g., train intact, test occluded)
    %   - Non-standard fold definitions
    %   - Stratified sampling strategies
    %   - Time-based splits (e.g., first half vs second half)
    partitions = custom_partitions;
end

%% ===================================================================
%  BALANCE PARTITIONS
%  ===================================================================

% Balance class representation within each partition
% This is critical for fair classification accuracy metrics
%
% cosmo_balance_partitions ensures equal sample counts per class by:
%   1. Finding the class with fewest samples in each fold
%   2. Randomly subsampling other classes to match this minimum
%   3. Returning balanced partitions struct
%
% Note: Despite the variable name 'ds_balanced', this function returns
% a partitions struct (not a dataset). The partitions contain indices
% that point to balanced subsets of the original dataset.
ds_balanced = cosmo_balance_partitions(partitions, ds);

% Store balanced partitions in measure arguments
ma.partitions = ds_balanced;

end