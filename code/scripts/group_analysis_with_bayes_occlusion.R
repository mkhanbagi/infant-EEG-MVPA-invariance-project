# ==============================================================================
# Study:      Mahdiyeh Khanbagi PhD Experiment II
#             Occlusion-tolerant Object Representations in Infants and Adults 
# Pipeline:   Group Analysis - Bayes Factor Computation
# Created:    15/07/25
# Objective:  Analyse Group Mean Decoding Outcomes using Bayes Factors
# ==============================================================================

# ENVIRONMENT SETUP ============================================================
rm(list = ls())       # Clear workspace
cat("\014")           # Clear console
gc()                  # Free memory

# LOAD DEPENDENCIES ============================================================
main_dir <- "/Users/22095708/Documents/PhD/Project"
setwd(main_dir)

# Source custom functions
source("./shared/func/stack_res_files.R")

# Load required packages
library(jsonlite)
library(BayesFactor)
library(ggplot2)
library(Cairo)
library(patchwork)
library(dplyr)

# CONFIGURATION SETUP ==========================================================

# ANALYSIS PARAMETERS ----------------------------------------------------------
# These can be modified to run different analyses

target_group <- 'infants'  # Options: "infants", "adults", or NULL for both
target_sample <- NULL     # Options: "all", "6mo", c("6mo", "8mo"), or NULL for 'all' 
target_dim <- NULL # Options: "category", "identity", etc., or NULL for all
analysis_type <- NULL    # Options: 'intact_intact', 'intact_occl', or NULL for all
pw_mode <- NULL #c('face_only', 'nonface_only', 'hetero', 'allpairs') # Options: 'face_only', 'nonface_only', 'hetero', 'allpairs'

# PROJECT SETUP ----------------------------------------------------------------

project_name <- "occlusion"

# Load project-specific configuration 
config_path <- file.path(main_dir, "shared/config", sprintf("%s_group_analysis_config.json", project_name))

if (!file.exists(config_path)) {
  stop("Config file not found: ", config_path)
}

config <- fromJSON(config_path)


# DETERMINE ANALYSIS COMBINATIONS ==============================================

# Determine which groups to analyze
groups_to_run <- if (is.null(target_group)) c("infants", "adults") else target_group

# Handle target_sample = NULL to use predefined combinations from config
if (is.null(target_sample) || target_sample == "all") {
  sample_combinations <- list()
  for (group in groups_to_run) {
    sample_combinations[[group]] <- list("all")
    warning(paste("No predefined sample combinations found for group:", group, ". Using 'all' as fallback."))
  }
} else {
  # Use specified target_sample
  sample_combinations <- list()
  for (group in groups_to_run) {
    sample_combinations[[group]] <- list(target_sample)
  }
}

# Determine decode types
decode_types <- if (is.null(target_dim)) subset(config$decode_type, name != 'pw_identity') else target_dim
decode_types <- if (is.data.frame(decode_types)) decode_types$name else decode_types

# Determine analysis versions (e.g., intact_intact, intact_occl)
analysis_version <- if (is.null(analysis_type)) config$decode_type$versions else analysis_type
analysis_version <- unique(unlist(analysis_version), use.names = FALSE)

# Create all combinations of decode type and analysis version
if (is.null(pw_mode)){
  combinations <- expand.grid(type = decode_types, 
                              version = analysis_version)
} else if (!is.null(pw_mode)){
  combinations <- expand.grid(type = decode_types, 
                              version = analysis_version, 
                              pw_mode = pw_mode)
}

# Apply special rules for different decode types
combinations <- combinations %>%
  mutate(version = case_when(
    type %in% c('occl_pos', 'occl_sfreq') ~ 'occl_only',
    type == 'occl_level' ~ 'all_all',
    TRUE ~ as.character(version)
  )) %>%
  # Filter out invalid combinations
  filter(
    # Remove occl_only version for non-occlusion types
    !(version == 'occl_only' & !type %in% c('occl_pos', 'occl_sfreq'))) %>%
  # For 'occl-level' type, keep only 'intact-intact' version
  filter(
    !(type == 'occl_level' & version != 'all_all')) %>%
  # Remove duplicates
  distinct()

# Create filename identifiers for each combination
if (is.null(pw_mode)){
  filenames <- paste(combinations$type, combinations$version, sep = "_")
} else {
  filenames <- paste('pw', combinations$type, combinations$version, combinations$pw_mode, sep = "_")
}

# MAIN ANALYSIS LOOP ===========================================================

