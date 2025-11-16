%% Initialising the Environment
clc
clear
close(gcf)

% Toolboxes
% CoSMoMVPA
addpath(genpath('/Users/22095708/Documents/MATLAB/toolboxes/CoSMoMVPA'))

% Fieldtrip
% addpath(genpath('/Users/22095708/Documents/MATLAB/toolboxes/fieldtrip-20250318'))
% rmpath(genpath('/Users/22095708/Documents/MATLAB/toolboxes/fieldtrip-20250318'))

% MyFunctions_Directory
addpath(genpath('/Users/22095708/Documents/MATLAB/toolboxes/myFunc'))

% Path to the project main directory
datapath = '/Users/22095708/Documents/PhD/Experiments/Exp1_Viewpoints/Infant';

%% Running the analysis for a set of subjects
% Define the range of subjects, e.g. 12:28 OR [ 13    14    15    16    17    18    19    20    21]
nSubjs = 52;

% Import LabNotebook in a table, containing information about individual subjects
% indluding good blocks that will be included in the final analysis (or
% subject numbers that need to be excluded from the final analysis) 
notes = sprintf('%s/group/LabNoteBook.csv', datapath);
opts = detectImportOptions(notes);
dataTable = readtable(notes, opts);
columns = {'x_ID', 'Gender', 'DateOfBirth', 'Age_months_', 'Age_days_', 'No_BlocksRecorded', 'LastBlock', 'BlocksIncludedInTheFinalAnalysis', 'Includ_OrExclud_'};
matchingIndices = find(cellfun(@(x) ismember(x, dataTable.Properties.VariableNames), columns));
dataTable = dataTable(:, columns);
isgood = cellfun(@str2num, dataTable.BlocksIncludedInTheFinalAnalysis, 'UniformOutput', false);

%% Example usage to run all
    % Determine which sample attribute to decode 
    decode = 'objects'; %Example: 'objects', 'animacy';
    
    % Determine the number of permutations to run 
    nPerm = 1000;
    sig = {};
    p = {};

