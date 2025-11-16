# Study:      Mahdiyeh Khanbagi PhD Experiment I : Viewpoint-tolerant Object Representations in Infants and Adults 
# Created on: 29/07/25
# --------------------------------------------------------------
# Unified Group Configuration Script
# --------------------------------------------------------------
# This script creates a single configuration file (JSON format) 
# that stores all the parameters needed for group-level analyses 
# of both infants and adults.  
#
# What the script does:
# 1. Defines global parameters used in all analyses 
#    (e.g., project paths, stimulus info, decode types).
# 2. Reads group-specific information for each group:
#    - For infants:
#       • Reads the LabNoteBook.csv file 
#       • Determines which subjects are included or excluded
#       • Stores subject counts and indices
#    - For adults:
#       • Stores subject count and folder location
# 3. Combines these into a single `config` list, where each group 
#    (infants/adults) is nested under `config$groups`.
# 4. Saves the unified configuration as a JSON file 
#    (e.g., "group_analysis_config.json") in the project `config/` folder.
#
# Why use a unified config?
# - Allows all group-specific settings to be accessed from a single file.
# - Makes the analysis scripts cleaner and reduces the need for 
#   multiple config files (one for infants and one for adults).
#
# Output:
# - JSON structure with keys:
#     • Global parameters (paths, stimuli IDs, decode types)
#     • `groups$infants`: infant-specific settings
#     • `groups$adults`: adult-specific settings
# --------------------------------------------------------------

library(jsonlite)
HOME <- Sys.getenv("HOME")
project_root <- file.path(HOME, "Documents", "PhD", "Project", "viewpoint")

# Create a container for all groups (infants & adults)
config <- list(
  HOME = HOME,
  project_root = project_root,
  preproc_dir = file.path(project_root, "data", "preprocessed"),
  total_nstimuli = 112,
  anim_ids = c(2, 3, 4, 5, 7, 8, 9),
  inanim_ids = c(1, 6, 10, 11, 12, 13, 14),
  low_entr = c(1:16, 26:31, 33:48, 51:54, 62, 63, 73, 74, 79:81, 84, 88, 105, 106, 110:112),
  high_entr = c(17:25, 32, 49, 50, 55:61, 64:72, 75:78, 82, 83, 85:87, 89:109),
  low_lum = c(2:7, 17:19, 25, 32, 41:44, 46:50, 55:72, 81, 88:104, 108, 109),
  high_lum = c(1, 8:16, 20:24, 26:31, 33:40, 45, 51:54, 62, 63, 73:80, 82:87, 105:107, 110:112),
  decode_type = list(
    list(name = "category", n_classes = 2, decode_method = c("one_block_out", "one_rotation_out")),
    list(name = "identity", n_classes = 14, decode_method = c("one_block_out", "one_rotation_out")),
    list(name = "entropy", n_classes = 2, decode_method = "one_block_out"),
    list(name = "luminance", n_classes = 2, decode_method = "one_block_out"),
    list(name = "size_2class", n_classes = 2, decode_method = "one_block_out"),
    list(name = "size_3class", n_classes = 3, decode_method = "one_block_out")
  ),
  plot_results = 1,
  savefile = 1,
  overwrite = 1
)

# Add group-specific configs
groups <- list()

for (group_label in c("infants", "adults")) {
  if (group_label == "infants") {
    labnotebook <- file.path(project_root, "docs/LabNoteBook.csv")
    dataTable <- read.csv(labnotebook)
    isgood <- dataTable$Includ..or..Exclud.
    
    groups[[group_label]] <- list(
      folder = "infants",
      n_subjects = nrow(dataTable),
      isgood = isgood,
      n_sub_includ = sum(isgood),
      sub_exclud = which(isgood == 0),
      res_color = "#FFA800",
      res_shade = "#FFD479", 
      BF_max = "#FF2600"
    )
  } else {
    groups[[group_label]] <- list(
      folder = "adults",
      n_subjects = 20,
      isgood = c(1:50),
      n_sub_includ = 20,
      sub_exclud = 0, 
      res_color = "#AB0172", 
      res_shade = "#E383BF", 
      BF_max = "#0433FF"
    )
  }
}

# Attach groups into config
config$groups <- groups

# Save unified config file
output_file <- file.path(project_root, "config/group_analysis_config.json")

write_json(config, output_file, pretty = TRUE, auto_unbox = TRUE)
cat("✅ Unified config file created:", output_file, "\n")
