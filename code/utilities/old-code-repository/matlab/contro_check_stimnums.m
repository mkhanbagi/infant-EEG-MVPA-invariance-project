clc
clear
datapath = '/Users/22095708/Documents/PhD/Project/occlusion/data/raw/infants';

for subjectnr = 1: 16
    control_check_1 = [];
    i = 1;
    % Import participant .csv file
    % === Behavioural File ===
    behav_file =  fullfile(datapath, sprintf('sub-%02i/eeg/sub-%02i_occlusion_events.csv', subjectnr, subjectnr));
    y = readtable(behav_file);
    y = y(~isnan(y.StimOnset), :);

    % extract color-content triggers
    stimnum.color.blue = unique(y.StimNumber(find(strcmp(y.Color, 'blue'))));
    stimnum.color.pink = unique(y.StimNumber(find(strcmp(y.Color, 'pink'))));
    control_check_1(subjectnr, i) = unique(ismember(stimnum.color.blue, stimnum.color.pink));
    i = i+1;

    % extract category-related triggers
    stimnum.category.face = unique(y.StimNumber(find(strcmp(y.Category, 'face'))));
    stimnum.category.nonface = unique(y.StimNumber(find(strcmp(y.Category, 'non-face'))));
    control_check_1(subjectnr, i) = unique(ismember(stimnum.category.face , stimnum.category.nonface));
    i = i+1;

    % extract identity-related triggers
    identity_info = y.Identity;
    stimnum.identity.bear = unique(y.StimNumber(find(strcmp(identity_info, 'bear'))));
    stimnum.identity.penguin = unique(y.StimNumber(find(strcmp(identity_info, 'penguin'))));
    stimnum.identity.rocket = unique(y.StimNumber(find(strcmp(identity_info, 'rocket'))));
    stimnum.identity.tower = unique(y.StimNumber(find(strcmp(identity_info, 'tower'))));
    control_check_1(subjectnr, i) = unique(ismember(stimnum.identity.bear , stimnum.identity.penguin)); i = i+1;
    control_check_1(subjectnr, i) = unique(ismember(stimnum.identity.bear , stimnum.identity.rocket)); i = i+1;
    control_check_1(subjectnr, i) = unique(ismember(stimnum.identity.bear , stimnum.identity.tower)); i = i+1;
    control_check_1(subjectnr, i) = unique(ismember(stimnum.identity.penguin , stimnum.identity.rocket)); i = i+1;
    control_check_1(subjectnr, i) = unique(ismember(stimnum.identity.penguin , stimnum.identity.tower)); i = i+1;
    control_check_1(subjectnr, i) = unique(ismember(stimnum.identity.rocket , stimnum.identity.tower)); i = i+1;
end

stimnum = struct();
for subjectnr = 1: 16
    % Import participant .csv file
    % === Behavioural File ===
    behav_file =  fullfile(datapath, sprintf('sub-%02i/eeg/sub-%02i_occlusion_events.csv', subjectnr, subjectnr));
    y = readtable(behav_file);
    y = y(~isnan(y.StimOnset), :);

    % extract color-content triggers
    stimnum.color.blue{subjectnr} = unique(y.StimNumber(find(strcmp(y.Color, 'blue'))));
    stimnum.color.pink{subjectnr} = unique(y.StimNumber(find(strcmp(y.Color, 'pink'))));

    % extract category-related triggers
    stimnum.category.face{subjectnr} = unique(y.StimNumber(find(strcmp(y.Category, 'face'))));
    stimnum.category.nonface{subjectnr} = unique(y.StimNumber(find(strcmp(y.Category, 'non-face'))));

    % extract identity-related triggers
    identity_info = y.Identity;
    stimnum.identity.bear{subjectnr} = unique(y.StimNumber(find(strcmp(identity_info, 'bear'))));
    stimnum.identity.penguin{subjectnr} = unique(y.StimNumber(find(strcmp(identity_info, 'penguin'))));
    stimnum.identity.rocket{subjectnr} = unique(y.StimNumber(find(strcmp(identity_info, 'rocket'))));
    stimnum.identity.tower{subjectnr} = unique(y.StimNumber(find(strcmp(identity_info, 'tower'))));
end

control_check_2 = struct();
n_subjects = 16;
pair_count = 0;
pairs = [];

categories = fieldnames(stimnum);
for k = 1: numel(categories)
    category = stimnum.(categories{k});
    types = fieldnames(category);
    for z = 1: numel(types)
        stimset = stimnum.(categories{k}).(types{z});
        for i = 1:n_subjects
            for j = i+1:n_subjects  % Key: j starts at i+1 to avoid repetition
                pair_count = pair_count + 1;
                pairs(pair_count, :) = [i, j];
                set = stimset(pairs);
                check = isequal(set{1}, set{2});
                if ~check 
                    error('the stimulus numbers for %s were not identical between sub-%02i and sub-%02i', types{z}, i, j)
                end
            end
        end
    end
end

