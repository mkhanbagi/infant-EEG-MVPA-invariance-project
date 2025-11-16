# ==============================================================================
# Study:      Mahdiyeh Khanbagi PhD Experiment I
#             Viewpoint-tolerant Object Representations in Infants and Adults 
# Pipeline:   Age Ladder Analysis - Developmental Trajectory
# Created:    24/09/25
# Objective:  Test whether proportion of infants showing significant neural 
#             decoding results increases with age using moving window analysis
# ==============================================================================

# ENVIRONMENT SETUP ============================================================
rm(list = ls())       # Clear workspace
cat("\014")           # Clear console
gc()                  # Free memory

# LOAD DEPENDENCIES ============================================================
main_dir <- "/Users/22095708/Documents/PhD/Project"
project_name <- "viewpoint"
setwd(main_dir)

library(jsonlite)
library(tidyverse)
library(readr)
library(ggplot2)
library(ggrepel)
library(gridExtra)

# CONFIGURATION SETUP ==========================================================

# Load project configuration
config_path <- file.path(main_dir, "shared/config/viewpoint_group_analysis_config.json")
group_config <- fromJSON(config_path)

# Extract infant-specific configuration
# BUG FIX: Changed 'infantsg' to 'infants' on line 30 of original code
infant_config <- list(
  paths = group_config$paths,
  folder = group_config$groups$infants$folder,
  n_subjects = group_config$groups$infants$n_subjects,
  excluded_subjects = group_config$groups$infants$excluded_subjects,
  age_groups = group_config$groups$infants$samples,
  samples = group_config$groups$infants$samples,
  plot_colors = group_config$groups$infants$colors
)

config <- infant_config


# ANALYSIS PARAMETERS ==========================================================
# These can be modified to run different analyses

target_sample <- c("6mo")  # Options: "all", "6mo", "7mo", etc., or c("6mo", "8mo")
window_size <- 14          # Moving window size in days
step_size <- 7             # Step size for window advancement in days

# Define color scheme for plots
colors <- list(
  object = "#57BD7E",
  category = "#337476", 
  ratio = "#962C37",
  fill_obj = "#57BD7E",
  fill_cat = "#337476"
)

# LOAD DATA ====================================================================
# Read the CSV file
age_ladder_table <- file.path(main_dir, project_name, "docs/individual_decoding_binary_rating_3tp.csv")
data <- read_csv(age_ladder_table)
inclusion_status <- data$`inclusion-status`

# Filter for included subjects only
# Determine sample name for file naming
if (length(target_sample) > 1 && !("all" %in% target_sample)) {
  # Multiple specific age groups - create combined sample name
  nums <- gsub("mo", "", target_sample)
  ample_name <- paste0(paste(nums, collapse = ","), "mo")
  
  
  # SELECT SAMPLE ================================================================
  subject_list <- c()
  for (i in 1:length(target_sample)){
    current_subjects <- config$samples[[target_sample[i]]][
      !config$samples[[target_sample[i]]] %in% config$excluded_subjects
    ]
    subject_list <- sort(c(subject_list, current_subjects))
  }
  sample <- data %>% slice(subject_list)
  } else {
    # Single age group or "all"
    if (target_sample == "all") {
      sample <- data %>% filter(inclusion_status == 1)
    } else {
      sample <- data %>% slice(config$samples[[target_sample]])
    }
  }

# Display sample characteristics
cat("\nSample Characteristics:\n")
cat("  N subjects:", nrow(sample), "\n")
cat("  Age range (months):", 
    sprintf("%.2f to %.2f", min(sample$age_months), max(sample$age_months)), "\n")
cat("  Age range (weeks):", 
    sprintf("%.2f to %.2f", min(sample$age_weeks), max(sample$age_weeks)), "\n")
cat("  Age range (days):", 
    sprintf("%.0f to %.0f", min(sample$age_days), max(sample$age_days)), "\n\n")

# MOVING WINDOW ANALYSIS =======================================================

cat("=== Running Moving Window Analysis ===\n")
cat("Window size:", window_size, "days\n")
cat("Step size:", step_size, "days\n")

