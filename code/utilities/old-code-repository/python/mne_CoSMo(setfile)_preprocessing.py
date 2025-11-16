#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Feb 22 18:34:05 2025
@author: Mahdiyeh Khanbagi
"""
import os
import numpy as np
import mne


def run_preprocess(subjectnr,overwrite=0):
    #%% subject to run
    print(f'preprocessing sub-{subjectnr}')
    
    # path
    datapath = os.path.expanduser('/Users/22095708/Documents/PhD/Experiments/Exp1_Viewpoints/Infant')
    os.makedirs(f'{datapath}/derivatives/mne', exist_ok=True)
    
    #rawfn = f'{datapath}/derivatives/eeglab/sub{subjectnr:02d}.set'
    rawfn = f'{datapath}/derivatives/eeglab/sub{subjectnr}.set'
    outfn = f'{datapath}/derivatives/mne/sub-{subjectnr}_mne_epo.fif'

    
    if os.path.exists(outfn) and not overwrite:
        print('file exists:',outfn)
        return
    
    
    if not (os.path.exists(rawfn) or os.path.exists(rawfn)):
        print('file does not exists:', rawfn)
        return

    #%% Load EEG file
    # Load MNE-readable .set file made using EEGLab
    raw = mne.io.read_raw_eeglab(rawfn, preload=True)
    
    # Define event IDs if needed
    events, event_id = mne.events_from_annotations(raw)
    
    # Define the event IDs to remove
    event_ids_to_remove = {"-1", "-2"}
    event_id = {k: v for k, v in event_id.items() if k not in event_ids_to_remove}

    # Keep only the events that are NOT in `event_ids_to_remove`
    events_to_remove = [1, 2]
    events = events[~np.isin(events[:, 2], events_to_remove)]


    # Preprocessing
    print(raw)
    raw.pick('eeg')
    #montage?
    montage = mne.channels.make_standard_montage("biosemi32")
    mne.rename_channels(raw.info,dict(zip(raw.info.ch_names,montage.ch_names)))
    print(raw.info.ch_names)
    raw.set_montage(montage)
    #montage?
    #raw.filter(l_freq=0.5,h_freq=None)
    #raw.filter(h_freq=40,l_freq=None)
    raw.filter(l_freq=0.5, h_freq=40)
    raw.set_eeg_reference()
    #raw.get_data(units='uV')    

    # Epoch
    epochs = mne.Epochs(raw, events, tmin=-0.1, tmax=0.8, baseline=(-0.1, 0), detrend=0, proj=False, preload=True)
    
    # Resample
    epochs.resample(250)
    print(epochs)
    epochs.save(outfn ,overwrite=1)

    print('Done')

#%%% Example usage to run all
nSubjs= 41
for subjectnr in range(1,nSubjs+1):
    try:run_preprocess("%02i"%subjectnr,1)
    except Exception as e:print(e)