#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EEG Preprocessing Script

Preprocesses EEG data using parameters from preprocessing_config.

Author: Mahdiyeh Khanbagi
Created: Tue Oct 14 18:15:29 2025

"""

import pandas as pd
import numpy as np
import mne
from .preprocessing_config import preprocessing_config


def run_preprocess(
    project_name, subjectnr, participant_group="adults", overwrite=None
):
    """
    Preprocess EEG data for a single subject.

    Parameters
    ----------
    project_name : str
        Name of the project (e.g., 'Exp1_Viewpoints')
    subjectnr : str or int
        Subject number
    participant_group : str, optional
        Participant group ('adults' or 'infants'). Default is 'adults'.
    overwrite : int or None, optional
        Whether to overwrite existing files (0=no, 1=yes).
        If None, uses value from config.
    """

    # Load configuration
    cfg = preprocessing_config(project_name)

    # Use config overwrite setting if not specified
    if overwrite is None:
        overwrite = cfg["overwrite"]

    # Get participant group info
    group_info = next(
        (
            g
            for g in cfg["participants_info"]
            if g["name"] == participant_group
        ),
        None,
    )
    if group_info is None:
        raise ValueError(
            f"Participant group '{participant_group}' not found in config"
        )

    # Format subject number
    if isinstance(subjectnr, int):
        subjectnr = f"{subjectnr:02d}"

    print(
        f'Preprocessing sub-{subjectnr} ({participant_group} group, {group_info["eeg_system"]})'
    )

    # Define paths using config
    datapath = cfg["data_dir"]
    rawdata_dir = cfg["rawdata_dir"]
    preproc_dir = cfg["preproc_dir"]

    # File paths
    source_behavfn = (
        datapath / "sourcedata" / f"sub-{subjectnr}_task-targets_events.csv"
    )
    source_filename = (
        datapath / "sourcedata" / f"sub-{subjectnr}_task-targets_eeg.bdf"
    )

    raw_filename = (
        rawdata_dir
        / participant_group
        / f"sub-{subjectnr}"
        / "eeg"
        / f"sub{subjectnr}.bdf"
    )

    behavfn = (
        rawdata_dir
        / participant_group
        / f"sub-{subjectnr}"
        / "eeg"
        / f"sub-{subjectnr}_task-targets_events.tsv"
    )

    outfn = (
        preproc_dir
        / participant_group
        / f"sub-{subjectnr}"
        / "mne"
        / f"sub-{subjectnr}_mne_epo.fif"
    )

    # ===================================================================
    # FILE LOCATION CHECK AND SETUP
    # ===================================================================

    # Check if output exists and overwrite is disabled
    if outfn.exists() and not overwrite:
        print(f"File exists: {outfn}")
        return

    # Check for behavioral file
    if behavfn.exists():
        # File already in raw location - good to go
        print(f"[PREPROC] Behavioral file found in raw: {behavfn.name}")

    elif source_behavfn.exists():
        # File in sourcedata - move it to raw
        print("[PREPROC] Moving behavioral file from sourcedata to raw...")
        behavfn.parent.mkdir(parents=True, exist_ok=True)
        source_behavfn.rename(behavfn)
        print(f"[PREPROC] ✓ Moved to: {behavfn}")

    else:
        # File not found anywhere - error
        print("[PREPROC] ✗ ERROR: Behavioral file not found!")
        print(f"  Checked raw: {behavfn}")
        print(f"  Checked source: {source_behavfn}")
        return

    # Check for EEG file
    if raw_filename.exists():
        # File already in raw location - good to go
        print(f"[PREPROC] EEG file found in raw: {raw_filename.name}")

    elif source_filename.exists():
        # File in sourcedata - move it to raw
        print("[PREPROC] Moving EEG file from sourcedata to raw...")
        raw_filename.parent.mkdir(parents=True, exist_ok=True)
        source_filename.rename(raw_filename)
        print("[PREPROC] ✓ Moved to: {raw_filename}")

    else:
        # File not found anywhere - error
        print("[PREPROC] ✗ ERROR: EEG file not found!")
        print(f"  Checked raw: {raw_filename}")
        print(f"  Checked source: {source_filename}")
        return

    # =====================================================================
    # Load EEG file
    # =====================================================================
    raw = mne.io.read_raw_bdf(str(raw_filename), preload=True)
    sfreq = raw.info["sfreq"]

    # =====================================================================
    # Read behavioural events
    # =====================================================================
    # read with correct separator (tsv vs csv)
    if str(behavfn).endswith(".tsv"):
        T = pd.read_csv(behavfn, sep="\t")
    else:
        T = pd.read_csv(behavfn)

    print(f"[DEBUG] Behavioural columns: {list(T.columns)}")

    # Find the STATUS channel and read the values from it
    stim_channel = raw.ch_names.index("Status")
    stim_data = raw.get_data(picks=stim_channel)

    # Find rising edges == 1324
    stim_onset_sample = [
        x for x in np.nonzero(np.diff(stim_data)[0] == 13824)[0]
    ]

    # Sanity-check
    print(
        f"[DEBUG] Detected {len(stim_onset_sample)} stim_onset_sample entries"
    )
    a, b = np.unique(np.diff(stim_data)[0], return_counts=1)
    a, b = np.unique(np.diff(stim_onset_sample), return_counts=1)

    # =====================================================================
    # Fix missing triggers
    # =====================================================================
    missingtriggers = len(T) - len(stim_onset_sample)
    if missingtriggers > 0:
        print(f"Reconstructing {missingtriggers} triggers")
        print(f"Triggers: {len(stim_onset_sample)}, Expected: {len(T)}")
        assert missingtriggers < 100, "Too many missing triggers"

        a = [int(x) / sfreq for x in stim_onset_sample]
        b = [x for x in T["time_stimon"]]

        for j in range(1, len(a)):
            da = a[j] - a[j - 1]
            db = b[j] - b[j - 1]
            if da - db > 0.11:
                print(
                    f"Inserting pos:{j} +{a[j-1]+db:.3f}s",
                    f"data:{da:.3f}s_diff({a[j-1]:.3f}s,{a[j]:.3f}s)",
                    f"expected:{db:.3f}s_diff({b[j-1]:.3f}s,{b[j]:.3f}s)",
                )
                a.insert(j, a[j - 1] + db)
                stim_onset_sample.insert(
                    j, int(round(sfreq * (a[j - 1] + db)))
                )

    if len(stim_onset_sample) > len(T):
        print(f"Found not enough events! {len(stim_onset_sample)} vs {len(T)}")

    assert len(stim_onset_sample) <= len(T), "Found too many events!"
    assert len(stim_onset_sample) >= len(T), "Found not enough events!"

    stim_onset_sample = np.array(stim_onset_sample)
    events = np.transpose(
        np.vstack(
            (
                stim_onset_sample,
                0 * stim_onset_sample,
                range(0, len(stim_onset_sample)),
            )
        )
    )

    # =====================================================================
    # Create behavioral dataframe
    # =====================================================================
    # Create behavioral dataframe
    T2 = pd.DataFrame(
        {
            "onset": [int(x) / sfreq for x in stim_onset_sample],
            "duration": 0.20,
            "onsetsample": [int(x) for x in stim_onset_sample],
            "eventnumber": range(len(stim_onset_sample)),
            "subjectnr": int(subjectnr),
        }
    )
    T2 = pd.concat((T2, T), axis=1)

    # Compare event onset times
    diffs = np.diff(T2["onset"].to_numpy()) - np.diff(
        T2["time_stimon"].to_numpy()
    )
    if not np.all(diffs < 0.11):
        # Optional: print debug info like old code
        print(
            "Event time differences (s) exceeding 0.11:", diffs[diffs >= 0.11]
        )
    assert np.all(diffs < 0.11), "Event times do not seem to match"

    # Save behavioral data
    behavfn.parent.mkdir(parents=True, exist_ok=True)
    T2.to_csv(behavfn, sep="\t", index=False)
    T2.to_csv(str(behavfn).replace(".tsv", ".csv"), sep=",", index=False)

    # =====================================================================
    # Preprocessing using config parameters
    # =====================================================================
    print(raw)
    raw.pick("eeg")
    montage = mne.channels.make_standard_montage("biosemi64")

    # Rename channels (A1, A2, etc. to Fp1, AF7, etc.)
    mne.rename_channels(
        raw.info, dict(zip(raw.info.ch_names, montage.ch_names))
    )
    print(raw.info.ch_names)
    raw.set_montage(montage)
    raw.set_eeg_reference()

    # Apply filters from config
    print(f'Applying bandpass filter: {cfg["HighPass"]}-{cfg["LowPass"]} Hz')
    raw.filter(l_freq=cfg["HighPass"], h_freq=cfg["LowPass"])

    # Epoch
    epochs = mne.Epochs(
        raw,
        events,
        tmin=-0.1,
        tmax=0.8,
        baseline=(-0.1, 0),
        detrend=0,
        proj=False,
        preload=True,
    )

    # Resample using config parameter
    if cfg["downsample"] > 0:
        print(f'Resampling to {cfg["downsample"]} Hz')
        epochs.resample(cfg["downsample"])

    print(epochs)
    epochs.save(str(outfn), overwrite=True)

    print("Done!")


# =========================================================================
# Example usage
# =========================================================================
if __name__ == "__main__":
    # Single subject
    # run_preprocess('Exp1_Viewpoints', subjectnr=1, overwrite=1)

    # Run all subjects
    project_name = "Exp1_Viewpoints"
    for s in range(1, 2):
        try:
            run_preprocess(project_name, subjectnr=s, overwrite=1)
        except Exception as e:
            print(f"Error processing subject {s}: {e}")
