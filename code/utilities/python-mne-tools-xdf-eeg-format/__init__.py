#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Configuration module for EEG analysis pipeline.

This module contains configuration generators for various analysis stages
including preprocessing, decoding, and other pipeline components.

Author: Mahdiyeh Khanbagi
Created: Tue Oct 14 18:12:30 2025
"""

from .preprocessing import run_preprocess
from .preprocessing_config import preprocessing_config
from .decoding import run_decoding
from .viewpoint_decoding_config import viewpoint_decoding_config


__version__ = "1.0.0"
__author__ = "Mahdiyeh Khanbagi"
__all__ = [
    "preprocessing_config",
    "run_preprocess",
    "viewpoint_decoding_config",
    "run_decoding",
]
