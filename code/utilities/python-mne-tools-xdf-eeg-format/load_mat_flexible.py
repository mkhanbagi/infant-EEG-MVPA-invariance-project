#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MATLAB File Loader - Universal .mat File Reader

This module provides a flexible function to load MATLAB .mat files,
automatically handling both legacy (<v7.3) and modern (v7.3+, HDF5-based) formats.

Author: Mahdiyeh Khanbagi
Created: Mon Oct 27 07:14:29 2025

Dependencies:
    - scipy.io: For loading legacy MATLAB files
    - h5py: For loading HDF5-based MATLAB files (v7.3+)
"""

import scipy.io
import h5py


def load_mat_flexible(file_path):
    """
    Loads a MATLAB .mat file, automatically handling different format versions.

    This function intelligently detects and loads both:
    - Legacy MATLAB formats (< v7.3): Uses scipy.io.loadmat
    - Modern MATLAB formats (v7.3+): Uses h5py for HDF5-based files

    Parameters
    ----------
    file_path : str or pathlib.Path
        Path to the .mat file to be loaded.

    Returns
    -------
    dict
        Dictionary containing the loaded MATLAB variables.
        Keys are variable names from the .mat file.
        Values are the corresponding data (arrays, structs, etc.).

    Raises
    ------
    TypeError
        If the file cannot be loaded as either format or if an
        unexpected error occurs during loading.

    Examples
    --------
    >>> # Load a legacy MATLAB file
    >>> data = load_mat_flexible('legacy_data.mat')
    >>> print(data.keys())

    >>> # Load a modern HDF5-based MATLAB file (v7.3+)
    >>> data = load_mat_flexible('modern_data.mat')
    >>> my_array = data['my_variable']

    Notes
    -----
    - MATLAB v7.3+ files are actually HDF5 files in disguise
    - The function first attempts scipy.io for better compatibility
      with older files, then falls back to h5py for newer formats
    - Nested structures in HDF5 files are recursively loaded
    """

    # ============================================
    # ATTEMPT 1: Try loading as legacy MAT file
    # ============================================
    try:
        # scipy.io.loadmat handles most MATLAB files created before v7.3
        # This is faster and more straightforward for compatible files
        data = scipy.io.loadmat(file_path)
        return data

    except NotImplementedError:
        # NotImplementedError is raised by scipy when it encounters
        # a v7.3 MAT file (which is HDF5-based)
        # We'll handle this format in the next section
        pass

    # ============================================
    # ATTEMPT 2: Try loading as HDF5 (v7.3+)
    # ============================================
    try:
        # Open the file using h5py for HDF5-based MAT files
        with h5py.File(file_path, "r") as f:
            # Initialize empty dictionary to store loaded data
            data = {}

            def recursively_load(h5obj):
                """
                Recursively loads HDF5 objects into Python data structures.

                This nested function handles the hierarchical nature of HDF5,
                converting datasets to arrays and groups to dictionaries.

                Parameters
                ----------
                h5obj : h5py.Dataset or h5py.Group
                    HDF5 object to be loaded.

                Returns
                -------
                numpy.ndarray, dict, or None
                    Converted Python object.
                """
                if isinstance(h5obj, h5py.Dataset):
                    # Dataset: Convert to numpy array
                    return h5obj[()]

                elif isinstance(h5obj, h5py.Group):
                    # Group: Recursively convert to dictionary
                    return {
                        k: recursively_load(h5obj[k]) for k in h5obj.keys()
                    }

                else:
                    # Unknown type: Return None as fallback
                    return None

            # Load all top-level keys from the HDF5 file
            for key in f.keys():
                # Skip MATLAB metadata keys (start with '#')
                if not key.startswith("#"):
                    data[key] = recursively_load(f[key])

            return data

    except Exception as e:
        # If both loading methods fail, raise an informative error
        raise TypeError(
            f"Could not load {file_path}: {e}\n"
            f"File may be corrupted or in an unsupported format."
        )


# ============================================
# Optional: Convenience functions
# ============================================


def get_mat_version(file_path):
    """
    Attempts to determine the MATLAB file version.

    Parameters
    ----------
    file_path : str
        Path to the .mat file.

    Returns
    -------
    str
        'legacy' for <v7.3 files, 'hdf5' for v7.3+ files,
        'unknown' if version cannot be determined.
    """
    try:
        scipy.io.loadmat(file_path)
        return "legacy"
    except NotImplementedError:
        try:
            with h5py.File(file_path, "r"):
                return "hdf5"
        except:
            return "unknown"


# ============================================
# Module testing (only runs when executed directly)
# ============================================

if __name__ == "__main__":
    # Simple test/demo code
    import sys

    if len(sys.argv) > 1:
        # If a file path is provided as command line argument
        file_path = sys.argv[1]
        print(f"Loading: {file_path}")

        try:
            data = load_mat_flexible(file_path)
            print(f"Successfully loaded! Keys found: {list(data.keys())}")

            # Optionally detect version
            version = get_mat_version(file_path)
            print(f"MATLAB file version: {version}")

        except Exception as e:
            print(f"Error: {e}")
    else:
        print("Usage: python load_mat_flexible.py <path_to_mat_file>")
        print("\nThis module is typically imported and used as:")
        print("  from load_mat_flexible import load_mat_flexible")
        print("  data = load_mat_flexible('your_file.mat')")
