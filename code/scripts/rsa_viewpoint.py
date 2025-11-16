#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Author:    Mahdiyeh Khanbagi

Email:     mkhanbagi@gmail.com

Created:   Sat Oct 25 13:12:37 2025

----------
Study:
    Representational Similarity Analysis for Viewpoint-tolerant
    Object Representations in Infants and Adults

    This script performs RSA to compare neural representations across different
    viewpoint conditions in EEG data, examining how viewpoint-change affects neural
    similarity structures.


Description:
    - Loads generated representational dissimilarity matrices (RDMs) from EEG data
    - Compares neural RDMs with model RDMs (e.g., behavioral, computational)
    - Analyzes temporal dynamics of viewpoint representation

Inputs:
    - Neural RDMs
    - Model RDMs (if applicable)

Outputs:
    - RSA correlation results
    - Statistical significance maps
    - Visualization plots

Dependencies:
    - numpy, scipy, scikit-learn
    - mne (for EEG processing)

----------
References:
    - Kriegeskorte et al. (2008) - RSA methodology

"""

# ENVIRONMENT SETUP ============================================================
# In Spyder, you can manually clear with:
# - Variable Explorer: click the eraser icon
# - Console: Ctrl+L or %clear in IPython console

import gc

gc.collect()


# LOAD DEPENDENCIES ============================================================
import os
import re
import sys
import json
import imageio
import itertools
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from scipy.io import savemat
from scipy.stats import spearmanr
from scipy.spatial.distance import squareform

# Set directories
main_dir = "/Users/22095708/Documents/PhD/Project"
project_name = "viewpoint"
os.chdir(main_dir)

# Add custom functions path
sys.path.append("./shared/tools")
from load_mat_flexible import load_mat_flexible

# CONFIGURATION SETUP ==========================================================
setting = {
    # Analysis pipelines
    "pipelines": {
        "plot_RDMs": True,
        "corr2model": True,
        "time_time_correlation": True,
        "temporal_generalisation": False,
    },
    # Analysis parameters
    "analysis": {
        "model_RDMs": ["animacy"],
        "corr_metric": ["spearman"],
        "target_dim": ["identity"],
        "crossval_method": ["one_rotation_out"],
        "analysis_version": None,  # Options: 'all_all', 'intact_occl'
    },
    # Data selection
    "data_selection": {
        "group": ["infants"],  # Options: 'all', 'infants', 'adults'
        "sample": ["6mo_selected"],  # Options: 'all', '7mo', ['6mo', '7mo']
        "subjects": None,  # Options: [1], [14:25], [4,7,9,23,45]
    },
}

# Import extra config
config_path = os.path.join(
    main_dir, "shared/config", f"{project_name}_RSA_config.json"
)

with open(config_path, "r") as file:
    project_config = json.load(file)

# ANALYSIS MAIN LOOP ===========================================================
# ------------------
group_to_run = setting["data_selection"]["group"][0]
samples_to_run = setting["data_selection"]["sample"][0]

if setting["data_selection"]["subjects"] is not None:
    subjects_to_run = setting["data_selection"]["subjects"]
else:
    # Extract the first element from the lists using [0]
    subjects_to_run = project_config["groups"][group_to_run]["samples"][
        samples_to_run
    ]

# Define the reordering indices (Python uses 0-based indexing)
animate_indices = [
    1,
    2,
    3,
    4,
    6,
    7,
    8,
]  # MATLAB [2,3,4,5,7,8,9] -> Python [1,2,3,4,6,7,8]
inanimate_indices = [
    0,
    5,
    9,
    10,
    11,
    12,
    13,
]  # MATLAB [1,6,10,11,12,13,14] -> Python [0,5,9,10,11,12,13]
# Create the new order
new_order = animate_indices + inanimate_indices

# Define the item labels (original order)
original_labels = [
    "chair",
    "deer",
    "dog",
    "dolphin",
    "llama",
    "lamp",
    "lion",
    "pigeon",
    "rabbit",
    "sofa",
    "plane",
    "tower",
    "train",
    "xylophone",
]

# Reorder the labels
reordered_labels = [original_labels[i] for i in new_order]
# ------------------
# I) Generate a .GIF file for Evolving Representational Space
#
# Step 1) Import RDMs and Plot Heatmaps

if setting["pipelines"]["plot_RDMs"]:
    RDM_avg = np.zeros(project_config["groups"][group_to_run]["RDM_size"])

    for s in subjects_to_run:
        subjectnr = f"{s:02d}"
        RDM_path = os.path.join(
            project_config["paths"]["variables_path"],
            f"{group_to_run}_sub-{subjectnr}_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}.mat",
        )

        RDM_ind = load_mat_flexible(RDM_path)["RDM"]
        if setting["data_selection"]["group"][0] == "infants":
            RDM_ind = np.transpose(RDM_ind, (1, 2, 0))
        # Rearrange the RDM for all timepoints - Using numpy's advanced indexing to reorder rows and columns
        RDM_rearranged = RDM_ind[np.ix_(new_order, new_order)]

        n_timpeoints = RDM_ind.shape[2]
        time_values = np.linspace(-100, 800, n_timpeoints)

        RDM_avg = RDM_avg + RDM_ind

    RDM_avg = RDM_avg / len(subjects_to_run)

    for t in range(0, n_timpeoints):
        RDM_timepoint = RDM_avg[:, :, t]
        fig = plt.figure(figsize=(8, 6))
        ax = plt.gca()

        # Create the heatmap
        im = ax.imshow(
            RDM_timepoint,
            aspect="equal",
            origin="upper",
            vmin=np.percentile(RDM_timepoint, 5),
            vmax=np.percentile(RDM_timepoint, 95),
            cmap="viridus",
        )
        #

        # Add grid lines to separate animate/inanimate blocks
        ax.axhline(
            y=6.5, color="white", linewidth=2, linestyle="--", alpha=0.5
        )
        ax.axvline(
            x=6.5, color="white", linewidth=2, linestyle="--", alpha=0.5
        )

        # Set tick positions and labels for rows
        ax.set_yticks(range(len(reordered_labels)))
        ax.set_yticklabels(reordered_labels, fontsize=9)

        # Set tick positions and labels for columns
        ax.set_xticks(range(len(reordered_labels)))
        ax.set_xticklabels(
            reordered_labels, fontsize=9, rotation=45, ha="right"
        )
        # ax.set_xticklabels([])

        plt.colorbar(im, ax=ax, label="Pairwise Decoding Accuracy")
        ax.set_title(f"Representational Space at t = {time_values[t]} ms")

        plt.tight_layout()

        # Save the figure
        figfn = os.path.join(
            main_dir,
            project_name,
            f"rsa/representational-space-timecourse/{group_to_run}_{setting['data_selection']['sample'][0]}(n={len(subjects_to_run)})_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}(t={time_values[t]}ms).png",
        )
        plt.savefig(figfn, dpi=300, bbox_inches="tight")
        plt.close(fig)  # Explicitly close the figure

    # Step 2) Create GIF from Generated Images

    # Directory where images are saved

    img_dir = os.path.join(
        main_dir, project_name, "rsa/representational-space-timecourse/"
    )

    # Pattern to match the image files for this subject
    pattern = f"{group_to_run}_{setting['data_selection']['sample'][0]}(n={len(subjects_to_run)})_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}"

    # Get all PNG files for this subject
    image_files = [
        f
        for f in os.listdir(img_dir)
        if f.startswith(pattern) and f.endswith(".png")
    ]

    # Extract time values and sort files chronologically
    def get_time_value(filename):
        # Extract the time value from filename using regex
        match = re.search(r"\(t=([-\d.]+)ms\)", filename)
        if match:
            return float(match.group(1))
        return 0

    # Sort files by time value
    image_files.sort(key=get_time_value)

    # Full paths to images
    image_paths = [os.path.join(img_dir, f) for f in image_files]

    # Read all images
    images = []
    for img_path in image_paths:
        images.append(imageio.imread(img_path))

    # Create GIF output path
    gif_path = os.path.join(
        main_dir,
        project_name,
        "rsa",
        f"{group_to_run}_{setting['data_selection']['sample'][0]}(n={len(subjects_to_run)})_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}.gif",
    )

    # Save as GIF
    # duration is in seconds per frame (0.1 = 100ms per frame = 10 fps)
    imageio.mimsave(gif_path, images, duration=0.1, loop=0)

    print(f"GIF created successfully: {gif_path}")
    print(f"Total frames: {len(images)}")


# ------------------
# II) Correlation to Model RDMs
#
if setting["pipelines"]["corr2model"]:
    # --- Generate all possible combinations ---
    all_combinations = list(
        itertools.product(
            setting["analysis"]["model_RDMs"],
            setting["analysis"]["corr_metric"],
        )
    )

    print("All possible combinations:")
    for model, metric in all_combinations:
        print(f"{model} × {metric}")

    # --- Loop over combinations specified in settings ---
    print("\nRunning analysis for selected combinations:")

    for model, metric in all_combinations:
        print("Running Correlation Analysis for RDM-model:")
        print(f"{model}\n")
        print("Correlation Metric:")
        print(f"{metric}\n")

    # Alternatively, create the animacy RDM manually
    animacy_rdm = np.zeros(project_config["groups"][group_to_run]["RDM_size"])
    animacy_rdm = animacy_rdm[:, :, 0]
    animacy_rdm[0:7, 7:14] = 1
    animacy_rdm[7:14, 0:7] = 1
    # (upper-left and bottom-right blocks remain zero)

    # Overwrite model_rdm with animacy_rdm
    model_rdm = animacy_rdm

    # Initialize results
    corr_all = []

    # Loop over subjects
    for subjectnr in subjects_to_run:
        RDM_path = os.path.join(
            main_dir,
            project_name,
            "derivatives",
            f"{group_to_run}_sub-{subjectnr:02d}_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}.mat",
        )

        ind_RDM = load_mat_flexible(RDM_path)["RDM"]
        if setting["data_selection"]["group"][0] == "infants":
            ind_RDM = np.transpose(ind_RDM, (1, 2, 0))
        ind_RDM_rearranged = ind_RDM[np.ix_(new_order, new_order)]
        n_timpeoints = ind_RDM_rearranged.shape[2]
        time_values = np.linspace(-100, 800, n_timpeoints)

        ind_corr = []

        for t in range(n_timpeoints):
            RDM1 = squareform(
                ind_RDM_rearranged[:, :, t]
            )  # flatten upper triangle
            RDM2 = squareform(model_rdm)

            # Spearman correlation
            r, _ = spearmanr(RDM1, RDM2)
            ind_corr.append(r)

        corr_all.append(ind_corr)

        # Save per-subject correlation CSV
        csv_path = os.path.join(
            main_dir,
            project_name,
            "derivatives",
            f"{group_to_run}_sub-{subjectnr:02d}_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}_corr2{setting['analysis']['model_RDMs'][0]}({setting['analysis']['corr_metric'][0]}).csv",
        )
        pd.DataFrame(ind_corr, columns=["SpearmanR"]).to_csv(
            csv_path, index=False
        )

        # Plot the correlation per-subject
        fig, ax = plt.subplots(figsize=(3.33, 2.08), constrained_layout=True)

        # Shade stimulus duration
        ax.axvspan(
            0, 150, color="#EBEBEB", alpha=0.8, label="Stimulus Duration"
        )

        # Plot average correlation
        ax.plot(
            time_values, ind_corr, label="Score", color="#57BD7E", linewidth=1
        )

        # Plot rolling mean
        rolling_mean = (
            pd.Series(ind_corr).rolling(window=10, center=True).mean()
        )
        ax.plot(time_values, rolling_mean, color="#337476", linewidth=1.5)

        # Set x-axis ticks (adjust as needed)
        ax.set_xticks(range(-100, 900, 300))
        ax.set_xlabel("Timepoints (ms)")
        ax.set_ylabel("Spearman correlation")

        # Add horizontal line at 0 (chance level)
        chance_level = 0
        ax.axhline(chance_level, color="#962C37", linestyle="--")

        fig.tight_layout()

        # Save the Figure
        fig_path = os.path.join(
            main_dir,
            project_name,
            "rsa/correlation-model-RDMs",
            f"{group_to_run}_sub-{subjectnr:02d}_corr2{setting['analysis']['model_RDMs'][0]}({setting['analysis']['corr_metric'][0]}).png",
        )
        plt.savefig(fig_path)
        plt.close()

    # Convert to NumPy array
    corr_all = np.array(corr_all)  # shape: nInfants x time/condition

    # Save the combined correlations file
    csv_path = os.path.join(
        main_dir,
        project_name,
        "derivatives",
        f"{group_to_run}_{setting['data_selection']['sample'][0]}(n={len(subjects_to_run)})_corr2{setting['analysis']['model_RDMs'][0]}({setting['analysis']['corr_metric'][0]}).csv",
    )

    pd.DataFrame(corr_all).to_csv(csv_path, index=False)

    # Compute the average
    corr_avg = np.mean(corr_all, 0)

    # Plot the correlation of average of subjects
    fig, ax = plt.subplots(figsize=(3.33, 2.08), constrained_layout=True)

    # Shade stimulus duration
    ax.axvspan(0, 150, color="#EBEBEB", alpha=0.8, label="Stimulus Duration")

    # Plot average correlation
    ax.plot(time_values, corr_avg, label="Score", color="#57BD7E", linewidth=1)

    # Plot rolling mean
    rolling_mean = pd.Series(corr_avg).rolling(window=10, center=True).mean()
    ax.plot(time_values, rolling_mean, color="#337476", linewidth=1.5)

    # Set x-axis ticks (adjust as needed)
    ax.set_xticks(range(-100, 900, 300))
    ax.set_xlabel("Timepoints (ms)")
    ax.set_ylabel("Spearman correlation")

    # Add horizontal line at 0 (chance level)
    chance_level = 0
    ax.axhline(chance_level, color="#962C37", linestyle="--")

    fig.tight_layout()

    # Save results
    fig_path = os.path.join(
        main_dir,
        project_name,
        "rsa/correlation-model-RDMs",
        f"{group_to_run}_{setting['data_selection']['sample'][0]}(n={len(subjects_to_run)})_corr2{setting['analysis']['model_RDMs'][0]}({setting['analysis']['corr_metric'][0]}).png",
    )
    plt.savefig(fig_path)
    plt.close()


# ------------------
# III) Time-time Correlation to Adult RDMs
#
if setting["pipelines"]["time_time_correlation"]:

    # Generate Average Adult RDM
    RDM_avg = np.zeros(project_config["groups"]["adults"]["RDM_size"])

    for subjectnr in project_config["groups"]["adults"]["samples"]["all"]:
        RDM_path = os.path.join(
            main_dir,
            project_name,
            "derivatives",
            f"adults_sub-{subjectnr:02d}_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}.mat",
        )

        ind_RDM = load_mat_flexible(RDM_path)["RDM"]
        ind_RDM_rearranged = ind_RDM[np.ix_(new_order, new_order)]

        RDM_avg = RDM_avg + ind_RDM_rearranged

    RDM_avg_adult = RDM_avg / len(
        project_config["groups"]["adults"]["samples"]["all"]
    )
    adlt_n_timepoints = RDM_avg_adult.shape[2]
    adlt_time_values = np.linspace(-100, 800, adlt_n_timepoints)

    # Loop over subjects
    ttcorr_all = []

    for subjectnr in subjects_to_run:
        RDM_path = os.path.join(
            main_dir,
            project_name,
            "derivatives",
            f"{group_to_run}_sub-{subjectnr:02d}_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}.mat",
        )

        ind_RDM = load_mat_flexible(RDM_path)["RDM"]
        if setting["data_selection"]["group"][0] == "infants":
            ind_RDM = np.transpose(ind_RDM, (1, 2, 0))
        ind_RDM_rearranged = ind_RDM[np.ix_(new_order, new_order)]

        inf_n_timpeoints = ind_RDM_rearranged.shape[2]
        inf_time_values = np.linspace(-100, 800, inf_n_timpeoints)

        ttcorr_ind = np.zeros((adlt_n_timepoints, inf_n_timpeoints))

        for adlt_time in range(adlt_n_timepoints):
            for inf_time in range(inf_n_timpeoints):
                RDM1 = squareform(
                    ind_RDM_rearranged[:, :, inf_time]
                )  # flatten upper triangle
                RDM2 = squareform(RDM_avg_adult[:, :, adlt_time])

                # Spearman correlation
                ttcorr, _ = spearmanr(RDM1, RDM2)
                ttcorr_ind[adlt_time, inf_time] = ttcorr

        # Save per-subject correlation CSV
        csv_path = os.path.join(
            main_dir,
            project_name,
            "derivatives",
            f"{group_to_run}_sub-{subjectnr:02d}_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}_ttcorr2avg_adult({setting['analysis']['corr_metric'][0]}).csv",
        )

        np.savetxt(csv_path, ttcorr_ind, delimiter=",")

        # Create a new figure explicitly
        fig = plt.figure(figsize=(8, 6))
        ax = plt.gca()

        # Now visualize the correlation matrix (ttcorr) instead of infant_RDM
        x_labels = inf_time_values
        y_labels = adlt_time_values

        # Create the heatmap
        im = ax.imshow(
            ttcorr_ind,
            aspect="equal",
            extent=[x_labels[0], x_labels[-1], y_labels[0], y_labels[-1]],
            origin="lower",
        )

        # Set ticks every 200 units
        xticks = np.arange(x_labels[0], x_labels[-1] + 1, 200)
        ax.set_xticks(xticks)
        yticks = np.arange(y_labels[0], y_labels[-1] + 1, 200)
        ax.set_yticks(yticks)

        ax.set_xlabel("Time (ms) - infants")
        ax.set_ylabel("Time (ms) - adults")
        plt.colorbar(im, ax=ax, label="Correlation (Spearman's rho)")
        ax.set_title(f"RDM Correlation Infant-Adult (Subject {subjectnr})")

        plt.tight_layout()

        # Save the Figure
        fig_path = os.path.join(
            main_dir,
            project_name,
            "rsa/time-time-correlation",
            f"{group_to_run}_sub-{subjectnr:02d}_RDM_{setting['analysis']['target_dim'][0]}_{setting['analysis']['crossval_method'][0]}_ttcorr2avg_adult({setting['analysis']['corr_metric'][0]}).png",
        )
        plt.savefig(fig_path)
        plt.close()

    # Generate the Combined "ttcorr" File and Load it
    def combine_ttcorr_csvs(input_dir, output_path):
        pattern = re.compile(r"infants_sub-(\d{2}).*corr2avg.*\.csv")
        all_matrices = []

        for filename in sorted(os.listdir(input_dir)):
            if pattern.match(filename):
                print(f"Reading {filename} ...")
                mat = np.loadtxt(
                    os.path.join(input_dir, filename), delimiter=","
                )
                all_matrices.append(mat)

        if not all_matrices:
            print("❌ No matching CSV files found.")
            return

        print(f"✅ Loaded {len(all_matrices)} CSVs")

        # Stack along new axis → shape: (n_subjects, 180, 225)
        ttcorr_all = np.stack(all_matrices, axis=0)
        print("Combined shape:", ttcorr_all.shape)

        # Save only as .npy
        np.save(output_path, ttcorr_all)
        print(f"Saved combined 3D array to: {output_path}")

        return ttcorr_all

    # Save the combined correlations file
    csv_path = os.path.join(
        main_dir,
        project_name,
        "derivatives",
        f"{group_to_run}_{setting['data_selection']['sample'][0]}(n={len(subjects_to_run)})_ttcorr2avg_adlt({setting['analysis']['corr_metric'][0]}).csv",
    )

    ttcorr_all = combine_ttcorr_csvs(
        "/Users/22095708/Documents/PhD/Project/viewpoint/derivatives", csv_path
    )

    # Generate the Average of All
    subjects_to_run_zero_based = [s - 1 for s in subjects_to_run]
    ttcorr_all = ttcorr_all[subjects_to_run_zero_based, :, :]
    ttcorr_avg = np.mean(ttcorr_all, 0)

    # Create a new figure explicitly
    fig = plt.figure(figsize=(8, 6))
    ax = plt.gca()

    # Now visualize the correlation matrix
    x_labels = np.linspace(-100, +800, ttcorr_avg.shape[1])
    y_labels = np.linspace(-100, +800, ttcorr_avg.shape[0])

    # Create the heatmap
    im = ax.imshow(
        ttcorr_avg,
        aspect="equal",
        extent=[x_labels[0], x_labels[-1], y_labels[0], y_labels[-1]],
        origin="lower",
    )

    # Set ticks every 200 units
    xticks = np.arange(x_labels[0], x_labels[-1] + 1, 200)
    ax.set_xticks(xticks)
    yticks = np.arange(y_labels[0], y_labels[-1] + 1, 200)
    ax.set_yticks(yticks)

    ax.set_xlabel("Time (ms) - infants")
    ax.set_ylabel("Time (ms) - adults")
    plt.colorbar(im, ax=ax, label="Correlation (Spearman's rho)")
    ax.set_title(
        f"RDM Correlation Infants : {samples_to_run} (n = {len(subjects_to_run)}) -Adult "
    )

    plt.tight_layout()

    # Save results
    fig_path = os.path.join(
        main_dir,
        project_name,
        "rsa/time-time-correlation",
        f"{group_to_run}_{setting['data_selection']['sample'][0]}(n={len(subjects_to_run)})_ttcorr2{setting['analysis']['model_RDMs'][0]}({setting['analysis']['corr_metric'][0]}).png",
    )
    plt.savefig(fig_path)
    plt.close()
