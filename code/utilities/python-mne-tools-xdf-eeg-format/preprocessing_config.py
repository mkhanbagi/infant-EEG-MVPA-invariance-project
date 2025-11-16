#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
preprocessing_config - EEG preprocessing configuration generator

Author: [Mahdiyeh Khanbagi]
Created: [20/07/2025]
Modified: [11/10/2025]

Generates configuration parameters for EEG preprocessing pipeline.
Handles both infant (BrainVision) and adult (Biosemix) participant data.

Usage:
    cfg = preprocessing_config(project_name)

Input:
    project_name - Name of the project folder (string)

Output:
    cfg - Configuration dict containing:
          - Path definitions
          - Filtering parameters
          - Participant information from LabNotebook.csv
          - Output format options


Author: Mahdiyeh Khanbagi
Created on Tue Oct 14 17:55:21 2025
"""

from pathlib import Path
import pandas as pd


def preprocessing_config(project_name):
    """
    Generate EEG preprocessing configuration.

    Parameters
    ----------
    project_name : str
        Name of the project folder

    Returns
    -------
    cfg : dict
        Configuration dictionary with all preprocessing parameters
    """

    cfg = {}

    # ===================================================================
    # PATH CONFIGURATION
    # ===================================================================
    cfg["project_root"] = Path.home() / "Documents" / "PhD" / "Project"
    cfg["project_path"] = cfg["project_root"] / project_name
    cfg["data_dir"] = cfg["project_path"] / "data"
    cfg["rawdata_dir"] = cfg["data_dir"] / "raw"
    cfg["preproc_dir"] = cfg["data_dir"] / "preprocessed"

    # ===================================================================
    # SIGNAL PROCESSING PARAMETERS
    # ===================================================================
    cfg["HighPass"] = 0.1  # High-pass filter cutoff (Hz) - removes slow drifts
    cfg["LowPass"] = (
        100  # Low-pass filter cutoff (Hz) - removes high-freq noise
    )
    cfg["downsample"] = 200  # Target sampling rate (Hz); 0 = no downsampling
    cfg["clean_rawdata"] = 0  # Use EEGLAB Clean Rawdata plugin (0=off, 1=on)

    # ===================================================================
    # PARTICIPANT INFORMATION
    # ===================================================================
    # Load participant metadata from LabNotebook.csv
    notebook_path = cfg["project_path"] / "docs" / "LabNotebook.csv"

    # Initialize participant groups
    cfg["participants_info"] = []

    # --- Infant Group ---
    # Only load LabNotebook if it exists and has the required columns
    if not notebook_path.is_file():
        try:
            # Import participant data
            data_table = pd.read_csv(notebook_path)

            # Select relevant columns
            relevant_cols = [
                "x_ID",  # Participant ID
                "Gender",  # Participant gender
                "DateOfBirth",  # Birth date
                "Age_months_",  # Age in months
                "Age_days_",  # Age in days
                "No_BlocksRecorded",  # Total blocks recorded
                "BlocksIncludedInTheFinalAnalysis",  # Valid blocks (comma-separated)
                "Includ_OrExclud_",  # Inclusion/exclusion status
            ]

            # Check which columns actually exist
            existing_cols = [
                col for col in relevant_cols if col in data_table.columns
            ]

            if existing_cols:
                data_table = data_table[existing_cols]

                # Parse block inclusion info (convert "1,2,3" string to [1, 2, 3] list)
                def parse_blocks(block_str):
                    """Convert comma-separated string to list of integers."""
                    if pd.isna(block_str) or block_str == "":
                        return []
                    return [
                        int(x.strip())
                        for x in str(block_str).split(",")
                        if x.strip()
                    ]

                if "BlocksIncludedInTheFinalAnalysis" in data_table.columns:
                    data_table["BlocksIncludedInTheFinalAnalysis"] = (
                        data_table["BlocksIncludedInTheFinalAnalysis"].apply(
                            parse_blocks
                        )
                    )
                    isgood_infants = data_table[
                        "BlocksIncludedInTheFinalAnalysis"
                    ].tolist()
                else:
                    isgood_infants = []
                cfg["participants_info"].append(
                    {
                        "name": "infants",
                        "eeg_system": "BrainVision",
                        "n_subjects": len(data_table),
                        "isgood": isgood_infants,
                        "labnotebook": data_table,
                    }
                )
            else:
                print(
                    "Warning: LabNotebook.csv exists but doesn't contain expected columns for infants"
                )
        except Exception as e:
            print(f"Warning: Could not load LabNotebook.csv: {e}")

    # --- Adult Group ---
    cfg["participants_info"].append(
        {
            "name": "adults",
            "eeg_system": "Biosemix",
            "n_subjects": 20,
            "isgood": [
                list(range(1, 51)) for _ in range(20)
            ],  # Same blocks for all 20 adults
            "labnotebook": None,
        }
    )

    # ===================================================================
    # OUTPUT OPTIONS
    # ===================================================================
    cfg["setfile"] = 1  # Save EEGLAB .set format (0=no, 1=yes)
    cfg["savemode"] = (
        "onefile"  # Save mode: 'onefile' or 'twofiles' (.set/.fdt)
    )
    cfg["cosmofile"] = 1  # Export to CoSMoMVPA format (0=no, 1=yes)
    cfg["overwrite"] = 0  # Overwrite existing files (0=no, 1=yes)

    return cfg


# Example usage
if __name__ == "__main__":
    # Test the configuration function
    cfg = preprocessing_config("MyProject")
    print(f"Project path: {cfg['project_path']}")
    print(f"Filter: {cfg['HighPass']}-{cfg['LowPass']} Hz")
    print(f"Number of participant groups: {len(cfg['participants_info'])}")
