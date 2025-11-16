# Study:      Mahdiyeh Khanbagi PhD Experiment II : Occlusion-tolerant Object Representations in Infants and Adults 
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
project_root <- file.path(HOME, "Documents", "PhD", "Project", "occlusion")

# Create a container for all groups (infants & adults)
config <- list(
  HOME = HOME,
  project_root = project_root,
  preproc_dir = file.path(project_root, "data", "preprocessed"),
  total_nstimuli = 64,
  
  stimnum = list(
    category = list(
      face    = as.list(1:32),
      nonface = as.list(33:64)
    ),
    identity = list(
      bear    = as.list(1:16),
      penguin = as.list(17:32),
      rocket  = as.list(33:48),
      tower   = as.list(49:64)
    ),
    color = list(
      blue = as.list(c(1:8,17:24,33:40,49:56)),
      pink = as.list(c(9:16,25:32,41:48,57:64))
    ),
    occl_level = list(
      occluded = as.list(c(1,2,7,8,9,10,15,16,17,18,23,24,25,26,31,32,
                           33,34,39,40,41,42,47,48,49,50,55,56,57,58,63,64)),
      intact   = as.list(c(3,4,5,6,11,12,13,14,19,20,21,22,27,28,29,30,
                           35,36,37,38,43,44,45,46,51,52,53,54,59,60,61,62))
    ),
    occl_pos = list(
      right = as.list(c(1,7,9,15,17,23,25,31,33,39,41,47,49,55,57,63)),
      left  = as.list(c(2,8,10,16,18,24,26,32,34,40,42,48,50,56,58,64))
    ),
    occl_sfreq = list(
      low  = as.list(c(1,2,7,8,9,10,15,16,17,18,23,24,25,26,31,32,
                       33,34,39,40,41,42,47,48,49,50,55,56,57,58,63,64)),
      high = as.list(c(7,8,15,16,23,24,31,32,39,40,47,48,55,56,63,64))
    )
  ),
  
  trigger_map = "docs/triggers_remapped.csv",
  map_key = list(
    occl_level = list(occluded = list(), intact = list()),
    occl_pos   = list(right = list(), left = list()),
    occl_sfreq = list(high = list(), low = list())
  ),
  
  decode_type = list(
    
    # === category ===
    list(
      name = "category",
      n_classes = 2,
      decode_method = "one_block_out",
      versions = list('all_all', 'intact_intact', 'intact_occl')
    ),
    
    # === identity ===
    list(
      name = "identity",
      n_classes = 4,
      decode_method = "one_block_out",
      versions = list('all_all', 'intact_intact', 'intact_occl')
    ),
    
    # === color ===
    list(
      name = "color",
      n_classes = 2,
      decode_method = "one_block_out",
      versions = list('all_all', 'intact_intact', 'intact_occl')
    ),
    
    # === size ===
    list(
      name = "size",
      n_classes = 2,
      decode_method = "one_block_out",
      versions = list('all_all', 'intact_intact', 'intact_occl')
    ),
    
    # === occlusion level ===
    list(
      name = "occl_level",
      n_classes = 2,
      decode_method = "one_block_out",
      versions = list('all_all')
    ),
    
    # === occluder position ===
    list(
      name = "occl_pos",
      n_classes = 2,
      decode_method = "one_block_out",
      versions = "occl_only"
    ),
    
    # === occluder spatial frequency ===
    list(
      name = "occl_sfreq",
      n_classes = 2,
      decode_method = "one_block_out",
      versions = "occl_only"
    )
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
      n_subjects = 0,
      isgood = c(1:15),
      n_sub_includ = 0,
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
