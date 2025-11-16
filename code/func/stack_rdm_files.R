# Study:      Mahdiyeh Khanbagi PhD Experiment I : Viewpoint-tolerant Object Representations in Infants and Adults 
# Created on: 29/07/25
stack_res_files <- function(config, target_group, ...) {
  # --------------------------
  # 1. Load required packages
  # --------------------------
  library(jsonlite)
  library(R.matlab)
  library(hdf5r)
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
      # Single age group or "all"
      if (sample == "all") {
        subject_list <- unlist(config$groups[[group]]$samples, use.names = FALSE)[
          !unlist(config$groups[[group]]$samples, use.names = FALSE) %in% config$groups[[group]]$excluded_subjects
        ]
      } else {
        subject_list <- config$groups[[group]]$samples[[current_sample]][
          !config$groups[[group]]$samples[[current_sample]] %in% config$groups[[group]]$excluded_subjects
        ]
      }
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
      all_rdms<- list()
      for (s in subject_list) {
        if (!(s %in% excluded_subjects)) {
          subjectnr <- sprintf("%02d", s)
          # Build the input filename
          infile <- file.path(
            project_root,
            "derivatives",
            sprintf("%s_sub-%s_%s.mat", group, subjectnr, filename)
          )
          if (file.exists(infile)) {
            all_rdms[[paste0(subjectnr)]] <- readMat(infile)$RDM
          } else {
            warning(sprintf("Result file not found: %s. Skipping...", infile))
            next   # skips to the next iteration of the innermost loop
          }
        }
      }
      # --------------------------
      # 8. Write output as HDF5
      # --------------------------
      if (length(all_rdms) == 0) {
        warning(sprintf("No - stacked result file - was generated for: %s. Skipping...", filename))
        next
      }
      
      # Ensure all entries are 3D arrays with identical dims
      is_arr3 <- vapply(all_rdms, function(x) is.array(x) && length(dim(x)) == 3, logical(1))
      if (!all(is_arr3)) stop("Each all_rdms[[i]] must be a 3D array (e.g., time × items × items).")
      
      dim_keys <- vapply(all_rdms, function(x) paste(dim(x), collapse = "x"), character(1))
      if (length(unique(dim_keys)) != 1)
        stop(sprintf("RDM sizes differ across subjects: %s", paste(unique(dim_keys), collapse = ", ")))
      
      rdm_dim <- dim(all_rdms[[1]])  # c(n_time, n_item, n_item)
      n_time  <- rdm_dim[3]
      n_item  <- rdm_dim[2]
      stopifnot(n_item == rdm_dim[1])  # must be square
      n_subj  <- length(all_rdms)
      
      # Subject IDs from list names, or fall back
      sub_ids <- names(all_rdms)
      if (is.null(sub_ids) || any(!nzchar(sub_ids))) sub_ids <- sprintf("%02d", seq_len(n_subj))
      
      # Stack to 4D: [subject, time, row, col]
      rdm_4d <- array(NA_real_, dim = c(n_subj, n_item, n_item, n_time))
      for (i in seq_len(n_subj)) rdm_4d[i, , , ] <- all_rdms[[i]]
      
      # Build output file name (ensure 'sample' is scalar string)
      sample_str <- if (length(sample) == 1) as.character(sample) else paste(sample, collapse = "+")
      outfile <- file.path(
        project_root, "derivatives",
        sprintf("%s_%s_%s(n=%d).h5", group, filename, sample_str, n_subj)
      )
      
      if (file.exists(outfile)) file.remove(outfile)
      h5 <- hdf5r::H5File$new(outfile, mode = "w")
      on.exit(try(h5$close(), silent = TRUE), add = TRUE)
      
      grp <- h5$create_group("rdm")
      
      # Main 4D dataset
      ds_rdm <- grp$create_dataset(
        name = "stack_4d",
        dims = dim(rdm_4d)
      )
      ds_rdm$write(rdm_4d)
      
      # Labels and metadata
      grp[["subject_ids"]]           <- sub_ids
      grp[["upper_triangle_labels"]] <- ut_labels
      
      grp$attr[["group"]]        <- group
      grp$attr[["filename"]]     <- filename
      grp$attr[["sample"]]       <- sample_str
      grp$attr[["n_subjects"]]   <- n_subj
      grp$attr[["rdm_shape"]]    <- as.integer(rdm_dim)   # (n_time, n_item, n_item)
      grp$attr[["order"]]        <- "stack_4d dims = [subject, time, row, col]"
      grp$attr[["created_with"]] <- "stack_res_files()"
      grp$attr[["created_on"]]   <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
      
      cat(sprintf("✅ Saved stacked 4D RDM and UT vectors to: %s\n", outfile))
    }
  }
}