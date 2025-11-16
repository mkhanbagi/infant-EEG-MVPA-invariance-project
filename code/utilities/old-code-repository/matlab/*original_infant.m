clc
clear

%% eeglab
addpath(genpath('/Users/22095708/Documents/MATLAB/toolboxes/CoSMoMVPA'))
addpath('/Users/22095708/Documents/MATLAB/toolboxes/eeglab2024.0')
eeglab nogui
close(gcf)

%paths
datapath = '/Users/22095708/Documents/*PhD/Thesis/Experiments/Exp1_Viewpoints/Infant/S001';
figspath = '/Users/22095708/Documents/MARCS/Thesis/Experiments/Exp1_Viewpoints/Infant/Analysis/MATLAB_EEGLAB/figures';

%% subject to run
subjectnr = 1;

%% get files
cosmofn = sprintf('/Users/22095708/Documents/*PhD/Thesis/Experiments/Exp1_Viewpoints/Infant/derivatives/cosmo/sub-%03i_cosmomvpa.mat',subjectnr);
source_filename = sprintf('%s/sub-P%03i_ses-S001_task-Default_run-001_eeg.xdf',datapath,subjectnr);
fig1fn = sprintf('%s/S%03i.png', datapath, subjectnr);
fig2fn = sprintf('%s/S%03i.png', figspath, subjectnr);
%source_filename = sprintf('%s/sub-P%03i_ses-S001_task-Default_run-001_eeg.bdf',datapath,subjectnr);

%assert(~exist(cosmofn,'file'),sprintf('file exists: %s',cosmofn));

fprintf('preprocessing sub-%03i\n',subjectnr);tic;

%%
EEG_raw = pop_loadxdf(source_filename);
%EEG_raw = eeg_read_bdf(source_filename, 'all', 'n');
%EEG_raw = pop_biosig(source_filename);

% high pass filter
EEG_raw = pop_eegfiltnew(EEG_raw, 1,[]);

% low pass filter
EEG_raw = pop_eegfiltnew(EEG_raw, [],100);

% downsample
% EEG_cont = pop_resample(EEG_raw, 250);
% EEG_cont = eeg_checkset(EEG_cont);
EEG_cont = EEG_raw;

% find events
events = arrayfun(@str2double,{EEG_cont.event.type});
blocknr = cumsum(events==-2);
idx = events>0;
onset = vertcat(EEG_cont.event(idx).latency);
stimnum = events(idx)';
blocknum = blocknr(idx)';

EEG_epoch = pop_epoch(EEG_cont, {EEG_cont.event(idx).type}, [-2 2]);
EEG_epoch = eeg_checkset(EEG_epoch);

%% convert to cosmo
ds = cosmo_flatten(permute(EEG_epoch.data,[3 1 2]),{'chan','time'},{{EEG_epoch.chanlocs.labels},EEG_epoch.times},2);
ds.a.meeg=struct(); %or cosmo thinks it's not a meeg ds
ds.sa=struct();
ds.sa.stimnum = stimnum(1:size(ds.samples,1));
ds.sa.blocknum = blocknum(1:size(ds.samples,1));
%ds = cosmo_slice(ds,ds.sa.blocknr<max(ds.sa.blocknr));
cosmo_check_dataset(ds,'meeg');

%% save
fprintf('saving...\n')
save(cosmofn,'ds','-v7.3')
fprintf('done\n')
fprintf('preprocessing sub-%03i finished in %.0fs\n',subjectnr,toc)

%%
addpath('~/CoSMoMVPA/mvpa/')

%%
%x=load('sub-001_cosmomvpa.mat','ds');
x= load(cosmofn, 'ds');
ds = cosmo_slice(x.ds,x.ds.sa.stimnum<=112);
%ds = cosmo_slice(ds,ismember(ds.sa.blocknum,[1 2 3 4 5 6 7]));
%ds = cosmo_slice(ds,113:896);

%%
ds.sa.targets = ceil(ds.sa.stimnum/8);
ds.sa.chunks = mod(ds.sa.stimnum,8);

% ds.sa.targets = ceil(ds.sa.stimnum/8);
% ds.sa.chunks = ds.sa.blocknum;
ds = cosmo_meeg_baseline_correct(ds,[-200 0],'absolute');
nh = cosmo_interval_neighborhood(ds,'time','radius',0);

ma = {};
ma.classifier = @cosmo_classify_lda;
ma.partitions = cosmo_nfold_partitioner(ds);

res = cosmo_searchlight(ds,nh,@cosmo_crossvalidation_measure,ma);

%%
figure(1);clf
tv = res.a.fdim.values{1};
plot(tv,1/14+0*tv,'k--');hold on
plot(tv,movmean(res.samples,1),'k')
plot(tv,movmean(res.samples,10),'r','LineWidth',2)
xlim([-200 800])

saveas(gcf, fig1fn)
saveas(gcf, fig2fn)
%%
% figure(1);clf
% dst = cosmo_dim_transpose(ds,'chan',1);
% plot(mean(dst.samples(:,:)));hold on