# Calculate number of analysis windows
age_range_in_days = max(sample$age_days) - min(sample$age_days)
total_nsteps = round(age_range_in_days/step_size)

cat("Age range:", round(age_range_in_days), "days\n")
cat("Total windows:", total_nsteps, "\n\n")

# Initialize results data frame
decoding_ratios <- data.frame(
  n_subj_total = numeric(total_nsteps),
  n_subj_obj = numeric(total_nsteps),
  n_subj_cat = numeric(total_nsteps),
  obj_ratio = numeric(total_nsteps),
  cat_ratio = numeric(total_nsteps),
  cat_obj_ratio = numeric(total_nsteps),
  age_center = numeric(total_nsteps)  # Added to track window centers
)

# Perform moving window analysis
cat("Computing window statistics")

for (step in 1:total_nsteps){
  
  # Progress indicator
  if (step %% 5 == 0) cat(".")
  
  # Define current window center and boundaries
  current_batch_center <- min(sample$age_days) + step_size * step
  # Extract subjects within current window
  current_batch <- sample %>% 
    filter(between(age_days, 
                   current_batch_center - window_size/2,
                   current_batch_center + window_size/2))
  
  # Calculate window statistics
  decoding_ratios$age_center_day[step] <- current_batch_center
  decoding_ratios$age_center_month[step] <- (current_batch_center/30.4)
  decoding_ratios$n_subj_total[step] <- nrow(current_batch)
  decoding_ratios$n_subj_obj[step] <- sum(current_batch$obj_3tp)
  decoding_ratios$n_subj_cat[step] <- sum(current_batch$cat_3tp)
  #decoding_ratios$n_subj_obj[step] <- sum(current_batch$sig_pw_obj_1tp)
  #decoding_ratios$n_subj_cat[step] <- sum(current_batch$sig_category_1tp)
  
  
  # Calculate proportions
  decoding_ratios$obj_ratio[step] <- decoding_ratios$n_subj_obj[step] / decoding_ratios$n_subj_total[step]
  decoding_ratios$cat_ratio[step] <- decoding_ratios$n_subj_cat[step] / decoding_ratios$n_subj_total[step]
  
  # Slice the current sample to calculate the cat/obj ratio
  selected_ind <- current_batch %>% filter(current_batch$obj_3tp == 1)
  #selected_ind <- current_batch %>% filter(current_batch$sig_pw_obj_1tp == 1)
  selected_ind_with_cat <- sum(selected_ind$sig_category_1tp)
  decoding_ratios$cat_obj_ratio[step] <- selected_ind_with_cat/nrow(selected_ind)
}

cat(" Done!\n\n")


# VISUALIZATION ================================================================

cat("=== Creating Visualizations ===\n")
# Set theme for all plots

theme_set(theme_minimal())

# Plot 1: Individual Ratios (Object and Category separately)
p1 <- ggplot(decoding_ratios, aes(x = age_center_month)) +
  geom_ribbon(aes(ymin = 0, ymax = obj_ratio), fill = colors$fill_obj, alpha = 0.2) +
  geom_ribbon(aes(ymin = 0, ymax = cat_ratio), fill = colors$fill_cat, alpha = 0.2) +
  geom_line(aes(y = obj_ratio, color = "Object Decoding"), size = 1.2) +
  geom_line(aes(y = cat_ratio, color = "Category Decoding"), size = 1.2) +
  geom_point(aes(y = obj_ratio), color = colors$object, size = 1.5, alpha = 0.6) +
  geom_point(aes(y = cat_ratio), color = colors$category, size = 1.5, alpha = 0.6) +
  scale_color_manual(values = c("Object Decoding" = colors$object, 
                                "Category Decoding" = colors$category)) +
  labs(
    title = "Proportion of Significant Decoders Across Age",
    subtitle = paste("Window:", window_size, "days, Step:", step_size, "days"),
    x = "Age (months)",
    y = "Proportion of Subjects",
    color = "Decoding Type"
  ) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(size = 12, face = "bold"),
    plot.subtitle = element_text(size = 9),
    axis.title.x = element_text(size = 12, face = "bold", color = "black", margin = margin(t = 15)),
    axis.title.y = element_text(size = 12, face = "bold", color = "black", margin = margin(r = 15)),
    axis.text.x  = element_text(size = 12, face = "bold", color = "gray30", angle = 0, vjust = 0.5),
    axis.text.y  = element_text(size = 12, face = "bold", color = "gray30")
  )

