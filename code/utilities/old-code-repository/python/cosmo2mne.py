#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Feb 22 18:34:05 2025
@author: Mahdiyeh Khanbagi
"""
import os
import pyxdf
import numpy as np
import mne



 #%% subject to run
subjectnr = 30
print(f'preprocessing sub-{subjectnr}')

# path
datapath = os.path.expanduser('/Users/22095708/Documents/PhD/Thesis/Experiments/Exp1_Viewpoints/Infant')
os.makedirs(f'{datapath}/derivatives/mne', exist_ok=True)
 
rawfn = f'{datapath}/sub-{subjectnr:02d}/eeg/sub-P{subjectnr:03d}_ses-S001_task-Default_run-001_eeg.xdf'
setfn = f'{datapath}/derivatives/eeglab/sub{subjectnr:02d}.set'
outfn = f'{datapath}/derivatives/mne/sub-{subjectnr:02d}_mne_epo.fif'
behavfn = f'{datapath}/sub-{subjectnr}/eeg/sub-{subjectnr:02d}_task-targets_events.csv'

 #%% Load EEG file
 #raw = mne.io.read_raw_bdf('/Users/22095708/Documents/*PhD/Thesis/Experiments/Exp1_Viewpoints/Adult/sub-01/eeg/sub01.bdf', preload=True)
 #raw = mne.io.read_raw_xdf("/Users/22095708/Documents/PhD/Thesis/Experiments/Exp1_Viewpoints/Infant/sub-01/eeg/sub-P001_ses-S001_task-Default_run-001_eeg.xdf", preload=True)

raw = mne.io.read_raw_eeglab(rawfn, preload=True)
 

data, header = pyxdf.load_xdf(rawfn)
for stream in data:
    print(f"Stream: {stream['info']['name'][0]}")
    
    
   #OR: 

try:
    from pyxdf import load_xdf
    def issubclass_(cls, classinfo):
        return isinstance(cls, type) and issubclass(cls, classinfo)
    data, header = load_xdf(rawfn)
except Exception as e:
    print("Error:", e)
    
    

event_stream = next(s for s in data if 'marker' in s['info']['type'][0].lower())
event_timestamps = event_stream['time_stamps']
event_values = event_stream['time_series']

#%%

# Convert XDF timestamps to sample indices
sfreq = raw.info['sfreq']
event_samples = np.round((event_timestamps - raw.times[0]) * sfreq).astype(int)

# Create an MNE-compatible events array
events = np.column_stack([event_samples, np.zeros(len(event_samples), dtype=int), np.array(event_values, dtype=int)])

# Define event IDs if needed
event_id = {'Stimulus A': 1, 'Stimulus B': 2}
epochs = mne.Epochs(raw, events, event_id, tmin=-0.2, tmax=0.5, baseline=(None, 0), preload=True)

#%% Last Version->
# Load EEG file
 #Finding Event Streams in .xdf File:
rawRnet, header = pyxdf.load_xdf(rawfn)
for stream in rawRnet:
    print(f"Stream: {stream['info']['name'][0]}")
 
# Extracting Events (Triggers)
event_stream = next(s for s in rawRnet if 'marker' in s['info']['type'][0].lower())
event_values = event_stream['time_series']
stimix = np.where((event_values !=-1) & (event_values != -2))[0]
event_timestamps = event_stream['time_stamps'][stimix]

 
# Converting to MNE Events Format:
# Load MNE-readable .set file made using EEGLab
set = mne.io.read_raw_eeglab(setfn, preload=True)
 
# Convert XDF timestamps to sample indices
sfreq = set.info['sfreq']
event_samples = np.round((event_timestamps - set.times[0]) * sfreq).astype(int)

# Create an MNE-compatible events array
#events = np.column_stack([event_samples, np.zeros(len(event_samples), dtype=int), np.array(event_values, dtype=int)])
events = np.column_stack([event_samples, np.zeros(len(event_samples), dtype=int), np.arange(len(event_samples))])

epochs = mne.Epochs(set, events, tmin=-0.2, tmax=0.5, baseline=(None, 0), preload=True)
