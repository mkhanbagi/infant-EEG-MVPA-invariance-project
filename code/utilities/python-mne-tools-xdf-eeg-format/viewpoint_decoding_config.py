#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
viewpoint_decoding_config - Configuration for EEG decoding analysis

Author: Mahdiyeh Khanbagi
Created: 20/07/2025
Modified: 14/10/2025

Generates configuration parameters for multivariate pattern analysis (MVPA).
Defines stimulus categories, decoding targets, and cross-validation schemes.

Usage:
    cfg = viewpoint_decoding_config(project_name)

Output:
    cfg - Configuration dict containing:
          - Stimulus metadata and categorizations
          - Decoding analysis parameters
          - Cross-validation settings
          - Participant information

Note: Requires helper functions assign_class_labels() and decode_size()
"""

from pathlib import Path
import pandas as pd
import numpy as np


def assign_class_labels(stimnum_array, category_dict):
    """
    Assign class labels based on stimulus number and category dictionary.

    Parameters
    ----------
    stimnum_array : array-like
        Array of stimulus numbers
    category_dict : dict
        Dictionary mapping category names to stimulus number lists

    Returns
    -------
    labels : np.ndarray
        Class labels (1-indexed)
    """
    labels = np.zeros(len(stimnum_array), dtype=int)

    for class_idx, (category_name, stim_list) in enumerate(
        category_dict.items(), start=1
    ):
        mask = np.isin(stimnum_array, stim_list)
        labels[mask] = class_idx

    return labels


def decode_size(behav_data, size_type="2class"):
    """
    Assign size class labels from behavioral data.

    Parameters
    ----------
    behav_data : pd.DataFrame
        Behavioral data containing 'stimsize' column
    size_type : str
        Type of size classification ('2class' or '3class')

    Returns
    -------
    labels : np.ndarray
        Size class labels
    """
    if "stimsize" not in behav_data.columns:
        raise ValueError("'stimsize' column not found in behavioral data")

    sizes = behav_data["stimsize"].values

    if size_type == "2class":
        # Binary: large vs small (median split)
        median_size = np.median(sizes)
        labels = np.where(sizes > median_size, 1, 2)  # 1=large, 2=small

    elif size_type == "3class":
        # Tertile split: small, medium, large
        tertiles = np.percentile(sizes, [33.33, 66.67])
        labels = np.digitize(sizes, tertiles) + 1  # 1=small, 2=medium, 3=large

    else:
        raise ValueError(f"Unknown size_type: {size_type}")

    return labels


def viewpoint_decoding_config(project_name="viewpoint"):
    """
    Generate EEG decoding configuration.

    Parameters
    ----------
    project_name : str
        Name of the project folder

    Returns
    -------
    cfg : dict
        Configuration dictionary with all decoding parameters
    """

    cfg = {}

    # ===================================================================
    # PROJECT PATHS
    # ===================================================================
    cfg["project_path"] = (
        Path.home() / "Documents" / "PhD" / "Project" / project_name
    )
    cfg["preproc_dir"] = cfg["project_path"] / "data" / "preprocessed"
    cfg["results_dir"] = (
        cfg["project_path"] / "data" / "derivatives" / "results"
    )
    cfg["figures_dir"] = cfg["results_dir"] / "figures"

    # Create directories
    cfg["results_dir"].mkdir(parents=True, exist_ok=True)
    cfg["figures_dir"].mkdir(parents=True, exist_ok=True)

    # ===================================================================
    # STIMULUS CONFIGURATION (112 total stimuli)
    # ===================================================================
    cfg["total_nstimuli"] = 112
    cfg["stimnum"] = {}

    # --- Category-based grouping ---
    # Animate objects (56 stimuli: 7 animals × 8 viewpoints)
    cfg["stimnum"]["category"] = {
        "animate": list(range(9, 41))
        + list(
            range(49, 73)
        ),  # Deer, Dog, Dolphin, Llama, Lion, Pigeon, Rabbit
        "inanimate": list(range(1, 9))
        + list(range(41, 49))
        + list(
            range(73, 113)
        ),  # Chair, Lamp, Sofa, Plane, Tower, Train, Xylophone
    }

    # --- Identity-based grouping (14 objects × 8 viewpoints each) ---
    cfg["stimnum"]["identity"] = {
        "deer": [9, 10, 11, 12, 13, 14, 15, 16],
        "dog": [17, 18, 19, 20, 21, 22, 23, 24],
        "dolphin": [25, 26, 27, 28, 29, 30, 31, 32],
        "llama": [33, 34, 35, 36, 37, 38, 39, 40],
        "lion": [49, 50, 51, 52, 53, 54, 55, 56],
        "pigeon": [57, 58, 59, 60, 61, 62, 63, 64],
        "rabbit": [65, 66, 67, 68, 69, 70, 71, 72],
        "chair": [1, 2, 3, 4, 5, 6, 7, 8],
        "lamp": [41, 42, 43, 44, 45, 46, 47, 48],
        "sofa": [73, 74, 75, 76, 77, 78, 79, 80],
        "plane": [81, 82, 83, 84, 85, 86, 87, 88],
        "tower": [89, 90, 91, 92, 93, 94, 95, 96],
        "train": [97, 98, 99, 100, 101, 102, 103, 104],
        "xylophone": [105, 106, 107, 108, 109, 110, 111, 112],
    }

    # --- Viewpoint-based grouping (8 rotation angles) ---
    cfg["stimnum"]["viewpoint"] = {
        "left_one": [
            1,
            13,
            21,
            29,
            37,
            41,
            53,
            59,
            69,
            77,
            85,
            93,
            97,
            109,
        ],  # -84°
        "left_two": [
            2,
            14,
            22,
            30,
            38,
            42,
            54,
            60,
            70,
            78,
            86,
            94,
            98,
            110,
        ],  # -60°
        "left_three": [
            3,
            15,
            23,
            31,
            39,
            43,
            55,
            61,
            71,
            79,
            87,
            95,
            99,
            111,
        ],  # -36°
        "left_four": [
            4,
            16,
            24,
            32,
            40,
            44,
            56,
            62,
            72,
            80,
            88,
            96,
            100,
            112,
        ],  # -12°
        "right_one": [
            5,
            9,
            17,
            25,
            33,
            45,
            49,
            63,
            65,
            73,
            81,
            89,
            101,
            105,
        ],  # +12°
        "right_two": [
            6,
            10,
            18,
            26,
            34,
            46,
            50,
            64,
            66,
            74,
            82,
            90,
            102,
            106,
        ],  # +36°
        "right_three": [
            7,
            11,
            19,
            27,
            35,
            47,
            51,
            57,
            67,
            75,
            83,
            91,
            103,
            107,
        ],  # +60°
        "right_four": [
            8,
            12,
            20,
            28,
            36,
            48,
            52,
            58,
            68,
            76,
            84,
            92,
            104,
            108,
        ],  # +84°
    }

    # --- Low-level visual features ---
    # Entropy (image complexity)
    cfg["stimnum"]["entropy"] = {
        "low": (
            list(range(1, 17))
            + list(range(26, 32))
            + list(range(33, 49))
            + list(range(51, 55))
            + [62, 63, 73, 74, 79, 80, 81, 84, 88]
            + list(range(105, 107))
            + list(range(110, 113))
        ),
        "high": (
            list(range(17, 26))
            + [32]
            + list(range(49, 51))
            + list(range(55, 62))
            + list(range(64, 73))
            + list(range(75, 79))
            + [82, 83, 85, 86, 87]
            + list(range(89, 105))
            + list(range(107, 110))
        ),
    }

    # Luminance (brightness)
    cfg["stimnum"]["luminance"] = {
        "low": (
            list(range(2, 8))
            + list(range(17, 20))
            + [25, 32]
            + list(range(41, 45))
            + list(range(46, 51))
            + list(range(55, 73))
            + [81]
            + list(range(88, 105))
            + [108, 109]
        ),
        "high": (
            [1]
            + list(range(8, 17))
            + list(range(20, 25))
            + list(range(26, 32))
            + list(range(33, 41))
            + [45]
            + list(range(51, 55))
            + [62, 63]
            + list(range(73, 88))
            + list(range(105, 108))
            + list(range(110, 113))
        ),
    }

    # ===================================================================
    # DATA PROCESSING CONFIGURATION
    # ===================================================================
    cfg["slice_method"] = (
        "blocks"  # How to organize data: 'trials' or 'blocks'
    )

    # ===================================================================
    # DECODING ANALYSIS CONFIGURATIONS
    # ===================================================================
    cfg["decode_types"] = []

    # --- 1. Category Decoding (Animate vs Inanimate) ---
    cfg["decode_types"].append(
        {
            "name": "category",
            "n_classes": 2,
            "description": "Animate vs Inanimate objects",
            "target_type": "category",  # Which stimnum dict to use
            "chunk_schemes": ["one_block_out", "one_rotation_out"],
            "class_names": ["animate", "inanimate"],
            "chance_level": 0.5,
        }
    )

    # --- 2. Identity Decoding (14 unique objects) ---
    cfg["decode_types"].append(
        {
            "name": "identity",
            "n_classes": 14,
            "description": "14 unique object identities",
            "target_type": "identity",
            "chunk_schemes": ["one_block_out", "one_rotation_out"],
            "class_names": list(cfg["stimnum"]["identity"].keys()),
            "chance_level": 1 / 14,
        }
    )

    # --- 3. Entropy Decoding (High vs Low complexity) ---
    cfg["decode_types"].append(
        {
            "name": "entropy",
            "n_classes": 2,
            "description": "High vs Low image complexity",
            "target_type": "entropy",
            "chunk_schemes": ["one_block_out"],
            "class_names": ["high", "low"],
            "chance_level": 0.5,
        }
    )

    # --- 4. Luminance Decoding (High vs Low brightness) ---
    cfg["decode_types"].append(
        {
            "name": "luminance",
            "n_classes": 2,
            "description": "High vs Low brightness",
            "target_type": "luminance",
            "chunk_schemes": ["one_block_out"],
            "class_names": ["high", "low"],
            "chance_level": 0.5,
        }
    )

    # --- 5. Size Decoding (2-class: Large vs Small) ---
    cfg["decode_types"].append(
        {
            "name": "size_2class",
            "n_classes": 2,
            "description": "Large vs Small size",
            "target_type": "size",
            "size_type": "2class",
            "chunk_schemes": ["one_block_out"],
            "class_names": ["large", "small"],
            "chance_level": 0.5,
        }
    )

    # --- 6. Size Decoding (3-class: Small vs Medium vs Large) ---
    cfg["decode_types"].append(
        {
            "name": "size_3class",
            "n_classes": 3,
            "description": "Small vs Medium vs Large size",
            "target_type": "size",
            "size_type": "3class",
            "chunk_schemes": ["one_block_out"],
            "class_names": ["small", "medium", "large"],
            "chance_level": 1 / 3,
        }
    )

    # --- Optional: Viewpoint Decoding (8 rotation angles) ---
    # Uncomment to enable
    # cfg['decode_types'].append({
    #     'name': 'viewpoint',
    #     'n_classes': 8,
    #     'description': '8 rotation angles',
    #     'target_type': 'viewpoint',
    #     'chunk_schemes': ['one_block_out', 'one_object_out'],
    #     'class_names': list(cfg['stimnum']['viewpoint'].keys()),
    #     'chance_level': 1/8
    # })

    # ===================================================================
    # CLASSIFIER CONFIGURATION
    # ===================================================================
    cfg["classifier"] = "lda"  # Linear Discriminant Analysis
    cfg["scoring"] = "balanced_accuracy"
    cfg["n_jobs"] = -1

    # ===================================================================
    # PARTICIPANT INFORMATION
    # ===================================================================
    notebook_path = cfg["project_path"] / "docs" / "LabNotebook.csv"

    # Try to load LabNotebook, but don't fail if it doesn't exist
    data_table = None
    isgood_data = None
    n_infants = 0

    if notebook_path.is_file():
        try:
            # Import participant data
            data_table = pd.read_csv(notebook_path)

            # Clean up column names: remove newlines, extra spaces, make them Python-friendly
            data_table.columns = (
                data_table.columns.str.replace(
                    "\n", " "
                )  # Replace newlines with spaces
                .str.replace(
                    r"\s+", " ", regex=True
                )  # Multiple spaces to single
                .str.strip()
            )  # Remove leading/trailing spaces

            n_infants = len(data_table)

            print(f"[CONFIG] Loaded LabNotebook with {n_infants} participants")
            print(f"[CONFIG] Cleaned columns: {list(data_table.columns)}")

            # Now check for the blocks column (with cleaned name)
            blocks_col = "Blocks included in the final analysis"

            if blocks_col in data_table.columns:
                # Parse block inclusion info (convert "1,2,3" string to [1, 2, 3] list)
                def parse_blocks(block_str):
                    if pd.isna(block_str) or block_str == "":
                        return []
                    return [
                        int(x.strip())
                        for x in str(block_str).split(",")
                        if x.strip()
                    ]

                isgood_data = (
                    data_table[blocks_col].apply(parse_blocks).tolist()
                )
                print(f"[CONFIG] Using blocks from LabNotebook")
            else:
                # Column doesn't exist - use defaults
                print(f"[CONFIG] Warning: '{blocks_col}' column not found")
                print(
                    f"[CONFIG] Using default: all blocks good for all subjects"
                )
                isgood_data = [
                    [1, 2, 3, 4, 5]
                ] * n_infants  # Assume blocks 1-5 are good

        except Exception as e:
            print(f"[CONFIG] Warning: Could not load LabNotebook: {e}")
            print(f"[CONFIG] Using default participant info")
            data_table = None
            isgood_data = None
            n_infants = 0
    else:
        print(
            f"[CONFIG] Warning: LabNotebook.csv not found at: {notebook_path}"
        )
        print(f"[CONFIG] Using default participant info")

    # If we still don't have data, use sensible defaults
    if n_infants == 0:
        n_infants = 10  # Default number of infant participants
        isgood_data = [[1, 2, 3, 4, 5]] * n_infants

    # Initialize participant groups
    cfg["participants_info"] = []

    # --- GROUP 1: Infant Participants ---
    cfg["participants_info"].append(
        {
            "name": "infants",
            "to_run": True,
            "n_subjects": n_infants,
            "isgood": isgood_data,
            "labnotebook": data_table,
        }
    )

    # --- GROUP 2: Adult Participants ---
    cfg["participants_info"].append(
        {
            "name": "adults",
            "to_run": True,
            "n_subjects": 20,
            "isgood": list(range(1, 51)),  # Valid blocks/trials indicator
            "labnotebook": None,
        }
    )

    # ===================================================================
    # OUTPUT OPTIONS
    # ===================================================================
    cfg["plot_results"] = True
    cfg["savefile"] = True
    cfg["overwrite"] = True

    return cfg


# =======================================================================
# EXAMPLE USAGE
# =======================================================================
if __name__ == "__main__":
    # Generate configuration
    cfg = viewpoint_decoding_config("viewpoint")

    # Display configuration summary
    print(f"\nProject path: {cfg['project_path']}")
    print(f"Total stimuli: {cfg['total_nstimuli']}")
    print(f"\nAvailable decoding types:")
    for decode_type in cfg["decode_types"]:
        print(f"  - {decode_type['name']}: {decode_type['description']}")

    print(f"\nParticipant groups:")
    for group in cfg["participants_info"]:
        print(f"  - {group['name']}: {group['n_subjects']} subjects")

    # Example: Get stimulus numbers for animate category
    animate_stims = cfg["stimnum"]["category"]["animate"]
    print(f"\nAnimate stimuli: {len(animate_stims)} stimuli")
    print(f"First 10: {animate_stims[:10]}")