# Plot 2: Category/Object Ratio
# Calculate the exact max value for the ceiling 
max_ratio <- max(decoding_ratios$cat_obj_ratio, na.rm = TRUE)

p2 <- ggplot(decoding_ratios %>% filter(!is.na(cat_obj_ratio)), 
             aes(x = age_center_month, y = cat_obj_ratio)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = colors$ratio, alpha = 0.5) +
  geom_line(color = colors$ratio, size = 1.2) +
  geom_point(color = colors$ratio, size = 2, alpha = 0.7) +
  labs(
    title = "Category/Object Decoding Ratio Across Age",
    subtitle = "Values > 1 indicate more category than object decoding",
    x = "Age (months)",
    y = "Ratio (Category/Object)"
  ) +
  # With 5% padding at the top
  scale_y_continuous(
    breaks = seq(0, ceiling(max_ratio), 0.5),
    limits = c(0, max_ratio * 1.05)  # 5% padding above max
  )+
  theme(
    plot.title = element_text(size = 12, face = "bold"),
    plot.subtitle = element_text(size = 10, face = "italic")
  )

# Plot 3: Raw Counts
p3 <- ggplot(decoding_ratios, aes(x = age_center_month)) +
  geom_area(aes(y = n_subj_total), fill = "grey80", alpha = 0.3) +
  geom_ribbon(aes(ymin = 0, ymax = n_subj_obj), fill = colors$fill_obj, alpha = 0.4) +
  geom_ribbon(aes(ymin = 0, ymax = n_subj_cat), fill = colors$fill_cat, alpha = 0.6) +
  geom_line(aes(y = n_subj_total, color = "Total in Window"), size = 1, linetype = "dotted") +
  geom_line(aes(y = n_subj_obj, color = "Object Decoding"), size = 1.2) +
  geom_line(aes(y = n_subj_cat, color = "Category Decoding"), size = 1.2) +
  scale_color_manual(values = c("Total in Window" = "grey40",
                                "Object Decoding" = colors$object, 
                                "Category Decoding" = colors$category)) +
  labs(
    title = "Number of Significant Decoders Across Age",
    subtitle = paste("Moving window analysis:", window_size, "days window,", step_size, "days step"),
    x = "Age (months)",
    y = "Number of Subjects",
    color = "Count Type"
  ) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(size = 12, face = "bold"),
    plot.subtitle = element_text(size = 10)
  )


# Arrange plots
library(gridExtra)
grid.arrange(p1, p2, p3, ncol = 2, nrow = 2)

# Save individual plots if needed
ggsave(filename = paste0(main_dir, "/", project_name, "/sliding-age-analysis/age_ladder_ratios.png"), 
       plot = p1, width = 8, height = 5, dpi = 300)
ggsave(filename = paste0(main_dir, "/", project_name, "/sliding-age-analysis/age_ladder_ratio.png"), 
       plot = p2, width = 8, height = 5, dpi = 300)
ggsave(filename = paste0(main_dir, "/", project_name, "/sliding-age-analysis/age_ladder_counts.png"), 
       plot = p3, width = 8, height = 5, dpi = 300)

cat("Plots saved to:", "./sliding-age-analysis/", "\n")


# STATISTICAL ANALYSIS =========================================================

# Remove NA values for correlation analysis
valid_data <- decoding_ratios %>% filter(!is.na(cat_obj_ratio))

# Test for age-related trends
cat("\n=== STATISTICAL ANALYSIS ===\n")
cat("Window size:", window_size, "days\n")
cat("Step size:", step_size, "days\n")
cat("Total windows analyzed:", nrow(decoding_ratios), "\n\n")

