#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mne_run_all_viewpoint.py
=======================================================================
VIEWPOINT EXPERIMENT - COMPLETE ANALYSIS PIPELINE
=======================================================================
Description: Master script for running preprocessing, decoding, and RDM
             analysis for the viewpoint experiment - using MNE toolbox
Author:   Mahdiyeh Khanbagi
Created:  14/10/2025
Modified: 14/10/2025
=======================================================================
"""
import os
import sys
from pathlib import Path

# Manually set the Project root path
PROJECT_ROOT = Path("/Users/22095708/Documents/PhD/Project")
sys.path.insert(0, str(PROJECT_ROOT))
os.chdir(PROJECT_ROOT)

print(f"Added to Python path: {PROJECT_ROOT}")

import logging
from datetime import datetime
import pandas as pd
import mne

# Import your configuration and pipeline functions
from shared.tools import (
    preprocessing_config,
    viewpoint_decoding_config,
)
from shared.tools import run_preprocess, run_decoding


# =======================================================================
# CONFIGURATION SECTION
# =======================================================================
class PipelineConfig:
    """Central configuration for all analysis tools."""

    def __init__(self):
        # Project settings
        self.project_name = "viewpoint"
        self.project_root = Path.home() / "Documents" / "PhD" / "Project"

        # Pipeline control - Set to True to run, False to skip
        self.tools_to_run = {
            "preprocessing": False,  # Preprocessing with MNE
            "decoding": True,  # Decoding analysis
            "permutation": False,  # Permutation testing
            "rsa": False,  # RDM generation
        }

        # Target group and subject selection
        self.groups_to_run = {"infants": False, "adults": True}

        # Subject selection: list of subject numbers OR empty list for all
        self.subjects_to_run = [1]  # e.g., [1, 2, 3, 4, 5, 6] or [] for all

        # Decoding parameters
        self.decodings_to_run = [
            "category"
        ]  # ['category', 'identity', 'size_2class', 'size_3class']
        self.versions_to_run = {
            "one_rotation_out": True,
            "one_block_out": False,
        }

        # RSA configuration
        self.rdm_config = {
            "target_class": ["category", "identity"],
            "crossval_method": self._get_active_versions(),
            "pw_permutation": False,
            "save_rdm": True,
            "rdm_size": 14,
        }

        # Permutation configuration
        self.permutation_config = {
            "k": 100,
            "save_null": True,
            "plot_results": True,
        }

    def _get_active_versions(self):
        """Get list of active cross-validation versions."""
        return [k for k, v in self.versions_to_run.items() if v]

    def get_active_groups(self):
        """Get list of active participant groups."""
        return [k for k, v in self.groups_to_run.items() if v]

    def get_active_tools(self):
        """Get list of tools to run."""
        return [k for k, v in self.tools_to_run.items() if v]


# =======================================================================
# LOGGING SETUP
# =======================================================================
def setup_logging(config):
    """Initialize logging system for pipeline execution."""
    # Create logs directory
    log_dir = config.project_root / config.project_name / "docs" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    # Create timestamped log file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_dir / f"run_all_{timestamp}.log"

    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler(sys.stdout),
        ],
    )

    logger = logging.getLogger(__name__)
    logger.info("=" * 70)
    logger.info(f"PIPELINE STARTED: {datetime.now()}")
    logger.info(f"Log file: {log_file}")
    logger.info("=" * 70)

    return logger


# =======================================================================
# HELPER FUNCTIONS
# =======================================================================
def load_subject_data(cfg, subjectnr, group_name):
    """Load subject data and behavioral information."""
    # Load MNE epochs
    data_file = (
        cfg["preproc_dir"]
        / group_name
        / f"sub-{subjectnr:02d}"
        / "mne"
        / f"sub-{subjectnr:02d}_mne_epo.fif"
    )

    if not data_file.exists():
        raise FileNotFoundError(f"Dataset not found: {data_file}")

    epochs = mne.read_epochs(str(data_file), preload=True)
    logging.info(f"[DATA] Loaded dataset: {data_file}")

    # Load behavioral file
    behav_file = (
        cfg["rawdata_dir"]
        / group_name
        / f"sub-{subjectnr:02d}"
        / "eeg"
        / f"sub-{subjectnr:02d}_task-targets_events.csv"
    )

    if not behav_file.exists():
        raise FileNotFoundError(f"Behavioral file not found: {behav_file}")

    behav_data = pd.read_csv(behav_file)
    behav_data = behav_data[~behav_data["time_stimon"].isna()]
    logging.info(f"[DATA] Loaded behavioral data: {len(behav_data)} trials")

    return epochs, behav_data


def get_subject_list(cfg, config, group_name):
    """Get list of subjects to process."""
    if config.subjects_to_run:
        return config.subjects_to_run
    else:
        # Get all subjects from the group
        group_info = next(
            (g for g in cfg["participants_info"] if g["name"] == group_name),
            None,
        )
        if group_info:
            return list(range(1, group_info["n_subjects"] + 1))
        else:
            return []


def display_configuration(config, logger):
    """Display analysis configuration summary."""
    logger.info("\n" + "=" * 70)
    logger.info("ANALYSIS CONFIGURATION")
    logger.info("=" * 70)

    # Tools
    active_tools = config.get_active_tools()
    logger.info(f'Tools: {", ".join(active_tools)}')

    # Groups
    active_groups = config.get_active_groups()
    logger.info(f'Groups: {", ".join(active_groups)}')

    # Subjects
    if config.subjects_to_run:
        logger.info(f"Subjects: {config.subjects_to_run}")
    else:
        logger.info("Subjects: All available")

    # Decoding configurations
    if config.tools_to_run["decoding"]:
        logger.info(f'Decoding types: {", ".join(config.decodings_to_run)}')
        logger.info(f'CV methods: {", ".join(config._get_active_versions())}')

    logger.info("=" * 70 + "\n")


# =======================================================================
# PIPELINE EXECUTION FUNCTIONS
# =======================================================================
def run_preprocessing_pipeline(config, logger):
    """Execute preprocessing pipeline for all subjects."""
    logger.info("\n" + "=" * 70)
    logger.info("STARTING PREPROCESSING PIPELINE")
    logger.info("=" * 70)

    # Load preprocessing config
    cfg = preprocessing_config(config.project_name)

    # Filter to active groups only
    active_groups = config.get_active_groups()

    success_count = 0
    fail_count = 0

    for group_name in active_groups:
        logger.info(f"\n[PREPROC] Processing group: {group_name}")

        # Get subject list for this group
        subject_list = get_subject_list(cfg, config, group_name)
        logger.info(f"[PREPROC] Subjects to process: {subject_list}")

        for subjectnr in subject_list:
            logger.info(f"[PREPROC] Processing subject {subjectnr:02d}...")

            try:
                # Call preprocessing function
                run_preprocess(
                    config.project_name,
                    subjectnr,
                    participant_group=group_name,
                    overwrite=1,
                )

                logger.info(f"[PREPROC] ✓ Subject {subjectnr:02d} completed")
                success_count += 1

            except Exception as e:
                logger.error(
                    f"[PREPROC] ✗ Subject {subjectnr:02d} failed: {str(e)}"
                )
                fail_count += 1
                continue

    logger.info(
        f"\n[PREPROC] Preprocessing completed: {success_count} success, {fail_count} failed"
    )


def run_decoding_pipeline(config, logger):
    """Execute decoding pipeline for all subjects."""
    logger.info("\n" + "=" * 70)
    logger.info("STARTING DECODING PIPELINE")
    logger.info("=" * 70)

    # Load config
    cfg = viewpoint_decoding_config(config.project_name)

    active_groups = config.get_active_groups()
    active_versions = config._get_active_versions()

    results = {}
    success_count = 0
    fail_count = 0

    for group_name in active_groups:
        logger.info(f"\n[DECODE] Processing group: {group_name}")

        subject_list = get_subject_list(cfg, config, group_name)

        for subjectnr in subject_list:
            logger.info(
                f"[DECODE] Processing subject {subjectnr:02d}/{len(subject_list)}..."
            )

            try:
                # Run decoding
                results[subjectnr] = run_decoding(
                    config.project_name,
                    subjectnr,
                    participant_group=group_name,
                    decode_types=config.decodings_to_run,
                    cv_schemes=active_versions,
                    overwrite=True,
                )

                logger.info(f"[DECODE] ✓ Subject {subjectnr:02d} completed")
                success_count += 1

            except Exception as e:
                logger.error(
                    f"[DECODE] ✗ Subject {subjectnr:02d} failed: {str(e)}"
                )
                logger.exception(e)  # Print full traceback
                fail_count += 1
                continue

    logger.info(
        f"\n[DECODE] Decoding completed: {success_count} success, {fail_count} failed"
    )
    return results


def run_permutation_pipeline(config, logger):
    """Execute permutation testing pipeline."""
    logger.info("\n" + "=" * 70)
    logger.info("STARTING PERMUTATION TESTING")
    logger.info("=" * 70)

    logger.info(
        f'[PERM] Number of permutations: {config.permutation_config["k"]}'
    )
    logger.info("[PERM] Permutation testing not yet implemented")


def run_rsa_pipeline(config, logger):
    """Execute RSA (Representational Similarity Analysis) pipeline."""
    logger.info("\n" + "=" * 70)
    logger.info("STARTING RSA PIPELINE")
    logger.info("=" * 70)

    cfg = preprocessing_config(config.project_name)
    active_groups = config.get_active_groups()

    pw_results = {}
    rdm_results = {}
    null_distributions = {}

    success_count = 0
    fail_count = 0

    for group_name in active_groups:
        logger.info(f"\n[RSA] Processing group: {group_name}")

        subject_list = get_subject_list(cfg, config, group_name)

        for subjectnr in subject_list:
            logger.info(
                f"[RSA] Processing subject {subjectnr:02d}/{len(subject_list)}..."
            )

            try:
                # Placeholder
                logger.info("[RSA] RDM computation not yet implemented")

                logger.info(f"[RSA] ✓ Subject {subjectnr:02d} completed")
                success_count += 1

            except Exception as e:
                logger.error(
                    f"[RSA] ✗ Subject {subjectnr:02d} failed: {str(e)}"
                )
                fail_count += 1
                continue

    logger.info(
        f"\n[RSA] RSA completed: {success_count} success, {fail_count} failed"
    )

    return pw_results, rdm_results, null_distributions


# =======================================================================
# MAIN EXECUTION
# =======================================================================
def main():
    """Main pipeline execution function."""

    # Initialize configuration
    config = PipelineConfig()

    # Setup logging
    logger = setup_logging(config)

    # Display configuration
    display_configuration(config, logger)

    # Execute tools based on configuration
    try:
        # I. Preprocessing
        if config.tools_to_run["preprocessing"]:
            run_preprocessing_pipeline(config, logger)

        # II. Decoding
        if config.tools_to_run["decoding"]:
            results = run_decoding_pipeline(config, logger)

        # III. Permutation Testing
        if config.tools_to_run["permutation"]:
            run_permutation_pipeline(config, logger)

        # IV. RSA
        if config.tools_to_run["rsa"]:
            pw_results, rdm_results, null_dist = run_rsa_pipeline(
                config, logger
            )

        logger.info("\n" + "=" * 70)
        logger.info("PIPELINE COMPLETED SUCCESSFULLY")
        logger.info(f"Finished at: {datetime.now()}")
        logger.info("=" * 70)

    except Exception as e:
        logger.error(f'\n{"=" * 70}')
        logger.error("PIPELINE FAILED")
        logger.error(f"Error: {str(e)}")
        logger.error(f'{"=" * 70}')
        raise


# =======================================================================
# ENTRY POINT
# =======================================================================
if __name__ == "__main__":
    main()
