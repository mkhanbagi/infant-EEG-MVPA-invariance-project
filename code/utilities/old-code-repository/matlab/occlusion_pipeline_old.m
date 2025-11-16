%% Set-up the Environment
clc
clear
close(gcf)

% Add CoSMoMVPA toolbox
addpath(genpath('/Users/22095708/Documents/MATLAB/toolboxes/CoSMoMVPA'))

% Path to the project main directory
datapath = '/Users/22095708/Documents/PhD/Project/occlusion';

%% Decide which analysis to do
decode_v1 = {'category(1)', 'id(1)', 'color(1)', 'occ_level(1)', 'occ_pos(1)', 'occ_sfreq(1)', 'size(1)'};
decode_v2 = {'category(2)', 'id(2)', 'color(2)', 'size(2)'};
decode_v3 = {'category(3)', 'id(3)', 'color(3)', 'size(3)'};

%% Run for a single participant
subjectnr = 1;

% Import participant details
notes = sprintf('%s/docs/LabNoteBook.csv', datapath);
opts = detectImportOptions(notes);
dataTable = readtable(notes, opts);
columns = {'x_ID', 'Gender', 'DateOfBirth', 'Age_months_', 'Age_days_', 'No_BlocksRecorded', 'BlocksIncludedInTheFinalAnalysis', 'Includ_OrExclud_'};
matchingIndices = find(cellfun(@(x) ismember(x, dataTable.Properties.VariableNames), columns));
dataTable = dataTable(:, columns);
isgood = cellfun(@str2num, dataTable.BlocksIncludedInTheFinalAnalysis, 'UniformOutput', false);
nSubjs = size(dataTable, 1);

for subjectnr = 1: nSubjs
    % Import participant .csv file
% === Behavioural File ===
behav_file = fullfile(datapath, 'data/raw/infants', sprintf('sub-%02i/eeg/sub-%02i_occlusion_events.csv', subjectnr, subjectnr));
y = readtable(behav_file);
y = y(~isnan(y.StimOnset), :);
size_info = y.StimSize(~isnan(y.StimSize));
stimnum.size = size_info;

% extract color-content triggers
stimnum.color.blue = unique(y.StimNumber(find(strcmp(y.Color, 'blue'))));
stimnum.color.pink = unique(y.StimNumber(find(strcmp(y.Color, 'pink'))));
unique(ismember(stimnum.color.blue, stimnum.color.pink))

% extract category-related triggers
stimnum.category.face = unique(y.StimNumber(find(strcmp(y.Category, 'face'))));
stimnum.category.nonface = unique(y.StimNumber(find(strcmp(y.Category, 'non-face'))));
unique(ismember(stimnum.category.face , stimnum.category.nonface))


% extract identity-related triggers
identity_info = y.Identity;
stimnum.identity.bear = unique(y.StimNumber(find(strcmp(identity_info, 'bear'))));
stimnum.identity.penguin = unique(y.StimNumber(find(strcmp(identity_info, 'penguin'))));
stimnum.identity.rocket = unique(y.StimNumber(find(strcmp(identity_info, 'rocket'))));
stimnum.identity.tower = unique(y.StimNumber(find(strcmp(identity_info, 'tower'))));
unique(ismember(stimnum.identity.bear , stimnum.identity.penguin))
unique(ismember(stimnum.identity.bear , stimnum.identity.rocket))
unique(ismember(stimnum.identity.bear , stimnum.identity.tower))
unique(ismember(stimnum.identity.penguin , stimnum.identity.rocket))
unique(ismember(stimnum.identity.penguin , stimnum.identity.tower))
unique(ismember(stimnum.identity.rocket , stimnum.identity.tower))


% add occlusion-related information
cfg = load('/Users/22095708/Downloads/sanity_check/sub-01_old/config_file.mat').cfg;
stimnum.occl_level = cfg.map_key.occl_level;
stimnum.occl_pos = cfg.map_key.occl_pos;
stimnum.occl_sfreq = cfg.map_key.occl_sfreq;

% Import preprocessed EEG data
cosmofn = sprintf('%s/data/preprocessed/infants/sub-%02i/cosmo/sub-%02i_cosmomvpa.mat', datapath, subjectnr, subjectnr);
x= load(cosmofn, 'ds');
blocks = isgood{subjectnr};
total_stimuli = 64 * max(size(blocks));

