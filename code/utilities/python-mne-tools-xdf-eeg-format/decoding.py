#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EEG Decoding Pipeline

Performs temporal decoding analyses on preprocessed EEG data.

Author: Mahdiyeh Khanbagi
Created: 14/10/2025
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import math
import mne
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.svm import LinearSVC
from sklearn.model_selection import LeaveOneGroupOut, GroupKFold
from mne.decoding import (
    SlidingEstimator,
    GeneralizingEstimator,
    cross_val_multiscore,
)

from .preprocessing_config import preprocessing_config
from .viewpoint_decoding_config import viewpoint_decoding_config


def get_classifier(classifier_type, n_classes=None):
    """
    Get classifier pipeline based on type.

    Parameters
    ----------
    classifier_type : str
        Type of classifier ('lda', 'logreg', 'svm')
    n_classes : int, optional
        Number of classes for setting priors

    Returns
    -------
    clf : sklearn pipeline
        Classifier pipeline
    """
    if classifier_type == "lda":
        if n_classes is not None:
            priors = (1 + 0 * np.arange(n_classes)) / n_classes
            clf = make_pipeline(
                LinearDiscriminantAnalysis(priors=priors, solver="eigen")
            )
        else:
            clf = make_pipeline(LinearDiscriminantAnalysis(solver="eigen"))

    elif classifier_type == "logreg":
        clf = make_pipeline(
            StandardScaler(),
            LogisticRegression(max_iter=1000, solver="liblinear"),
        )

    elif classifier_type == "svm":
        clf = make_pipeline(
            StandardScaler(), LinearSVC(max_iter=10000, dual=False)
        )
    else:
        raise ValueError(f"Unknown classifier type: {classifier_type}")

    return clf


def prepare_decoding_data(epochs, behav_data, decode_type, cv_scheme):
    """
    Prepare data for decoding based on type and CV scheme.

    Parameters
    ----------
    epochs : mne.Epochs
        Preprocessed epochs
    behav_data : pd.DataFrame
        Behavioral data
    decode_type : str
        Type of decoding ('category', 'identity', 'size_2class', etc.)
    cv_scheme : str
        Cross-validation scheme ('one_rotation_out', 'one_block_out')

    Returns
    -------
    X : np.ndarray
        Data array (n_epochs, n_channels, n_times)
    y : np.ndarray
        Labels for decoding
    groups : np.ndarray
        Group labels for cross-validation
    n_classes : int
        Number of classes
    """
    # Filter out target trials if present
    if "istarget" in behav_data.columns:
        idx = ~behav_data["istarget"].astype(bool)
        behav_data = behav_data[idx].reset_index(drop=True)
        X = epochs.get_data()[idx, :, :]
    else:
        X = epochs.get_data()

    # Determine labels based on decode_type
    if decode_type == "category":
        # Decode object category (group of 8 rotations)
        y = np.array([math.ceil(x / 8) for x in behav_data["stimnumber"]])

    elif decode_type == "identity":
        # Decode individual stimulus identity
        y = np.array(behav_data["stimnumber"])

    elif decode_type == "size_2class":
        # Binary size classification
        if "stimsize" in behav_data.columns:
            y = np.array(behav_data["stimsize"])
            # Convert to binary if needed
            unique_sizes = np.unique(y)
            if len(unique_sizes) > 2:
                median_size = np.median(y)
                y = (y > median_size).astype(int)
        else:
            raise ValueError("'stimsize' column not found in behavioral data")

    elif decode_type == "size_3class":
        # Three-class size classification
        if "stimsize" in behav_data.columns:
            y = np.array(behav_data["stimsize"])
            # Convert to 3 classes if needed
            unique_sizes = np.unique(y)
            if len(unique_sizes) != 3:
                # Bin into tertiles
                tertiles = np.percentile(y, [33.33, 66.67])
                y = np.digitize(y, tertiles)
        else:
            raise ValueError("'stimsize' column not found in behavioral data")
    else:
        raise ValueError(f"Unknown decode_type: {decode_type}")

    # Determine groups for cross-validation
    if cv_scheme == "one_rotation_out":
        # Group by rotation (modulo 8 of stimulus number)
        groups = np.array([x % 8 for x in behav_data["stimnumber"]])

    elif cv_scheme == "one_block_out":
        # Group by block
        if "blocksequencenumber" in behav_data.columns:
            groups = np.array(behav_data["blocksequencenumber"])
        else:
            raise ValueError("'blocksequencenumber' column not found")
    else:
        raise ValueError(f"Unknown cv_scheme: {cv_scheme}")

    n_classes = len(np.unique(y))

    return X, y, groups, n_classes