# Object decoding trend
obj_cor <- cor.test(decoding_ratios$age_center_month, decoding_ratios$obj_ratio)
cat("Object Decoding vs Age:\n")
cat("  Correlation: r =", round(obj_cor$estimate, 3), "\n")
cat("  P-value:", format(obj_cor$p.value, scientific = TRUE), "\n\n")

# Category decoding trend
cat_cor <- cor.test(decoding_ratios$age_center_month, decoding_ratios$cat_ratio)
cat("Category Decoding vs Age:\n")
cat("  Correlation: r =", round(cat_cor$estimate, 3), "\n")
cat("  P-value:", format(cat_cor$p.value, scientific = TRUE), "\n\n")

# Category/Object ratio trend
if(nrow(valid_data) > 2) {
  ratio_cor <- cor.test(valid_data$age_center_month, valid_data$cat_obj_ratio)
  cat("Category/Object Ratio vs Age:\n")
  cat("  Correlation: r =", round(ratio_cor$estimate, 3), "\n")
  cat("  P-value:", format(ratio_cor$p.value, scientific = TRUE), "\n")
  cat("  Windows with ratio > 1:", sum(valid_data$cat_obj_ratio > 1), 
      "(", round(100 * mean(valid_data$cat_obj_ratio > 1), 1), "%)\n\n")
}

# Summary statistics
cat("=== SUMMARY STATISTICS ===\n")
cat("Mean object decoding rate:", round(mean(decoding_ratios$obj_ratio), 3), "\n")
cat("Mean category decoding rate:", round(mean(decoding_ratios$cat_ratio), 3), "\n")
cat("Mean category/object ratio:", round(mean(valid_data$cat_obj_ratio, na.rm = TRUE), 3), "\n")

cat("=== Age Ladder Analysis Complete ===\n")

# CORRELATION WITH NUMBER OF BLOCKS ============================================

cat("\n=== CORRELATION WITH NUMBER OF BLOCKS ===\n\n")

# Point-biserial correlations (for binary outcomes)
# Object identity decoding
obj_blocks_cor <- cor.test(sample$nblocks, sample$obj_3tp)
cat("Identity Decoding vs Number of Blocks:\n")
cat("  Correlation: r =", round(obj_blocks_cor$estimate, 3), "\n")
cat("  P-value:", format(obj_blocks_cor$p.value, scientific = TRUE), "\n\n")

# Category decoding
cat_blocks_cor <- cor.test(sample$nblocks, sample$cat_3tp)
cat("Animacy Decoding vs Number of Blocks:\n")
cat("  Correlation: r =", round(cat_blocks_cor$estimate, 3), "\n")
cat("  P-value:", format(cat_blocks_cor$p.value, scientific = TRUE), "\n\n")

# Summary statistics by decoding status
cat("Mean Number of Blocks:\n")
cat("  Identity Decoders:", round(mean(sample$nblocks[sample$obj_3tp == 1]), 2), 
    "(SD =", round(sd(sample$nblocks[sample$obj_3tp == 1]), 2), ")\n")
cat("  Identity Non-decoders:", round(mean(sample$nblocks[sample$obj_3tp == 0]), 2),
    "(SD =", round(sd(sample$nblocks[sample$obj_3tp == 0]), 2), ")\n")
cat("  Animacy Decoders:", round(mean(sample$nblocks[sample$cat_3tp == 1]), 2),
    "(SD =", round(sd(sample$nblocks[sample$cat_3tp == 1]), 2), ")\n")
cat("  Animacy Non-decoders:", round(mean(sample$nblocks[sample$cat_3tp == 0]), 2),
    "(SD =", round(sd(sample$nblocks[sample$cat_3tp == 0]), 2), ")\n\n")

# VISUALIZATION - BLOCKS CORRELATION ===========================================

cat("=== Creating Correlation Visualizations ===\n")

# Create a summary by number of blocks
blocks_prop_summary <- sample %>%
  group_by(nblocks) %>%
  summarise(
    n_total = n(),
    n_obj = sum(obj_3tp),
    n_cat = sum(cat_3tp),
    prop_obj = n_obj / n_total,
    prop_cat = n_cat / n_total,
    .groups = 'drop'
  )

