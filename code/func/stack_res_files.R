# Study:      Mahdiyeh Khanbagi PhD Experiment I : Viewpoint-tolerant Object Representations in Infants and Adults 
# Created on: 29/07/25
stack_res_files <- function(config, target_group, ...) {
  # --------------------------
  # 1. Load required packages
  # --------------------------
  library(jsonlite)
  library(dplyr)
  
  # -----------------------------------------------
  # 2. Capture additional arguments (MOVE THIS UP)
  # ----------------------------------------------- 
  args <- list(...)
  # -----------------------------------------------
  # 3. Load the config file and read the settings 
  # -----------------------------------------------
  project_root <- config$paths$project_root
  
  # --------------------------------
  # 4. Decide which groups to run
  # --------------------------------
  groups_to_run <- if (is.null(target_group)) c("infants", "adults") else target_group
  
  for (group in groups_to_run) {
    ##-- LOAD DATA --
    if (group == "infants") {
      read_resfile_header <- FALSE
      res_col <- "V1"
    } else if (group == "adults") {
      read_resfile_header <- TRUE
      res_col <- c("object_decoding")
    } else {
      stop(sprintf("Invalid group: %s. Use 'infants' or 'adults'.", group))
    }
    
    # -----------------------------------------------
    # 5. Process the arguments 
    # ----------------------------------------------- 
    if ("filename" %in% names(args)) {
      # Mode 1: filename provided
      filenames <- args$filename 
      sample <- if ("sample" %in% names(args)) args$sample else "all" 
    } else {
      # Mode 2: other parameters provided
      filenames <- NULL
      sample <- if (!is.null(args$sample)) args$sample else "all"
      types <- if (!is.null(args$types)) args$types else NULL
      methods <- if (!is.null(args$methods)) args$methods else NULL
      versions <- if (!is.null(args$versions)) args$versions else NULL
    }
    
    # Enhanced handling for multiple age groups
    if (length(sample) > 1 && !("all" %in% sample)) {
      # Multiple specific age groups
      subject_list <- c()  # Initialize as empty vector
      
      for (i in 1:length(sample)){
        current_subjects <- config$groups[[group]]$samples[[current_sample[i]]][
          !config$groups[[group]]$samples[[current_sample[i]]] %in% config$groups[[group]]$excluded_subjects
        ]
        subject_list <- sort(c(subject_list, current_subjects))
      }
      
      # Create combined sample name
      nums <- gsub("mo", "", sample)
      sample_name <- paste0(paste(nums, collapse = ","), "mo")
      sample <- sample_name
      
    } else if (sample == "all" || length(sample) == 1) {
        subject_list <- config$groups[[group]]$samples[[current_sample]][
          !config$groups[[group]]$samples[[current_sample]] %in% config$groups[[group]]$excluded_subjects
        ]
    }
    
    excluded_subjects <- config$groups[[group]]$excluded_subjects
    
    # ---------------------------------------------------------------------------------------------------------------------
    # 6. Generate all combinations of decode types & crossval method & analysis versions to reconstruct the input filename 
    # ---------------------------------------------------------------------------------------------------------------------
    if (is.null(filenames)) {
      filenames <- list()
      # Create combinations only from non-null variables
      vars_to_combine <- list()
      if (!is.null(types)) vars_to_combine$types <- types
      if (!is.null(methods)) vars_to_combine$methods <- methods
      if (!is.null(versions)) vars_to_combine$versions <- versions
      
      # Only create combinations if we have at least two variables
      if (length(vars_to_combine) > 1) {
        combinations <- expand.grid(vars_to_combine, stringsAsFactors = FALSE)
        filenames <- apply(combinations, 1, paste, collapse = "_")
      } else {
        filenames <- character(0)  # Empty character vector if no variables provided
      }
    }
    
    # --------------------------------------------
    # 7. Stack files by looping through filenames
    # --------------------------------------------
    
    for (filename in filenames) {
      all_scores <- list()
      for (s in subject_list) {
        if (!(s %in% excluded_subjects)) {
          subjectnr <- sprintf("%02d", s)
          # Build the input filename
          infile <- file.path(
            project_root,
            "derivatives",
            sprintf("%s_sub-%s_%s.csv", group, subjectnr, filename)
          )
          if (file.exists(infile)) {
            data <- read.csv(infile, header = read_resfile_header)
            
            # Store the data with subjectnr as key
            all_scores[[paste0(subjectnr)]] <- data[[res_col]]
          } else {
            warning(sprintf("Result file not found: %s. Skipping...", infile))
            next   # skips to the next iteration of the innermost loop
          }
        }
      }
      # --------------------------
      # 8. Write output CSV
      # --------------------------
      outfile <- file.path(
        project_root,
        "derivatives",
        sprintf("%s_%s_%s(n=%d).csv", group, filename, sample, length(subject_list))
      )
      
      if (!is.null(all_scores) && length(all_scores) > 0){
        write.csv(all_scores, outfile, row.names = FALSE)
        cat(sprintf("✅ Done stacking result files for group '%s': %s\n", group, filename))
      } else {
        warning(sprintf("No - stacked result file - was  generated for: %s. Skipping...", filename))
        next   # skips to the next iteration of the innermost loop
      }
    }
  }
}