def run_temporal_decoding(X, y, groups, cfg, n_classes):
    """
    Run temporal decoding analysis.

    Parameters
    ----------
    X : np.ndarray
        Data array (n_epochs, n_channels, n_times)
    y : np.ndarray
        Labels
    groups : np.ndarray
        Group labels for CV
    cfg : dict
        Configuration dictionary
    n_classes : int
        Number of classes

    Returns
    -------
    scores : np.ndarray
        Cross-validated scores across time
    """
    # Get classifier
    clf = get_classifier(cfg["classifier"], n_classes)

    # Create temporal decoder
    if cfg["temporal_decoding"]["method"] == "sliding":
        time_decoder = SlidingEstimator(
            clf,
            n_jobs=cfg["n_jobs"],
            scoring=cfg["scoring"],
            verbose=cfg["temporal_decoding"]["verbose"],
        )
    elif cfg["temporal_decoding"]["method"] == "generalizing":
        time_decoder = GeneralizingEstimator(
            clf,
            n_jobs=cfg["n_jobs"],
            scoring=cfg["scoring"],
            verbose=cfg["temporal_decoding"]["verbose"],
        )
    else:
        raise ValueError(
            f"Unknown method: {cfg['temporal_decoding']['method']}"
        )

    # Run cross-validation
    scores = cross_val_multiscore(
        time_decoder,
        X,
        y,
        groups=groups,
        cv=LeaveOneGroupOut(),
        n_jobs=cfg["n_jobs"],
    )

    return scores


