function ds = assign_labels(ds, cfg)
% ASSIGN_LABELS - Assign target and chunk labels to CoSMoMVPA dataset
%
% This function assigns classification targets (class labels) and chunks
% (cross-validation folds) to a CoSMoMVPA dataset based on function handles
% specified in the configuration struct. It dynamically inspects the function
% handles to determine their input requirements and calls them appropriately.
%
% Inputs:
%   ds     - CoSMoMVPA dataset structure with sample attributes (.sa)
%            Must contain .sa.stimnum field
%
%   cfg    - Configuration struct containing:
%            .decode_type - Struct with fields:
%              .name        - Name of current decoding type (e.g., 'category')
%              .target_func - Function handle to compute target labels
%                             Can take 1 arg: @(ds) ...
%                             Or 2 args: @(ds, stimnum) ...
%              .chunk_func  - Function handle to compute chunk labels
%                             Can take 1 arg: @(ds) ...
%                             Or 2 args: @(ds, stimnum) ...
%            .stimnum - Struct containing stimulus groupings
%                       (e.g., .category.face, .identity.bear)
%
% Output:
%   ds - Updated CoSMoMVPA dataset with assigned labels:
%        .sa.targets - Vector of class labels for each sample
%        .sa.chunks  - Vector of chunk/fold identifiers for each sample
%
% Function Handle Formats:
%   One argument:  @(ds) ds.sa.blocknum
%   Two arguments: @(ds, stimnum) double(ismember(ds.sa.stimnum, stimnum))
%
% Example:
%   cfg.decode_type.name = 'category';
%   cfg.decode_type.target_func = @(ds, stimnum) double(ismember(ds.sa.stimnum, stimnum));
%   cfg.decode_type.chunk_func = @(ds) ds.sa.blocknum;
%   cfg.stimnum.category.face = [1:32];
%
%   ds = assign_labels(ds, cfg);
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [21/07/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  INITIALIZATION
%  ===================================================================
% Make a copy of the dataset
ds_labeled = ds;

% Extract decoding configuration from nested config struct
[~, ~, decode_type] = hasFieldDeep(cfg, 'decode_type');
decode_type = decode_type{1};

% Get current decoding type name (e.g., 'category', 'identity')
type = decode_type.name;

% Extract function handles for target and chunk assignment
target_func = decode_type.target_func;
chunk_func = decode_type.chunk_func;

% Extract stimulus number groupings from config
[~, ~, stimnum] = hasFieldDeep(cfg, 'stimnum');
stimnum = stimnum{1};

%% ===================================================================
%  ASSIGN TARGET LABELS (Class labels for classification)
%  ===================================================================

% --- Parse function handle to determine number of arguments ---
% Extract argument names from function handle using regex
% Example: '@(ds, stimnum)' → {'ds', 'stimnum'}
tokens = regexp(func2str(target_func), '@\((.*?)\)', 'tokens', 'once');
argnames = strtrim(strsplit(tokens{1}, ','));

% --- Call target function based on number of arguments ---
if numel(argnames) > 1
    % Two-argument function: @(ds, stimnum) ...
    % Pass both dataset and relevant stimulus grouping
    % Example: target_func(ds, stimnum.category)
    if ismember(type, {'size', 'size_2class', 'size_3class'})
        target_labels = target_func(ds_labeled, cfg);
    else
        target_labels = target_func(ds_labeled, stimnum.(type));
    end
    

    % Check if function returned a full dataset or just label vector
    if isstruct(target_labels) && hasFieldDeep(target_labels, 'targets')
        % Function returned entire dataset with targets already assigned
        ds_labeled = target_labels;
    else
        % Function returned just the target vector
        ds_labeled.sa.targets = target_labels;
    end

elseif isscalar(argnames)
    % Single-argument function: @(ds) ...
    % Pass only the dataset
    % Example: target_func(ds)
    target_labels = target_func(ds_labeled);
    ds_labeled.sa.targets = target_labels;

else
    error('target_func must have 1 or 2 input arguments');
end

%% ===================================================================
%  ASSIGN CHUNK LABELS (Cross-validation folds)
%  ===================================================================

% Only assign chunks if chunk function is provided
if ~isempty(chunk_func)
    % --- Parse function handle to determine number of arguments ---
    tokens = regexp(func2str(chunk_func), '@\((.*?)\)', 'tokens', 'once');
    argnames = strtrim(strsplit(tokens{1}, ','));

    % --- Call chunk function based on number of arguments ---
    if numel(argnames) > 1
        % Two-argument function: @(ds, stimnum) ...
        % Extract the second argument name from function handle
        % Example: '@(ds, blocks)' → use stimnum.blocks
        chunk_labels = chunk_func(ds_labeled, stimnum.(argnames{2}));

        % Check if function returned a full dataset or just chunk vector
        if isstruct(chunk_labels) && hasFieldDeep(chunk_labels, 'chunks')
            % Function returned entire dataset with chunks already assigned
            [~, ~, values] = hasFieldDeep(chunk_labels, 'chunks');
            ds_labeled.sa.chunks = values{1};
        else
            % Function returned just the chunk vector
            ds_labeled.sa.chunks = chunk_labels;
        end

    elseif isscalar(argnames)
        % Single-argument function: @(ds) ...
        % Pass only the dataset
        % Example: @(ds) ds.sa.blocknum
        chunk_labels = chunk_func(ds_labeled);
        ds_labeled.sa.chunks = chunk_labels;

    else
        error('chunk_func must have 1 or 2 input arguments');
    end
end

%% ===================================================================
%  RETURN LABELED DATASET
%  ===================================================================

% Return the dataset with assigned targets and chunks
ds = ds_labeled;

end