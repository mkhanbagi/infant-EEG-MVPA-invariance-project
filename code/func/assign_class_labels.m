function labelled_groups = assign_class_labels(stimnum, label_key)
% ASSIGN_LABELS - Assign numeric labels to stimuli based on group membership
%
% This function maps stimulus numbers to numeric class labels based on their
% membership in predefined groups. It is commonly used in MVPA decoding to
% assign target labels for classification (e.g., assigning identity labels
% 1=bear, 2=penguin, 3=rocket, 4=tower).
%
% Inputs:
%   stimnum     - Vector of stimulus numbers for all class/group(s) available
%                 that needs to be (re-)labelled (e.g., [1 2 3 ... 64])
%                  OR
%                  Dataset struct with field .sa.stimnum
%                  
%   label_key - Struct where each field represents a class/group and
%                  contains the stimulus numbers belonging to that group
%                  (labeling key)
%                  Example for identity decoding:
%                    label_groups.id1   = [1:16]
%                    label_groups.id2   = [17:32]
%                    label_groups.id3   = [33:48]
%                    label_groups.id4   = [49:64]
%
% Output:
%   labelled_groups - Vector of numeric labels (same length as stimnum)
%                   Each stimulus is assigned a number corresponding to its group
%                   (1 = first group, 2 = second group, etc.)
%                   Stimuli not belonging to any group are labelled as 0
%
% Example:
%   % Define identity groups
%   groups.id1 = [1:16];
%   groups.id2 = [17:32];
%   groups.id3 = [33:48];
%   groups.id4 = [49:64];
%   
%   % Stimulus numbers to label
%   stim = [5, 20, 35, 50];
%   
%   % Assign labels
%   labels = assign_labels(stim, groups);
%   % Result: [1, 2, 3, 4] (id1, id2, id3, id4)
%
% Notes:
%   - The order of labels follows the order of fields in the struct
%   - Each stimulus should belong to only one group (no overlap)
%   - Stimuli not in any group receive label 0

%% ===================================================================
%  INPUT HANDLING
%  ===================================================================

% Check if input is a dataset struct or a vector
if isstruct(stimnum)
    % Extract stimulus numbers from dataset structure
    stimnum = stimnum.sa.stimnum;
end

%% ===================================================================
%  EXTRACT GROUP INFORMATION
%  ===================================================================

% Get names of all groups (field names of the struct)
% Example: {'bear', 'penguin', 'rocket', 'tower'}
group_names = fieldnames(label_key);

% Create numeric labels for each group (1, 2, 3, ...)
numeric_labels = 1:length(group_names);

% Initialize output vector (zeros for stimuli not in any group)
labelled_groups = zeros(size(stimnum));

%% ===================================================================
%  ASSIGN LABELS BASED ON GROUP MEMBERSHIP
%  ===================================================================

% Loop through each group and assign corresponding numeric label
for i = 1:numel(group_names)
    % Get current group name (e.g., 'bear')
    current_group = group_names{i};
    
    % Get stimulus numbers belonging to this group
    group_stimuli = label_key.(current_group);
    
    % Find which stimuli belong to this group and assign label
    % Example: stimuli [1:16] get label 1 (bear)
    labelled_groups(ismember(stimnum, group_stimuli)) = numeric_labels(i);
end

end