def plot_decoding_results(
    times, scores, decode_type, chance_level, save_path=None
):
    """
    Plot temporal decoding results.

    Parameters
    ----------
    times : np.ndarray
        Time points
    scores : np.ndarray
        Mean decoding scores across time
    decode_type : str
        Type of decoding
    chance_level : float
        Chance level for this decoding
    save_path : Path or str, optional
        Path to save figure
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    # Plot mean score
    ax.plot(times, scores, label="Decoding accuracy", linewidth=2)

    # Add chance level
    ax.axhline(
        chance_level,
        color="k",
        linestyle="--",
        label=f"Chance ({chance_level:.3f})",
        linewidth=1.5,
    )

    # Add stimulus onset
    ax.axvline(0.0, color="k", linestyle="-", linewidth=1, alpha=0.5)

    # Labels and formatting
    ax.set_xlabel("Time (s)", fontsize=12)
    ax.set_ylabel("Accuracy", fontsize=12)
    ax.set_title(
        f'{decode_type.replace("_", " ").title()} Decoding', fontsize=14
    )
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        fig.savefig(save_path, dpi=300, bbox_inches="tight")
        plt.close(fig)
    else:
        plt.show()


def run_decoding(
    project_name,
    subjectnr,
    participant_group="adults",
    decode_types=None,
    cv_schemes=None,
    overwrite=None,
):
    """
    Run decoding analysis for a single subject.

    Parameters
    ----------
    project_name : str
        Name of the project
    subjectnr : int or str
        Subject number
    participant_group : str, optional
        Participant group ('adults' or 'infants')
    decode_types : list of str, optional
        Types of decoding to run. If None, runs all available types.
    cv_schemes : list of str, optional
        CV schemes to use. If None, uses 'one_rotation_out'.
    overwrite : bool, optional
        Whether to overwrite existing results

    Returns
    -------
    results : dict
        Dictionary containing decoding results for each analysis
    """
    # Load configurations
    cfg_preproc = preprocessing_config(project_name)
    cfg_decode = viewpoint_decoding_config(project_name)

    # Handle overwrite setting
    if overwrite is None:
        overwrite = cfg_decode["overwrite"]

    # Format subject number
    if isinstance(subjectnr, int):
        subjectnr = f"{subjectnr:02d}"

    print(f'\n{"="*70}')
    print(f"DECODING: Subject {subjectnr} ({participant_group})")
    print(f'{"="*70}')

    # Define paths using config
    epochs_file = (
        cfg_preproc["preproc_dir"]
        / participant_group
        / f"sub-{subjectnr}"
        / "mne"
        / f"sub-{subjectnr}_mne_epo.fif"
    )
    behav_file = (
        cfg_preproc["rawdata_dir"]
        / participant_group
        / f"sub-{subjectnr}"
        / "eeg"
        / f"sub-{subjectnr}_task-targets_events.tsv"
    )

    # Check if files exist
    if not epochs_file.exists():
        raise FileNotFoundError(f"Epochs file not found: {epochs_file}")
    if not behav_file.exists():
        raise FileNotFoundError(f"Behavioral file not found: {behav_file}")

    # Load data
    print(f"Loading epochs from: {epochs_file}")
    epochs = mne.read_epochs(str(epochs_file), preload=True)

    print(f"Loading behavioral data from: {behav_file}")
    behav_data = pd.read_csv(behav_file, delimiter="\t")

    # Plot epochs average if requested
    if cfg_decode.get("plot_results", False) and cfg_decode.get(
        "savefile", False
    ):
        avg = epochs.average()
        fig = avg.plot_joint(show=False)

        # Default dpi if not in config
        dpi = cfg_decode.get("plotting", {}).get("dpi", 100)

        fig_path = cfg_decode["figures_dir"] / f"sub-{subjectnr}_epochs.png"
        fig.savefig(fig_path, dpi=dpi)
        plt.close(fig)
        print(f"Saved epoch plot: {fig_path}")

    # Set default decode types and CV schemes
    if decode_types is None:
        decode_types = ["category"]
    if cv_schemes is None:
        cv_schemes = ["one_rotation_out"]

    # Storage for results
    results = {}
    all_scores_df = pd.DataFrame({"time": epochs.times})

    # Run each decoding analysis
    for decode_type in decode_types:
        for cv_scheme in cv_schemes:
            analysis_name = f"{decode_type}_{cv_scheme}"
            print(f"\n--- Running: {analysis_name} ---")

            # Check if results already exist
            result_file = (
                cfg_decode["results_dir"]
                / f"sub-{subjectnr}_{analysis_name}_results.csv"
            )
            if result_file.exists() and not overwrite:
                print(f"Results exist, skipping: {result_file}")
                continue

            # Prepare data
            try:
                X, y, groups, n_classes = prepare_decoding_data(
                    epochs, behav_data, decode_type, cv_scheme
                )
                print(
                    f"Data prepared: {X.shape[0]} trials, {n_classes} classes"
                )

            except Exception as e:
                print(f"Error preparing data: {str(e)}")
                continue

            # Run decoding
            scores = run_temporal_decoding(X, y, groups, cfg_decode, n_classes)
            mean_scores = np.mean(scores, axis=0)

            # Calculate chance level
            chance_level = 1.0 / n_classes

            # Store results
            results[analysis_name] = {
                "scores": scores,
                "mean_scores": mean_scores,
                "chance_level": chance_level,
                "n_classes": n_classes,
                "n_trials": X.shape[0],
            }

            # Add to combined dataframe
            all_scores_df[analysis_name] = mean_scores

            # Plot results
            if cfg_decode["plotting"]["save_figs"]:
                fig_path = (
                    cfg_decode["figures_dir"]
                    / f"sub-{subjectnr}_{analysis_name}_decoding.png"
                )
                plot_decoding_results(
                    epochs.times,
                    mean_scores,
                    decode_type,
                    chance_level,
                    save_path=fig_path,
                )
                print(f"Saved figure: {fig_path}")

            # Save individual results
            if cfg_decode["save_results"]:
                result_df = pd.DataFrame(
                    {
                        "time": epochs.times,
                        "accuracy": mean_scores,
                        "chance": chance_level,
                    }
                )
                result_df.to_csv(result_file, index=False)
                print(f"Saved results: {result_file}")

            print(f"✓ Completed: {analysis_name}")
            print(
                f"  Peak accuracy: {mean_scores.max():.3f} at {epochs.times[mean_scores.argmax()]:.3f}s"
            )

    # Save combined results
    if cfg_decode["save_results"]:
        combined_file = (
            cfg_decode["results_dir"] / f"sub-{subjectnr}_all_results.csv"
        )
        all_scores_df.to_csv(combined_file, index=False)
        print(f"\nSaved combined results: {combined_file}")

    print(f'\n{"="*70}')
    print(f"DECODING COMPLETED: Subject {subjectnr}")
    print(f'{"="*70}\n')

    return results


# =======================================================================
# EXAMPLE USAGE
# =======================================================================
if __name__ == "__main__":
    # Single subject, single analysis
    results = run_decoding(
        "Exp1_Viewpoints",
        subjectnr=1,
        participant_group="adults",
        decode_types=["category"],
        cv_schemes=["one_rotation_out"],
        overwrite=True,
    )

    # Multiple analyses
    # results = run_decoding(
    #     'Exp1_Viewpoints',
    #     subjectnr=1,
    #     decode_types=['category', 'size_2class'],
    #     cv_schemes=['one_rotation_out', 'one_block_out']
    # )
