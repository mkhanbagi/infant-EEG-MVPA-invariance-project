function save_results(res, resfn)
% SAVE_RESULTS - Save CoSMoMVPA decoding results in multiple formats
%
% This function saves decoding results to disk in both MAT and CSV formats.
% The MAT file preserves the complete result structure for MATLAB analysis,
% while the CSV file provides a portable format for statistical software
% (R, Python, SPSS) containing just the decoding accuracy time series.
%
% Inputs:
%   res   - CoSMoMVPA result structure containing:
%           .samples         : Decoding accuracy at each time point (1 × timepoints)
%           .a.fdim.values   : Feature dimensions (time vector, channels, etc.)
%           .a.fdim.labels   : Feature dimension names
%           .fa              : Feature attributes
%           Additional fields from searchlight analysis
%   
%   resfn - Base filepath WITHOUT file extension
%           Function automatically appends .mat and .csv
%           Example: '/results/sub-05_category_all_all'
%           Creates: '/results/sub-05_category_all_all.mat'
%                    '/results/sub-05_category_all_all.csv'
%
% Output Files:
%   .mat file - Complete result structure (for MATLAB)
%               Contains all fields from CoSMoMVPA searchlight
%               Saved in HDF5 format (-v7.3) for large dataset support
%               Can be loaded with: results = load('filename.mat')
%   
%   .csv file - Decoding accuracy time series only (portable format)
%               Each row = one time point
%               Single column = accuracy value
%               Can be imported into R, Python, Excel, SPSS
%
% Behavior:
%   - Always saves/overwrites files without checking if they exist
%   - No overwrite protection implemented
%   - Creates both formats simultaneously
%   - Parent directory must exist (no automatic directory creation)
%
% Example Usage:
%   % After running searchlight decoding
%   res = cosmo_searchlight(ds, nh, @cosmo_crossvalidation_measure, ma);
%   
%   % Save to derivatives folder
%   basepath = '/data/derivatives/infants_sub-05_category_all_all';
%   save_results(res, basepath);
%   % Creates: infants_sub-05_category_all_all.mat
%   %          infants_sub-05_category_all_all.csv
%   
%
% See also: APPLY_DECODING, COSMO_SEARCHLIGHT, WRITEMATRIX
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [21/07/2025]
% Modified: [13/10/2025]


%% ===================================================================
%  CONSTRUCT OUTPUT FILENAMES
%  ===================================================================

% Append file extensions to base filepath
% MAT file: Complete MATLAB structure with all metadata
resfn_mat = sprintf('%s.mat', resfn);

% CSV file: Accuracy time series only (portable format)
resfn_csv = sprintf('%s.csv', resfn);

%% ===================================================================
%  SAVE COMPLETE RESULT STRUCTURE (MAT FORMAT)
%  ===================================================================

% Save full CoSMoMVPA result structure to MAT file
% 
% Uses -v7.3 format (HDF5-based) which:
%   - Supports files larger than 2GB
%   - Allows partial loading of large arrays
%   - Compatible with MATLAB R2006b and later
%   - Can be read by Python (scipy.io.loadmat with option)
%
% The MAT file contains all fields:
%   - .samples: Decoding accuracies
%   - .a: Dataset-level attributes (time vectors, etc.)
%   - .fa: Feature attributes
%   - Any other searchlight outputs
save(resfn_mat, 'res', '-v7.3');

fprintf('[INFO] Saved MAT file: %s\n', resfn_mat);

%% ===================================================================
%  SAVE ACCURACY TIME SERIES (CSV FORMAT)
%  ===================================================================

% Extract and save just the decoding accuracy values as CSV
% 
% res.samples is typically a row vector (1 × timepoints)
% Transpose (') to create column vector for standard CSV format:
%   - Each row = one time point
%   - Single column = accuracy value
%
% CSV format advantages:
%   - Human-readable
%   - Import into any statistical software
%   - Small file size
%   - No MATLAB required for analysis
%
% Note: Time vector not included in CSV (can be reconstructed or
%       extracted from MAT file if needed)
writematrix(res.samples', resfn_csv);

fprintf('[INFO] Saved CSV file: %s\n', resfn_csv);
fprintf('[INFO] Results saved successfully (2 files created)\n');

end