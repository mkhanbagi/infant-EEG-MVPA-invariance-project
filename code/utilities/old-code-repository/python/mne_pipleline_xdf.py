#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Mar  4 18:18:30 2025

@author: 22095708
"""

import mne
import numpy as np
import pyxdf

#%% Load the .xdf file
file_path = "/Users/22095708/Documents/PhD/Thesis/Experiments/Exp1_Viewpoints/Infant/sub-01/eeg/sub-P001_ses-S001_task-Default_run-001_eeg.xdf"  # Replace with your file path
streams, header = pyxdf.load_xdf('/Users/22095708/Documents/PhD/Thesis/Experiments/Exp1_Viewpoints/Piolot/RNet_Mina/sub-30/eeg/sub-P030_ses-S001_task-Default_run-001_eeg.xdf')

# Find the EEG stream
eeg_stream = None
for stream in streams:
    if "EEG" in stream["info"]["type"]:  # Adjust based on your data
        eeg_stream = stream
        break

if eeg_stream is None:
    raise ValueError("No EEG stream found in the XDF file.")

# Extract EEG data and timestamps
eeg_data = eeg_stream["time_series"].T  # Shape: (n_channels, n_samples)
sfreq = float(eeg_stream["info"]["nominal_srate"][0])  # Sampling frequency
ch_names = [ch["label"][0] for ch in eeg_stream["info"]["desc"][0]["channels"][0]["channel"]]
ch_types = ["eeg"] * len(ch_names)  # Assume all channels are EEG

# Create MNE Info and Raw object
info = mne.create_info(ch_names=ch_names, sfreq=sfreq, ch_types=ch_types)
raw = mne.io.RawArray(eeg_data, info)

# Plot raw EEG data
raw.plot()

#%% Preprocess EEG Data
# Bandpass filter (e.g., 1-40 Hz)
raw.filter(1, 40, fir_design="firwin")

# Set EEG reference (e.g., average reference)
raw.set_eeg_reference("average")

# Detect and mark bad channels
raw.plot()
raw.info["bads"] = ["Fp1"]  # Example: Mark 'Fp1' as bad
raw.interpolate_bads()

#%% Extract Events and Epochs
# Find event stream (adjust as needed)
event_stream = None
for stream in streams:
    if "Markers" in stream["info"]["type"]:  # Change if needed
        event_stream = stream
        break

if event_stream:
    event_times = event_stream["time_stamps"]
    #event_ids = {marker[0]: i + 1 for i, marker in enumerate(set(event_stream["time_series"]))}
    event_ids = {str(marker[0]): i + 1 for i, marker in enumerate(set(tuple(m) for m in event_stream["time_series"]))}
    events = [[int(t * sfreq), 0, event_ids[marker[0]]] for t, marker in zip(event_times, event_stream["time_series"])]
    events = mne.events_from_annotations(raw, event_id=event_ids)

    # Create epochs
    epochs = mne.Epochs(raw, events, event_id=event_ids, tmin=-0.2, tmax=0.8, baseline=(None, 0), detrend=1, preload=True)
    epochs.plot()
    
#%% Perform Time-Frequency Analysis    
# Plot power spectral density (PSD)
raw.plot_psd(fmax=40)

# Compute time-frequency representation
from mne.time_frequency import tfr_multitaper

freqs = np.linspace(2, 40, 20)  # Define frequencies
tfr = tfr_multitaper(epochs, freqs=freqs, n_cycles=freqs / 2, time_bandwidth=2.0, return_itc=False)
tfr.plot_topo(baseline=(-0.2, 0), mode="logratio", title="TFR")

#%% Source Localization (Optional)
# Compute ICA for artifact removal
ica = mne.preprocessing.ICA(n_components=20, random_state=97)
ica.fit(raw)
ica.plot_components()