for subjectnr = 1:nSubjs
    nullfn1 = sprintf('%s/derivatives/results/sub-%02i_%sNullDist(notime).mat', datapath, subjectnr, decode);
    nullfn2 = sprintf('%s/derivatives/results/sub-%02i_%sNullDist(notime).csv', datapath, subjectnr, decode);
    
    resfn1 = sprintf('%s/derivatives/results/sub-%02i_%s(notime).mat', datapath, subjectnr, decode);
    resfn2 = sprintf('%s/derivatives/results/sub-%02i_%s(notime).csv', datapath, subjectnr, decode);
    
    figfn1 = sprintf('%s/figures/time_collapsed/sub-%02i_%s.png', datapath, subjectnr, decode);
    %figfn2 = sprintf('%s/figures/%s/sub-%02i_%s(notime).png', datapath, decode, subjectnr, decode);
    
    outfn1 = sprintf('%s/group/sig_all_%s_no-time.csv', datapath, decode);
    outfn2 = sprintf('%s/group/pVal_all_%s_no-time.csv', datapath, decode);

    % Load the data
    nblocks = isgood(subjectnr);
    blocks = nblocks{1,1}; % blocks should be passed as a cell array
    cosmofn = sprintf('%s/derivatives/cosmo/sub-%02i_cosmomvpa.mat', datapath, subjectnr);
    a = load(cosmofn);
    ds = cosmo_slice(a.ds,ismember(a.ds.sa.blocknum, blocks));

    % Identify time points to keep (i.e., from index 26 (t=0ms) onward)
    keep_idx = ds.fa.time > 25;  % or more generally: keep the last 200

    % Apply mask to dataset
    ds_trimmed = cosmo_slice(ds, keep_idx, 2);  % 2 = feature dimension
    ds_trimmed = cosmo_dim_prune(ds_trimmed); % update dim attributes 

    % Average over the 'time' dimension - collapsing time for all channels 
    ds_avg_time = cosmo_fx(ds_trimmed, @(x) mean(x, 2), {'chan'}, 2);
    ds = ds_avg_time;
    
    % Version 1-> removing time from .fa and .a fields of the dataset 
    ds.fa = rmfield(ds.fa, 'time');
    ds.a.fdim.labels(2) = [];
    ds.a.fdim.values(2) = [];
    
    % Version 2 -> keeping time, but turning them all into identical values
    % ds.a.fdim.values(2) = {ones(1,200)}; 
    % or
    % ds.a.fdim.values(2) = {1};

    % Decide which sample attributes to decode
    if strcmp(decode, 'animacy')
        chance = 1/2;
        ds.sa.targets = ceil(ds.sa.stimnum/8); % Assign target labels for decoding by grouping samples
        animals = [2,3,4,5,7,8,9]; %non_animals = [1,6,10,11,12,13,14];
        binary_vec = ismember(ds.sa.targets, animals);
        ds.sa.targets =  double(binary_vec);
        ds.sa.chunks = mod(ds.sa.stimnum,8); % Define chunks cross-validation based on stimulus indices
    elseif strcmp(decode, 'objects')
        chance = 1/14;
        ds.sa.targets = ceil(ds.sa.stimnum/8);
        ds.sa.chunks = mod(ds.sa.stimnum,8);
    end

    % Version 1-> performs cross-validation using cosmo crossvalidate
    % function:
    
    classifier =  @cosmo_classify_lda;
    partitions = cosmo_nfold_partitioner(ds);
    
    % opt= struct(); % -> optional struct with options for classifier
    % opt.normalization = 'zscore'; % -> optional, one of 'zscore','demean','scale_unit'
    %                       to normalize the data prior to classification
    
    [~, observed] = cosmo_crossvalidate(ds, classifier, partitions);%, opt);
    
    % Version 2-> run searchlight (with either: 1. including all the
    % channels in your searchlight window or 2. using time (identical
    % values, with window radius 0) 
    %
    % 1. Inluding all channels: 
    % nh = cosmo_interval_neighborhood(ds, 'chan', 'radius', 32);
    % or
    % nh = cosmo_meeg_chan_neighborhood(ds_avg_time, 'radius', 0); %->requires fieldtrip toolbox
    %
    % 2.
    % nh = cosmo_interval_neighborhood(ds, 'time', 'radius', 0);
    %
    %
    %
    % Define the classifier characteristics
    % ma = {};
    % ma.classifier =  @cosmo_classify_lda;
    % ma.partitions = cosmo_nfold_partitioner(ds);
    % 
    % % Run the classifier
    % res = cosmo_searchlight(ds,nh,@cosmo_crossvalidation_measure,ma);
    % observed = mean(res.samples, 2);
    
    % Save the classification results 

    % Version 1 -> CoSMo crossvalidate
    save(resfn1, 'observed', '-v7.3')
    writematrix(observed, resfn2)

    % Version 2 -> searchlight
    % save(resfn1, 'observed', '-v7.3')
    % writematrix(res.samples, resfn2)

    % Shuffle labels
    null = zeros(nPerm,1);
    % res_shuffled = {};
    
    for k=1:nPerm
        ds_shuffled = cosmo_randomize_targets(ds, 'seed', k);
        ds.sa.targets = ds_shuffled;
        % Version 1 -> CoSMo crossvlidate 
        [~,null(k,1)] = cosmo_crossvalidate(ds, classifier, partitions);%, opt);

        % Version 2 -> searchlight
        % res_shuffled{k} = cosmo_searchlight(ds,nh,@cosmo_crossvalidation_measure,ma);
    end
   
    % Save the produced null distribution
    
    % Version 1 -> CoSMo crossvlidate 
    save(nullfn1, 'null', '-v7.3')
    writematrix(null, nullfn2)

    % Version 2 -> searchlight 
    % ds_null = cosmo_stack(res_shuffled);
    % ds_null.samples = mean(ds_null.samples, 2);
    % null = ds_null.samples;
    % 
    % save(nullfn1, 'ds_null', '-v7.3')
    % writematrix(ds_null.samples, nullfn2)
    

    %Test when observed data exceeds null dist (at each timepoint - does not correct for tp)
    cutoffs = prctile(null,95,1);
    %sig = observed>corrected_null; % When does observed decoding acc EXCEED cutoff?
    sig{subjectnr} = observed>cutoffs;
    
    % Non-parametric one-tailed test (permutation-style): count how many null values are >= the observation
    p{subjectnr} = sum(null >= observed) / length(null);

    figure(1);clf

    % Plot histogram of null distribution
    histogram(null', 'FaceColor', [0.6 0.6 0.9])
    hold on

    % Plot the observed value as a vertical line
    y_limits = ylim; % Get current y-axis limits
    plot([observed observed], y_limits, 'r--', 'LineWidth', 2)
    %plot([mean(null,1) mean(null,1)], y_limits, 'k-', LineWidth= 2)

    % Add text and labels
    title('Null Distribution with Observed Value')
    xlabel('Value')
    ylabel('Frequency')
    legend('Null distribution', 'Observed value')
    hold off

    saveas(gcf, figfn1)
    %saveas(gcf, figfn2)
    close(gcf);
end


writecell(sig, outfn1)
writecell(p, outfn2)