% I) Version 1: Run the decoding by training the classifier on "all
% trials" and testing on "all tirals"
for dim = 1: size(decode_v1,2)
    ds = cosmo_slice(x.ds, ismember(x.ds.sa.blocknum, blocks));
    if strcmp (decode_v1{dim}, 'category(1)') % Slice the database based on the dimension that is decoded
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.category.face));
        ds.sa.chunks = ds.sa.blocknum; % 1-block-out
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Face', 'Non-face'}));

    elseif strcmp (decode_v1{dim}, 'id(1)')
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.identity.bear)) + [double(ismember(ds.sa.stimnum, stimnum.identity.penguin))]*2 + [double(ismember(ds.sa.stimnum, stimnum.identity.rocket))]*3 + [double(ismember(ds.sa.stimnum, stimnum.identity.tower))]*4;
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 2 3 4], {'Bear', 'Penguin', 'Rocket', 'Tower'}));

    elseif strcmp (decode_v1{dim}, 'color(1)')
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.color.blue));
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Blue', 'Pink'}));

    elseif strcmp (decode_v1{dim}, 'occ_level(1)')
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.occl_level.intact));
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Intact', 'Occluded'}));

    elseif strcmp (decode_v1{dim}, 'occ_pos(1)')
        ds = cosmo_slice(ds, ismember(ds.sa.stimnum, stimnum.occl_level.occluded));
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.occl_pos.right));
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Right', 'Left'}));

    elseif strcmp (decode_v1{dim}, 'occ_sfreq(1)')
        ds = cosmo_slice(ds, ismember(ds.sa.stimnum, stimnum.occl_level.occluded));
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.occl_sfreq.high));
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'High', 'Low'}));

    elseif strcmp (decode_v1{dim}, 'size(1)')
        idx_valid = find(ismember(ds.sa.blocknum, blocks));
        size_info = stimnum.size(idx_valid);

        ds.sa.targets = zeros(size(ds.sa.stimnum));
        ds.sa.targets(find(size_info == 500)) = 1;
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [0 1], {'Small', 'Large'}));
    end

    ds = cosmo_meeg_baseline_correct(ds,[-100 0],'absolute');
    nh = cosmo_interval_neighborhood(ds,'time','radius',0);

    ma = {};
    ma.classifier = @cosmo_classify_lda;
    partitions = cosmo_nfold_partitioner(ds);
    ds_balanced = cosmo_balance_partitions(partitions, ds); % balance training -> balance test : fulse / 'unbalanced_partitions_ok', true
    ma.partitions = ds_balanced;
    res = cosmo_searchlight(ds,nh,@cosmo_crossvalidation_measure,ma);

    resfn = sprintf('/Users/22095708/Downloads/sanity_check/new_results_old_pipeline/sub-%02i_%s.csv', subjectnr, decode_v1{dim});
    writematrix(res.samples', resfn)

    chance = 1/size(unique(ds.sa.targets),1);
    figure(1);clf
    tv = res.a.fdim.values{1};
    plot(tv,chance+0*tv,'k--');hold on
    plot(tv,movmean(res.samples,1),'k')
    plot(tv,movmean(res.samples,10),'r','LineWidth',2)
    xlim([-100 800])

    figfn= sprintf('/Users/22095708/Downloads/sanity_check/new_results_old_pipeline/sub-%02i_%s.png',subjectnr, decode_v1{dim});
    saveas(gcf, figfn)
end

% II) Version 2: Run the decoding by training the classifier on "intact
% objects" and testing on "intact objects"
for dim = 1: size(decode_v2,2)
    ds = cosmo_slice(x.ds, ismember(x.ds.sa.blocknum, blocks));
    
    idx_occl = find(ismember(ds.sa.stimnum, stimnum.occl_level.occluded));
    idx_int = find(ismember(ds.sa.stimnum, stimnum.occl_level.intact));
    ds = cosmo_slice(ds, ismember(ds.sa.stimnum, stimnum.occl_level.intact));

    if strcmp (decode_v2{dim}, 'category(2)') % Slice the database based on the dimension that is decoded
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.category.face));
        ds.sa.chunks = ds.sa.blocknum; % 1-block-out
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Face', 'Non-face'}));

    elseif strcmp (decode_v2{dim}, 'id(2)')
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.identity.bear)) + [double(ismember(ds.sa.stimnum, stimnum.identity.penguin))]*2 + [double(ismember(ds.sa.stimnum, stimnum.identity.rocket))]*3 + [double(ismember(ds.sa.stimnum, stimnum.identity.tower))]*4;
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 2 3 4], {'Bear', 'Penguin', 'Rocket', 'Tower'}));

    elseif strcmp (decode_v2{dim}, 'color(2)')
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.color.blue));
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Blue', 'Pink'}));
    
    elseif strcmp (decode_v2{dim}, 'size(2)')
        idx_valid = find(ismember(x.ds.sa.blocknum, blocks));
        size_info = stimnum.size(idx_valid);
        size_info = size_info(idx_int);
        ds.sa.targets = zeros(size(ds.sa.stimnum));
        ds.sa.targets(find(size_info == 500)) = 1;
        ds.sa.chunks = ds.sa.blocknum;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [0 1], {'Small', 'Large'}));
    end

    ds.sa.chunks = ds.sa.blocknum;
    ds = cosmo_meeg_baseline_correct(ds,[-100 0],'absolute');
    nh = cosmo_interval_neighborhood(ds,'time','radius',0);

    ma = {};
    ma.classifier = @cosmo_classify_lda;
    partitions = cosmo_nfold_partitioner(ds);
    ds_balanced = cosmo_balance_partitions(partitions, ds); % balance training -> balance test : fulse / 'unbalanced_partitions_ok', true
    ma.partitions = ds_balanced;
    res = cosmo_searchlight(ds,nh,@cosmo_crossvalidation_measure,ma);

    resfn = sprintf('/Users/22095708/Downloads/sanity_check/new_results_old_pipeline/sub-%02i_%s.csv', subjectnr, decode_v2{dim});
    writematrix(res.samples', resfn)

    chance = 1/size(unique(ds.sa.targets),1);
    figure(1);clf
    tv = res.a.fdim.values{1};
    plot(tv,chance+0*tv,'k--');hold on
    plot(tv,movmean(res.samples,1),'k')
    plot(tv,movmean(res.samples,10),'r','LineWidth',2)
    xlim([-100 800])

    figfn= sprintf('/Users/22095708/Downloads/sanity_check/new_results_old_pipeline/sub-%02i_%s.png', subjectnr, decode_v2{dim});
    saveas(gcf, figfn)
end

% III) Version 3: Run the decoding by training the classifier "intact objects" and testing on "occluded objects"
for dim = 1: size(decode_v3,2)
    ds = cosmo_slice(x.ds, ismember(x.ds.sa.blocknum, blocks));
    int_occl_mask = double(ismember(ds.sa.stimnum, stimnum.occl_level.intact));

    if strcmp (decode_v3{dim}, 'category(3)') % Slice the database based on the dimension that is decoded
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.category.face));
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Face', 'Non-face'}));

    elseif strcmp (decode_v3{dim}, 'id(3)')
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.identity.bear)) + [double(ismember(ds.sa.stimnum, stimnum.identity.penguin))]*2 + [double(ismember(ds.sa.stimnum, stimnum.identity.rocket))]*3 + [double(ismember(ds.sa.stimnum, stimnum.identity.tower))]*4;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 2 3 4], {'Bear', 'Penguin', 'Rocket', 'Tower'}));

    elseif strcmp (decode_v3{dim}, 'color(3)')
        ds.sa.targets = double(ismember(ds.sa.stimnum, stimnum.color.blue));
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [1 0], {'Blue', 'Pink'}));
   