cat("\n=== Starting Bayes Factor Analysis ===\n")
cat("Project:", project_name, "\n")
cat("Groups:", paste(groups_to_run, collapse = ", "), "\n")
cat("Total combinations:", nrow(combinations), "\n\n")


# Iterate through each group
for (group in groups_to_run) {
  cat(sprintf("\n--- Processing Group: %s ---\n", toupper(group)))
  
  # Loop through all sample combinations for this group
  for (current_sample in sample_combinations[[group]]) {
    # Determine sample name for file naming
    
    if (length(current_sample) > 1 && !("all" %in% current_sample)) {
      # Multiple specific age groups - create combined sample name
      nums <- gsub("mo", "", current_sample)
      combined_sample_name <- paste0(paste(nums, collapse = ","), "mo")
      
      # Get total subject count for file naming
      subject_list <- c()
      for (i in 1:length(current_sample)){
        current_subjects <- config$groups[[group]]$samples[[current_sample[i]]][
          !config$groups[[group]]$samples[[current_sample[i]]] %in% config$groups[[group]]$excluded_subjects
        ]
        subject_list <- sort(c(subject_list, current_subjects))
      }
    } else {
      # Single age group or "all"
      if (!(length(current_sample) > 1) || (current_sample == "all")) {
        subject_list <- config$groups[[group]]$samples[[current_sample]][
          !config$groups[[group]]$samples[[current_sample]] %in% config$groups[[group]]$excluded_subjects
        ]
        combined_sample_name <- current_sample
      } 
    }
    
    # Loop through all participant result files and combine decoding scores
    for (i in 1:nrow(combinations)) {
      group_res_file <- file.path(config$paths$project_root, "derivatives",
                                  sprintf("%s_%s_%s(n=%d).csv", group, filenames[i], combined_sample_name, length(subject_list)))
      
      if(!file.exists(group_res_file)){
        # Use the flexible stack_res_files function with original args approach
        stack_res_files(config, group, filename = filenames[i], sample = current_sample)
      }
      
      # Load decoding accuracy data
      all_scores <- read.csv(group_res_file)
      colnames(all_scores) <- sub("^X", "sub-", colnames(all_scores))
      
      # Get analysis parameters
      n_timepoints <- nrow(all_scores)
      
      # Get chance level for this decode type
      if (is.null(pw_mode)){
        chance_level = 1/config$decode_type[config$decode_type$name == combinations$type[i], "n_classes"]
      } else {
        chance_level = 1/2
      }
      
      cat(sprintf("computing (n=%d, t=%d)... ", length(subject_list), n_timepoints))
      
      # COMPUTE GROUP STATISTICS -----------------------------------------------
      sem <- function(x) { sd(x) / sqrt(length(x)) }
      gMeans <- all_scores %>%
        reframe(
          time = seq(-100, 800, length.out = n_timepoints),
          mAcc = rowMeans(all_scores, na.rm = TRUE),
          SEM = apply(all_scores, 1, sem)
        )
      
      # COMPUTE BAYES FACTORS --------------------------------------------------
      # Test H1: accuracy > chance vs H0: accuracy <= chance at each timepoint
      
      BF <- numeric(n_timepoints)
      for (t in 1:n_timepoints) {
        timepoint_data <- as.numeric(all_scores[t, ])
        
        # One-sided t-test: is mean > chance_level?
        bf <- ttestBF(
          x = timepoint_data,
          mu = chance_level,
          nullInterval = c(chance_level, Inf)
        )
        BF[t] <- extractBF(bf)[1, "bf"]
      }
      
      # Add BF results to data frame
      gMeans$BF <- BF
      gMeans$logBF <- log10(BF)
      
      
      # CREATE AND SAVE VISUALIZATION ------------------------------------------
      cat("plotting... ")
      
      shared_theme <- theme_classic() +
        theme(
          plot.title = element_text(
            margin = margin(b = 10), hjust = 0.5
          ), 
          axis.title.x = element_text(
            size = 10, face = "bold", family = "Arial",
            margin = margin(t = 10)  # add space above x-axis title
          ),
          axis.title.y = element_text(
            size = 10, face = "bold", family = "Arial",
            margin = margin(r = 10)  # add space to the right of y-axis title
          ),
          axis.text = element_text(size = 12, face = "bold", family = "Arial"),
          plot.background = element_rect(fill = "white", color = NA), 
        )
      
      #-------------------------- Plot Decoding Accuracy --------------------------
      upper <- gMeans$mAcc + gMeans$SEM
      lower <- gMeans$mAcc - gMeans$SEM
      
      # Get colors from config
      # line_color <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_main"]
      # ribbon_fill <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_shade"]
      # bf_max <- config$decode_type[config$decode_type$name == combinations$type[i], "bf_max"]
      
      # Get colors from config (with special case for pw_identity)
      if (identical(combinations$type[i], "pw_identity") && "pairwise_mode" %in% names(combinations)) {
        mode_i <- combinations$pairwise_mode[i]
        
        # row of pw_identity in config$decode_type
        row_idx <- which(config$decode_type$name == "pw_identity")
        stopifnot(length(row_idx) == 1)
        
        pm <- config$decode_type$pairwise_modes[[row_idx]]  # data.frame or list
        
        if (is.data.frame(pm)) {
          mrow <- pm[pm$mode == mode_i, , drop = FALSE]
          if (nrow(mrow) == 0) mrow <- pm[1, , drop = FALSE]  # fallback
          line_color  <- mrow$acc_main
          ribbon_fill <- mrow$acc_shade
          bf_max      <- mrow$bf_max
        } else if (is.list(pm)) {
          pick <- Filter(function(x) is.list(x) && isTRUE(x$mode == mode_i), pm)
          if (length(pick) == 0L) pick <- pm[1]
          line_color  <- pick[[1]]$acc_main
          ribbon_fill <- pick[[1]]$acc_shade
          bf_max      <- pick[[1]]$bf_max
        } else {
          stop("pairwise_modes must be a data.frame or list in config JSON")
        }
      } else {
        # default: top-level colors for non-pairwise types
        line_color  <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_main"]
        ribbon_fill <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_shade"]
        bf_max      <- config$decode_type[config$decode_type$name == combinations$type[i], "bf_max"]
      }
      
      
      p1 <- ggplot(gMeans, aes(x = time, y = mAcc)) +
        labs(title = "", x = "", y = "Decoding Accuracy") +
        
        # Shaded time window
        annotate("rect", xmin = 0, xmax = 150, ymin = -Inf, ymax = Inf, 
                 fill = "lightgray", alpha = 0.5) +
        
        # SEM ribbon
        geom_ribbon(aes(ymin = lower, ymax = upper), 
                    fill = ribbon_fill) + 
        
        # Mean accuracy line
        geom_line(color = line_color, linewidth = 1) +
        
        # Chance level line
        geom_hline(yintercept = chance_level, 
                   linetype = 11, color = "#A9A9A9", linewidth = 1) +
        shared_theme  
      
      ##-------------------------- Plot Bayes Factors (log10) --------------------------
      # Dynamically determine limits based on data
      logBF_min <- min(gMeans$logBF, na.rm = TRUE)
      logBF_max <- max(gMeans$logBF, na.rm = TRUE)
      
      # Ensure symmetric limits around 0 (optional, for better color balance)
      abs_max <- max(abs(c(logBF_min, logBF_max)))
      scale_limits <- c(-abs_max, abs_max)
      
      # Create a categorical variable for color groups
      gMeans$BF_category <- cut(gMeans$logBF, 
                                breaks = c(-Inf, 0, log10(3), Inf),
                                labels = c("negative", "neutral", "positive"),
                                include.lowest = TRUE)
      
      
      p2 <- ggplot(gMeans, aes(x = time, y = logBF)) +
        geom_segment(aes(xend = time, yend = 0), color = "gray") +
        # Use shape 21 for filled circles with borders
        geom_point(aes(fill = BF_category),  # Use categorical variable
                   shape = 21, 
                   size = 3,
                   color = "gray",
                   stroke = 0.3) +
        scale_fill_manual(values = c("negative" = "darkgray", 
                                     "neutral" = "white", 
                                     "positive" = bf_max)) +
        labs(x = "Time (ms)", y = "Bayes Factor (log10)") +
        shared_theme +
        theme(legend.position = "none")
      
      ##----------------------- Combo Plot: Accuracy + logBF -----------------------
      
      comboPlot <- (p1 / p2) + plot_layout(heights = c(3, 2))
      
      Cairo( 
        file = file.path(config$paths$project_root, "group", sprintf("%s_%s_BFcombo_%s(n=%s).png", group, filenames[i], current_sample, length(subject_list))),
        type = "png", width = 8, height = 6, units = "in", dpi = 300
      )
      print(comboPlot)
      dev.off()
    }
  }
  
  
  cat("\n=== Analysis Complete ===\n")
  cat(sprintf("Output directory: %s\n", 
              file.path(config$project_root, "analysis/group")))
}
