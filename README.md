# infant-EEG-MVPA-invariance-project
README.md
markdown# Neural Basis of Invariant Object Representations in Infants

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2024b-orange.svg)](https://www.mathworks.com/products/matlab.html)

MATLAB analysis pipeline for investigating the neural basis of invariant object representations in infant and adult brains using EEG decoding techniques.

**Author:** Mahdiyeh Khanbagi  
**Affiliation:** MARCS Institute for Brain, Behaviour and Development, Western Sydney University, Sydney, Australia  
**Status:** Manuscript in preparation

---

## Overview

This repository contains the complete analysis pipeline for three EEG experiments investigating object recognition and visual invariance in infants and adults:

1. **Viewpoint Experiment** - Object recognition across viewpoint transformations (55 infants, 20 adults)
2. **Occlusion Experiment** - Representation invariance under partial occlusion (30 infants, 5 adults)

### Key Features

- **Complete preprocessing pipeline**: Raw EEG → Filtered → Epoched → Analysis-ready
- **Multivariate pattern analysis (MVPA)**: Time-resolved decoding using CoSMoMVPA
- **Multiple decoding targets**: Category, identity, viewpoint, occlusion properties, size
- **Representational similarity analysis (RSA)**: Pairwise decoding and RDM construction
- **Permutation testing**: Statistical significance with cluster correction
- **Flexible configuration system**: Easy parameter adjustment per experiment
- **BIDS-like organization**: Standardized directory structure

---

## Installation

### Prerequisites

- **MATLAB** R2024b or later
- **EEGLAB** 2025.0 ([download](https://sccn.ucsd.edu/eeglab/download.php))
- **CoSMoMVPA** 2013-2024 ([download](https://www.cosmomvpa.org/download.html))
- **Clean Rawdata** plugin for EEGLAB ([download](https://github.com/sccn/clean_rawdata))

### Setup

1. Clone this repository:
```bash
git clone https://github.com/yourusername/infant-object-eeg.git
cd infant-object-eeg

Add EEGLAB and CoSMoMVPA to your MATLAB path:

matlabaddpath('/path/to/eeglab2025.0');
eeglab; % Initialize EEGLAB
addpath(genpath('/path/to/CoSMoMVPA'));
cosmo_set_path; % Initialize CoSMoMVPA

Add project functions to path:

matlabaddpath(genpath('shared/func'));
addpath(genpath('shared/utilities'));

Project Structure
.
├── viewpoint/              # Viewpoint transformation experiment
│   ├── code/              # Analysis scripts
│   ├── data/              # Raw and preprocessed data
│   │   ├── raw/          # Raw EEG files (BrainVision .xdf, BioSemi .bdf)
│   │   └── preprocessed/ # Filtered, epoched data (EEGLAB, CoSMoMVPA, MNE)
│   ├── derivatives/       # Decoding results (.mat, .csv)
│   ├── figures/           # Result visualizations
│   └── task/              # Stimulus files
│
├── occlusion/             # Occlusion invariance experiment
│   └── [same structure as viewpoint]
│
│
└── shared/                # Shared codebase across experiments
    ├── config/           # Configuration files
    ├── func/             # Core analysis functions
    └── utilities/        # Helper functions and tools

Usage
Quick Start Example
matlab% 1. Set up configuration
cd viewpoint/code
cfg = viewpoint_decoding_config();

% 2. Run preprocessing for one subject
[EEG_epoch, ds] = run_preprocess(5, cfg);

% 3. Run decoding analyses
results = run_decoding_viewpoint(ds, cfg);

% 4. Run group-level analysis
run_group_analysis(cfg);

Typical Workflow

Step 1: Preprocessing
matlab% Load configuration
cfg = preprocessing_config('viewpoint');

% Preprocess single subject
[EEG_epoch, ds] = run_preprocess(subject_number, cfg);

% Or batch process all subjects
for sub = 1:cfg.participants_info.n_subjects
    run_preprocess(sub, cfg);
end

Step 2: Decoding Analysis
matlab% Load preprocessed data
ds = load_cosmo_dataset(subject_number, cfg);

% Run decoding (all analyses in config)
results = run_decoding_viewpoint(ds, cfg);

% Or run specific analysis
results = run_decoding_viewpoint(ds, cfg, ...
    'type', {'category'}, ...
    'version', 'all_all');

Step 3: RSA/Pairwise Decoding
matlab% Run pairwise decoding for RDM construction
[pw_avg, RDM, null] = run_pairwise(ds, cfg);
Configuration Options
Key parameters can be adjusted in config files:
matlab% Preprocessing
cfg.HighPass = 0.1;          % High-pass filter (Hz)
cfg.LowPass = 40;            % Low-pass filter (Hz)
cfg.downsample = 250;        % Target sampling rate (Hz)
cfg.clean_rawdata = true;    % Apply automatic artifact rejection

% Decoding
cfg.classifier = @cosmo_classify_lda;  % Classifier type
cfg.fold_by = 'blocknum';              % Cross-validation scheme

Decoding Analyses
Viewpoint Experiment

Category (animate vs inanimate)
Identity (14-way object classification)
Viewpoint (azimuth angle decoding)
Size (2-class and 3-class)
Entropy (high vs low visual entropy)
Luminance (high vs low brightness)

Occlusion Experiment

Category (face vs non-face)
Identity (4-way: bear, penguin, rocket, tower)
Color (blue vs pink)
Occlusion level (intact vs occluded)
Occluder position (left vs right)
Occluder spatial frequency (high vs low)


Output Files
Preprocessing Outputs

EEGLAB format: data/preprocessed/{group}/sub-XX/eeglab/subXX.set
CoSMoMVPA format: data/preprocessed/{group}/sub-XX/cosmo/sub-XX_cosmomvpa.mat

Decoding Results

MAT files (full results): derivatives/{group}_sub-XX_{analysis}.mat
CSV files (accuracy time series): derivatives/{group}_sub-XX_{analysis}.csv
Figures: figures/decoding/{group}_sub-XX_{analysis}.png

RDM Outputs

RDM matrices: derivatives/{group}_sub-XX_RDM_{analysis}.mat
Pairwise results: derivatives/{group}_sub-XX_pw_{analysis}.csv


Dependencies
Required

MATLAB R2024b or later
EEGLAB 2025.0
CoSMoMVPA (2013-2024)
Signal Processing Toolbox

Optional

Clean Rawdata plugin (for automatic artifact rejection)
Statistics and Machine Learning Toolbox (for advanced analyses)

EEG Systems Supported

BrainVision (.xdf files)
BioSemi (.bdf files)


Citation
If you use this code in your research, please cite:
bibtex@misc{khanbagi2025infant,
  author = {Khanbagi, Mahdiyeh and Quek, Genevieve and Grootswagers, Tijl and Varlet, Manuel and Goetz, Antonia},
  title = {Neural Basis of Invariant Object Representations in Infants},
  year = {2025},
  publisher = {GitHub},
  url = {https://github.com/yourusername/infant-object-eeg}
}
Manuscript in preparation.

Acknowledgments
This research was supported by HDR candidate funding from Western Sydney University.
Collaborators:

Genevieve Quek
Tijl Grootswagers
Manuel Varlet
Antonia Goetz

Software:

EEGLAB: Delorme & Makeig (2004)
CoSMoMVPA: Oosterhof et al. (2016)
Clean Rawdata: Mullen et al. (2015)


License
This project is licensed under the MIT License - see the LICENSE file for details.

Contact
Mahdiyeh Khanbagi
MARCS Institute for Brain, Behaviour and Development
Western Sydney University
Sydney, Australia
For questions or collaboration inquiries, please open an issue on GitHub or contact via email.

Project Status
🚧 Active Development - Manuscript in preparation

✅ Viewpoint experiment: Data collection and analysis complete
✅ Occlusion experiment: Data collection and analysis complete
🔄 Congruence experiment: In progress
📝 Manuscript: In preparation


Last updated: October 2025