elseif strcmp (decode_v3{dim}, 'size(3)')
        idx_valid = find(ismember(x.ds.sa.blocknum, blocks));
        size_info = stimnum.size(idx_valid);

        ds.sa.targets = zeros(size(ds.sa.stimnum));
        ds.sa.targets(find(size_info == 500)) = 1;
        ds.sa.labels = cellstr(categorical(ds.sa.targets, [0 1], {'Small', 'Large'}));
    end

    ds.sa.chunks = ds.sa.blocknum;
    ds.sa.modality = int_occl_mask;

    ds = cosmo_meeg_baseline_correct(ds,[-100 0],'absolute');
    nh = cosmo_interval_neighborhood(ds,'time','radius',0);

    ma = {};
    ma.classifier = @cosmo_classify_lda;
    partitions = cosmo_nchoosek_partitioner(ds,1,'modality',0);
    ds_balanced = cosmo_balance_partitions(partitions, ds);
    ma.partitions = ds_balanced;

    res = cosmo_searchlight(ds,nh,@cosmo_crossvalidation_measure,ma);

    resfn = sprintf('/Users/22095708/Downloads/sanity_check/new_results_old_pipeline/sub-%02i_%s.csv', subjectnr, decode_v3{dim});
    writematrix(res.samples', resfn)

    chance = 1/size(unique(ds.sa.targets),1);
    figure(1);clf
    tv = res.a.fdim.values{1};
    plot(tv,chance+0*tv,'k--');hold on
    plot(tv,movmean(res.samples,1),'k')
    plot(tv,movmean(res.samples,10),'r','LineWidth',2)
    xlim([-100 800])

    figfn= sprintf('/Users/22095708/Downloads/sanity_check/new_results_old_pipeline/sub-%02i_%s.png', subjectnr, decode_v3{dim});
    saveas(gcf, figfn)
end
end
