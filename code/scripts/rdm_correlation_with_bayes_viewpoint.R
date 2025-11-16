# ==============================================================================
# Study:      Mahdiyeh Khanbagi PhD Experiment I
#             Viewpoint-tolerant Object Representations in Infants and Adults 
# Pipeline:   Group Analysis - Bayes Factor Computation
# Created:    30/10/25
# Objective:  Compute Bayes Factors for RDM-correlations to Model RDM
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

# CONFIGURATION SETUP ==========================================================

# Load project configuration
config_path <- file.path(main_dir, "shared/config/viewpoint_group_analysis_config.json")
config <- fromJSON(config_path)


# ANALYSIS PARAMETERS ----------------------------------------------------------
# These can be modified to run different analyses

target_group <- c("infants") # Options: "infants", "adults", or NULL for both
target_sample <- c("6mo")  # Options: "all", "6mo", "7mo", etc., or NULL for config defaults
target_dim <- "identity"  # Decode dimensions to analyze
crossval_method <- "one_rotation_out"  # Cross-validation method(s)
corr_metric <- "spearman"


# DETERMINE ANALYSIS COMBINATIONS ==============================================
# Determine which groups to analyze
groups_to_run <- if (is.null(target_group)) c("infants", "adults") else target_group

# Handle target_sample = NULL to use predefined combinations from config
if (is.null(target_sample)) {
  # Use predefined combinations from config
  sample_combinations <- list()
  
  for (group in groups_to_run) {
    if (!is.null(config$default_sample_combinations[[group]])) {
      sample_combinations[[group]] <- config$default_sample_combinations[[group]]
    } else {
      # Fallback: if no predefined combinations, just use "all"
      sample_combinations[[group]] <- list("all")
      warning(paste("No predefined sample combinations found for group:", group, ". Using 'all' as fallback."))
    }
  }
} else {
  # Use specified target_sample
  sample_combinations <- list()
  for (group in groups_to_run) {
    sample_combinations[[group]] <- list(target_sample)
  }
}

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
  mutate(method) %>%  
  # Remove any duplicate rows (where all columns are identical)
  distinct()

filenames <- paste("RDM", combinations$type, combinations$method, sep = "_")


# MAIN ANALYSIS LOOP ===========================================================

cat("\n=== Starting Bayes Factor Analysis ===\n")
cat(sprintf("Groups: %s\n", paste(groups_to_run, collapse = ", ")))
cat(sprintf("Total combinations: %d\n\n", nrow(combinations)))

# Iterate through each group
for (group in groups_to_run) {
  
  cat(sprintf("\n--- Processing Group: %s ---\n", toupper(group)))
  
  # Loop through all sample combinations for this group
  for (current_sample_idx in seq_along(sample_combinations[[group]])) {
    
    # Extract and normalize to a simple character vector (not a list)
    current_sample <- sample_combinations[[group]][[current_sample_idx]]
    current_sample <- as.character(unlist(current_sample, use.names = FALSE))
    
    # Determine sample name for file naming
    if (length(current_sample) > 1 && !("all" %in% current_sample)) {
      # Multiple specific age groups - create combined sample name
      nums <- gsub("mo", "", current_sample)
      combined_sample_name <- paste0(paste(nums, collapse = ","), "mo")
      
      # Get total subject count for file naming
      subject_list <- c()
      for (i in seq_along(current_sample)) {
        grp_samples <- config$groups[[group]]$samples[[ current_sample[i] ]]
        excl       <- config$groups[[group]]$excluded_subjects
        current_subjects <- grp_samples[ !grp_samples %in% excl ]
        subject_list <- sort(c(subject_list, current_subjects))
      }
      
    } else {
      # Single age group or "all"
      if (length(current_sample) == 1 && current_sample == "all") {
        all_samples <- unlist(config$groups[[group]]$samples, use.names = FALSE)
        excl        <- config$groups[[group]]$excluded_subjects
        subject_list <- all_samples[ !all_samples %in% excl ]
        combined_sample_name <- "all"
      } else {
        # single specific age (e.g., "6mo")
        grp_samples <- config$groups[[group]]$samples[[ current_sample[1] ]]
        excl        <- config$groups[[group]]$excluded_subjects
        subject_list <- grp_samples[ !grp_samples %in% excl ]
        combined_sample_name <- current_sample[1]
      }
    }
    
    for (i in 1:nrow(combinations)) {
      group_res_file <- file.path(config$paths$project_root, "derivatives",
                                  sprintf("%s_%s_%s(n=%d).mat", group, filenames[i], combined_sample_name, length(subject_list)))
      
      if(!file.exists(group_res_file)){
        # Use the flexible stack_res_files function with original args approach
        stack_res_files(config, group, filename = filenames[i], sample = current_sample)
      }
      
      all_scores <- read.csv(group_res_file)
      colnames(all_scores) <- sub("^X", "sub-", colnames(all_scores))
      n_timepoints <- nrow(all_scores)
      chance_level = 1/config$decode_type[config$decode_type$name == combinations$type[i], "n_classes"]
      
      
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
      
      cat("computing BFs... ")
      
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
      
      gMeans$BF <- BF
      gMeans$logBF <- log10(BF)
      
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
      upper <- gMeans$mAcc + gMeans$SEM
      lower <- gMeans$mAcc - gMeans$SEM
      
      # Get colors from config
      line_color <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_main"]
      ribbon_fill <- config$decode_type[config$decode_type$name == combinations$type[i], "acc_shade"]
      bf_max <- config$decode_type[config$decode_type$name == combinations$type[i], "bf_max"]
      
      
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
                                breaks = c(-Inf, 0, 1, Inf),
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
        file = file.path(config$paths$project_root, "group",  
                         sprintf("%s_%s_BFcombo_%s(n=%d).png", group, filenames[i], combined_sample_name, length(subject_list))),
        type = "png", width = 8, height = 6, units = "in", dpi = 300
      )
      print(comboPlot)
      dev.off()
    }
  }
}

cat("\n=== Analysis Complete ===\n")
cat(sprintf("Output directory: %s\n", file.path(config$paths$project_root, "group")))