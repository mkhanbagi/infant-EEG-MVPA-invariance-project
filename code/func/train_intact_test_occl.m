function custom_partitions = train_intact_test_occl(ds, cfg)
% TRAIN_INTACT_TEST_OCCL - Create custom partitions for cross-condition generalization
%
% This function creates custom train/test partitions for assessing whether
% neural representations learned from intact (unoccluded) stimuli can
% generalize to occluded versions of the same stimuli. This tests the
% invariance of neural representations to occlusion.
%
% Partitioning Strategy:
%   TRAIN: All intact (unoccluded) stimuli across all chunks/blocks
%   TEST:  All occluded stimuli in each chunk (leave-one-chunk-out)
%
% This creates a challenging generalization test where the classifier never
% sees occluded examples during training, only during testing.
%
% Inputs:
%   ds  - CoSMoMVPA dataset structure with sample attributes:
%         .sa.stimnum  : Stimulus numbers for each sample
%         .sa.chunks   : Block/chunk numbers for cross-validation
%   
%   cfg - Configuration struct containing:
%         .stimnum.occl_level.intact : Vector of intact stimulus indices
%                                      (e.g., [1, 2, 5, 6, 9, 10, ...])
%
% Output:
%   custom_partitions - CoSMoMVPA partitions structure with fields:
%                       .train_indices : Cell array of training sample indices
%                                        (all intact stimuli from non-test chunks)
%                       .test_indices  : Cell array of testing sample indices
%                                        (occluded stimuli from one test chunk)
%
% Modality Encoding:
%   The function creates a temporary .sa.modality field:
%     modality = 1 : Intact (unoccluded) stimuli
%     modality = 0 : Occluded stimuli
%
% Cross-Validation Structure:
%   For n chunks, creates n folds:
%     Fold 1: Train on intact from chunks 2-n, test on occluded from chunk 1
%     Fold 2: Train on intact from chunks 1,3-n, test on occluded from chunk 2
%     ...
%     Fold n: Train on intact from chunks 1-(n-1), test on occluded from chunk n
%
% Example Usage:
%   % Set up configuration
%   cfg.stimnum.occl_level.intact = [1:32];  % First 32 are intact
%   
%   % Create custom partitions
%   partitions = train_intact_test_occl(ds, cfg);
%   
%   % Use in cross-validation
%   ma.classifier = @cosmo_classify_lda;
%   ma.partitions = partitions;
%   results = cosmo_crossvalidation_measure(ds, ma);
%
% Scientific Rationale:
%   This design tests whether neural representations are truly invariant to
%   occlusion or whether they rely on low-level visual features. If
%   classification succeeds, it suggests abstract/invariant representations.
%   If it fails, it suggests feature-dependent representations.
%
% See also: COSMO_NCHOOSEK_PARTITIONER, COSMO_NFOLD_PARTITIONER,
%           APPLY_DECODING, RUN_DECODING_OCCLUSION
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [22/08/2025]
% Modified: [13/10/2025]


%% ===================================================================
%  CREATE MODALITY LABELS
%  ===================================================================

% Create binary mask indicating which samples are intact vs occluded
% 1 = intact (unoccluded) stimuli
% 0 = occluded stimuli
%
% Example: If ds.sa.stimnum = [1, 2, 33, 34, 1, 2, 33, 34]
%          and intact = [1:32]
%          Then int_occl_mask = [1, 1, 0, 0, 1, 1, 0, 0]
int_occl_mask = double(ismember(ds.sa.stimnum, cfg.stimnum.occl_level.intact));

% Assign modality labels to dataset
% This temporary field is used by cosmo_nchoosek_partitioner to determine
% which samples to use for training vs testing
ds.sa.modality = int_occl_mask;

%% ===================================================================
%  CREATE CUSTOM PARTITIONS
%  ===================================================================

% Create leave-one-chunk-out partitions with cross-modality testing
%
% cosmo_nchoosek_partitioner parameters:
%   ds                : Dataset with .sa.chunks and .sa.modality
%   1                 : Leave one chunk out (n-1 chunks for training)
%   'modality', 0     : Test on modality=0 (occluded stimuli)
%                       Train on modality=1 (intact stimuli)
%
% How it works:
%   - For each chunk (block) in the dataset:
%       1. Test set: All occluded samples (modality=0) from that chunk
%       2. Train set: All intact samples (modality=1) from other chunks
%
% Result:
%   - Classifier learns from intact stimuli only
%   - Evaluated on occluded stimuli only
%   - Tests generalization across occlusion condition
custom_partitions = cosmo_nchoosek_partitioner(ds, 1, 'modality', 0);

%% ===================================================================
%  IMPLICIT OUTPUT
%  ===================================================================

% Note: ds.sa.modality field remains in the dataset after this function
% This is intentional - it may be used by downstream functions
% The field does not interfere with decoding (not used as a feature)

end