# Plot 2: Individual subjects with subject-colored dots
# Example for non-numeric IDs
sample$pair_id <- rep(1:(length(unique(sample$subjectnr)) / 2), each = 2)[as.numeric(factor(sample$subjectnr))]
p_blocks_indiv <- ggplot(sample) +
  # --- Identity decoding points ---
  geom_jitter(
    aes(x = nblocks, y = obj_3tp, color = factor(pair_id)),
    height = 0.03, width = 0.1, alpha = 0.7, size = 2.5
  ) +
  # --- Animacy decoding points ---
  geom_jitter(
    aes(x = nblocks, y = cat_3tp - 0.05, color = factor(pair_id)),
    height = 0.03, width = 0.1, alpha = 0.7, size = 2.5
  ) +
  # --- Subject labels ---
  geom_text_repel(
    aes(x = nblocks, y = obj_3tp, label = subjectnr, color = factor(pair_id)),
    size = 3,
    max.overlaps = Inf,
    box.padding = 0.6,
    point.padding = 0.4,
    segment.color = "gray60",
    segment.size = 0.3,
    force = 2,
    nudge_y = 0.1
  ) +
  # --- Subject labels ---
  geom_text_repel(
    aes(x = nblocks, y = cat_3tp, label = subjectnr, color = factor(pair_id)),
    size = 3,
    max.overlaps = Inf,
    box.padding = 0.6,
    point.padding = 0.4,
    segment.color = "gray60",
    segment.size = 0.3,
    force = 2,
    nudge_y = 0.1
  ) +
  # --- Smoothed lines (keep fixed colors) ---
  geom_smooth(
    aes(x = nblocks, y = obj_3tp, linetype = "Identity Decoding"),
    method = "lm", se = TRUE,
    color = colors$object, fill = colors$fill_obj, alpha = 0.2,
    linewidth = 1.2
  ) +
  geom_smooth(
    aes(x = nblocks, y = cat_3tp, linetype = "Animacy Decoding"),
    method = "lm", se = TRUE,
    color = colors$category, fill = colors$fill_cat, alpha = 0.2,
    linewidth = 1.2
  ) +
  scale_color_manual(
    name = "Subject Pair",
    values = viridis::viridis(length(unique(sample$pair_id)))
  ) +
  scale_linetype_manual(
    name = "Decoding Type",
    values = c("Identity Decoding" = "solid", "Animacy Decoding" = "solid")
  ) +
  scale_y_continuous(breaks = c(0, 1), labels = c("No", "Yes")) +
  labs(
    title = "Individual Decoding Success by Number of Blocks",
    subtitle = paste0(
      "Identity: r = ", round(obj_blocks_cor$estimate, 3),
      ", p ", ifelse(obj_blocks_cor$p.value < 0.001, "< 0.001", 
                     paste0("= ", round(obj_blocks_cor$p.value, 3))),
      " | Animacy: r = ", round(cat_blocks_cor$estimate, 3),
      ", p ", ifelse(cat_blocks_cor$p.value < 0.001, "< 0.001", 
                     paste0("= ", round(cat_blocks_cor$p.value, 3)))
    ),
    x = "Number of Blocks",
    y = "Significant Decoding"
  ) +
  guides(color = "none") +
  theme(
    legend.position = "bottom",
    plot.title = element_text(size = 12, face = "bold", margin = margin(t = 30)),
    plot.subtitle = element_text(size = 9, margin = margin(t = 15, b = 30)),
    axis.title.x = element_text(size = 12, face = "bold", color = "black", margin = margin(t = 15)),
    axis.title.y = element_text(size = 12, face = "bold", color = "black", margin = margin(r = 20)),
    axis.text.x  = element_text(size = 12, face = "bold", color = "gray30"),
    axis.text.y  = element_text(size = 12, face = "bold", color = "gray30")
  )

p_blocks_indiv

ggsave(filename = paste0(main_dir, "/", project_name, 
                         "/sliding-age-analysis/blocks_correlation_individual.png"), 
       plot = p_blocks_indiv, width = 8, height = 7, dpi = 300)

