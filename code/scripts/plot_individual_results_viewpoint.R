# ==============================================================================
# Study:      Mahdiyeh Khanbagi PhD Experiment I
#             Viewpoint-tolerant Object Representations in Infants and Adults 
# Pipeline:   Individual Subject Visualization - Decoding Results
# Created:    24/10/25
# Objective:  Standardise Visualisation Across All Decoding Analyses (Group & Individual)
# ==============================================================================

# ENVIRONMENT SETUP ============================================================
rm(list = ls())       # Clear workspace
cat("\014")           # Clear console
gc()                  # Free memory

# LOAD DEPENDENCIES ============================================================
main_dir <- "/Users/22095708/Documents/PhD/Project"
project_name <- "viewpoint"
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
library(zoo)

# CONFIGURATION SETUP ==========================================================

# Load project configuration
config_path <- file.path(main_dir, "shared/config/viewpoint_group_analysis_config.json")
config <- fromJSON(config_path)


# ANALYSIS PARAMETERS ----------------------------------------------------------
# These can be modified to run different analyses

target_group <- 'infants'  # Options: "infants", "adults", or NULL for both
target_subjects <- NULL
target_dim <- NULL # Decode dimensions to analyze
crossval_method <- NULL  # Cross-validation method(s)


# DETERMINE ANALYSIS COMBINATIONS ==============================================
# Determine which groups to run
groups_to_run <- if (is.null(target_group)) c("infants", "adults") else target_group

# Determine which subjects to run 
subjects_to_run <- if(is.null(target_subjects)) config$groups[[groups_to_run]]$samples[["all"]] else target_subjects

# Determine decode types and methods
decode_types <- if (is.null(target_dim)) config$decode_type else target_dim
decode_types <- if (is.data.frame(decode_types)) decode_types$name else decode_types
decode_methods <- if (is.null(crossval_method)) config$decode_type$decode_method else crossval_method
decode_methods <- unique(unlist(decode_methods), use.names = FALSE)

# Create all combinations of decode type and method
combinations <- expand.grid(type = decode_types, 
                            method = decode_methods,
                            stringsAsFactors = FALSE)

# Special cases: certain decode types always use 'one_block_out'
combinations <- combinations %>%
  mutate(method = case_when(
    !type %in% c('category', 'pw_category', 'identity', 'pw_identity') ~ 'one_block_out', 
    TRUE ~ as.character(method)
  )) %>%  
  # Remove any duplicate rows (where all columns are identical)
  distinct()

filenames <- paste(combinations$type, combinations$method, sep = "_")


# MAIN ANALYSIS LOOP ===========================================================

cat("\n=== Plot Individual Decoding Results ===\n")
cat(sprintf("Groups: %s\n", paste(groups_to_run, collapse = ", ")))
cat(sprintf("Total combinations: %d\n\n", nrow(combinations)))

# Iterate through each group
for (group in groups_to_run) {
  
  cat(sprintf("\n--- Processing Group: %s ---\n", toupper(group)))
  
  # Loop through all sample combinations for this group
  for (subjectnr in subjects_to_run) {
    for (i in 1:length(filenames)) {
      subj_res_file <- file.path(config$paths$project_root, "derivatives",
                                 sprintf("%s_sub-%02i_%s.csv", group, subjectnr, filenames[i]))
      
      subj_null_dist <- file.path(config$paths$project_root, "derivatives",
                                  sprintf("%s_sub-%02i_%s_null.csv", group, subjectnr, filenames[i]))
      
      
      # Define Plotting Values ------------------------------------------------
      
      observed <- read.csv(subj_res_file, header= config$groups[[group]]$read_resfile_header)$V1
      window_size <- 10
      smoothed <- rollmean(observed, k = window_size, fill = "extend", align = "center")
      
      if (exists(subj_null_dist)) {
        null <- read.csv(subj_null_dist,  header= config$groups[[group]]$read_resfile_header)
        # Get 95th percentile for each timepoint across shuffles
        corrected_null <- apply(null, 2, function(x) quantile(x, 0.95))
        max_cutoff <-  quantile(corrected_null, 0.95)
        sigidx <- as.integer(observed > max_cutoff)
      } else {
        sigidx <- 0
      }
      timepoints <- seq(-100, 800, length.out = length(observed))
      chance_level = 1/config$decode_type[config$decode_type$name == combinations$type[i], "n_classes"]
      
      
      # Create dataframe for plotting
      plot_data <- data.frame(
        time = seq(-100, 800, length.out = length(observed)),
        observed = observed,
        smoothed = smoothed,
        significant = sigidx
      )
      
      # Find significant timepoints
      sig_data <- if(sum(plot_data$significant) >0 ) plot_data[plot_data$significant == 1, ]
      sig_data$y_pos <- if(!is.null(sig_data)) chance_level * 0.95
      
      
      # CREATE AND SAVE VISUALIZATION ------------------------------------------
      cat("plotting... ")
      
      ##------------------------------ Plot Decoding Accuracy ------------------------------
      # Define shared theme
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
      
      # Get colors from config
      observed_color <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_shade"]
      smooth_color <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_main"]
      
      p <- ggplot(plot_data, aes(x = time)) +
        labs(title = "", x = "", y = "Decoding Accuracy") +
        
        # Shaded time window
        annotate("rect", xmin = 0, xmax = 150, ymin = -Inf, ymax = Inf, 
                 fill = "lightgray", alpha = 0.5) +
        
        # Plot observed and smoothed curves
        geom_line(aes(y = observed), color = observed_color, linewidth = 1) +
        geom_line(aes(y = smoothed), color = smooth_color, linewidth = 1.5) +
        
        # Chance level line
        geom_hline(yintercept = chance_level, color = "#A72F00", linetype = "dashed") +
        
        # Axis formatting
        scale_x_continuous(limits = c(-100, 800), 
                           breaks = seq(-100, 800, 100)) +
        shared_theme  
      
      # Add significant points only if they exist
      if (!is.null(sig_data)) {
        p <- p + geom_point(data = sig_data, aes(x = time, y = y_pos), 
                            shape = 8, color = "#A72F00", size = 2)
      }
      
      ##----------------------- Combo Plot: Accuracy + logBF -----------------------
      
      Cairo(
        file = file.path(config$paths$project_root, "figures/decoding",  
                         sprintf("%s_sub-%02i_%s.png", group, subjectnr, filenames[i])),
        type = "png", width = 8, height = 5, units = "in", dpi = 300
      )
      print(p)
      dev.off()
    }
  }
}

cat("\n=== Analysis Complete ===\n")
cat(sprintf("Output directory: %s\n", file.path(config$paths$project_root, "group")))
