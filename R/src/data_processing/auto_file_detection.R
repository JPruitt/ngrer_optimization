# R/data_processing/auto_file_detection.R

# Automatic File Detection and Inventory System for NGRER Data Sources
# 
# Purpose: Automatically detect and catalog all available input files across 
#          data sources without requiring user date input
#
# Author: Joe pruitt & The NGRER Development Team
# Last Modified: 2025-12-19

#' Automatically detect all available input files across NGRER data sources
#'
#' This function scans the input directory structure and creates a comprehensive
#' inventory of all available data files, extracting dates and metadata where possible
#'
#' @param base_input_path Character string of base input directory path
#' @param config_file Path to NGRER configuration file
#' @return List containing file inventory and processing recommendations
#' 
#' @examples
#' file_inventory <- detect_all_input_files("data/input")

# --- 1. Load Libraries ---
library(dplyr); library(stringr); library(logger); library(readxl); library(jsonlite); library(lubridate);

# --- 2. Main Detection Function ---
#' @export
detect_all_input_files <- function(base_input_path = "../data/inputs/current", 
                                   log_dir = "../logs/audit") {
  
  log_info("Starting automatic file detection in: {base_input_path}")
  
  # --- ROBUST, FLEXIBLE FILE PATTERNS ---
  file_patterns <- list(
    sacs = list(equipment = "cla_eqpdet_roll", header = "cla_header_roll"),
    ldac = list(inventory = "AE2S_LIN_DATA_G8_NIIN_File"),
    lmdb = list(master = "LINS_ACTIVE"),
    fdiis = list(procurement = "AE2S_CURRENT_POSITION"),
    darpl = list(priorities = "CUI_.*DARPL"),
    substitutions = list(sb_700_20_h = "SB_700_20_APPENDIX_H", sb_700_20_chapters = "SB_700_20_CHAPTERS"),
    transfers = list(lmi_dst = "LMI_DST_PSDs")
  )
  
  file_inventory <- list()
  
  # --- Scan and Process ---
  for (source_name in names(file_patterns)) {
    source_path <- file.path(base_input_path, source_name)
    if (!dir.exists(source_path)) { log_warn("Source directory does not exist: {source_path}"); next }
    
    all_files <- list.files(source_path, full.names = TRUE, recursive = FALSE)
    if (length(all_files) == 0) { log_warn("No files found in {source_name} directory"); next }
    
    for (file_type in names(file_patterns[[source_name]])) {
      pattern <- file_patterns[[source_name]][[file_type]]
      # The new regex is case-insensitive and handles spaces, underscores, or hyphens
      matching_files <- all_files[grepl(pattern, basename(all_files), ignore.case = TRUE)]
      
      if (length(matching_files) > 0) {
        file_inventory[[source_name]][[file_type]] <- process_matching_files(matching_files, source_name, file_type)
      } else {
        log_warn("No {file_type} files found matching pattern: {pattern}")
      }
    }
  }
    
  # Generate processing summary and recommendations
  processing_summary <- generate_processing_summary(file_inventory)
  
  # --- Generate and Save Audit Log ---
  audit_entry <- create_file_detection_audit(file_inventory, base_input_path)
  
  # Save audit information
  save_audit_information(audit_entry)
  
  return(list(
    file_inventory = file_inventory,
    processing_summary = processing_summary,
    audit_entry = audit_entry,
    detection_timestamp = Sys.time()
  ))
}

# --- 3. HELPER FUNCTIONS (with enhanced validation) ---
#' Process matching files and extract metadata
#'
#' @param matching_files Vector of file paths that match the pattern
#' @param source_name Source category name (sacs, ldac, etc.)
#' @param file_type File type within source (equipment, header, etc.)
#' @return Data frame with file metadata
#' 
process_matching_files <- function(matching_files, source_name, file_type) { # Corrected to accept file_type
  
  file_metadata <- data.frame()
  
  for (file_path in matching_files) {
    
    file_info <- file.info(file_path)
    file_name <- basename(file_path)
    
    extracted_date <- extract_date_from_filename(file_name) # No longer needs source/type
    file_format <- determine_file_format(file_path)
    validation_result <- validate_file_accessibility(file_path, source_name) # Pass source_name
    
    metadata_row <- data.frame(
      source = source_name,
      file_type = file_type,
      file_name = file_name,
      full_path = file_path,
      file_size_mb = round(file_info$size / (1024^2), 2),
      file_format = file_format,
      last_modified = file_info$mtime,
      extracted_date = extracted_date,
      date_format = determine_date_format(extracted_date),
      validation_status = validation_result$status,
      validation_message = validation_result$message,
      processing_priority = determine_processing_priority(extracted_date, file_info$mtime),
      stringsAsFactors = FALSE
    )
    
    file_metadata <- rbind(file_metadata, metadata_row)
  }
  
  file_metadata <- file_metadata %>%
    arrange(desc(extracted_date), desc(last_modified), processing_priority)
  
  return(file_metadata)
}

#' Extract date information from filename using various patterns
#'
#' @param filename Name of the file
#' @return Date object or NA if no date found
#' 
extract_date_from_filename <- function(filename) {
  
  # Use the more robust mdy, ymd functions from lubridate which can handle multiple formats
  
  # Pattern 1: YYYYMMDD (e.g., "20250811")
  if (grepl("[0-9]{8}", filename)) {
    date_str <- str_extract(filename, "[0-9]{8}")
    parsed_date <- ymd(date_str, quiet = TRUE)
    if (!is.na(parsed_date)) return(parsed_date)
  }
  
  # Pattern 2: YYYY-MM-DD (e.g., "2025-08-11")
  if (grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", filename)) {
    date_str <- str_extract(filename, "[0-9]{4}-[0-9]{2}-[0-9]{2}")
    parsed_date <- ymd(date_str, quiet = TRUE)
    if (!is.na(parsed_date)) return(parsed_date)
  }
  
  # Pattern 3: MM-DD-YY (e.g., "8-7-25")
  if (grepl("[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}", filename)) {
    date_str <- str_extract(filename, "[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}")
    parsed_date <- mdy(date_str, quiet = TRUE)
    if (!is.na(parsed_date)) return(parsed_date)
  }
  
  # If no patterns match, return NA
  return(as.Date(NA))
}

#' Determine file format based on file extension and structure
#'
#' @param file_path Path to the file
#' @return Character string describing file format
#' 
determine_file_format <- function(file_path) {
  
  file_extension <- tools::file_ext(file_path)
  
  format_map <- list(
    "txt" = "TAB_DELIMITED",
    "csv" = "COMMA_SEPARATED", 
    "xlsx" = "EXCEL_WORKBOOK",
    "xls" = "EXCEL_LEGACY"
  )
  
  detected_format <- format_map[[tolower(file_extension)]]
  
  if (is.null(detected_format)) {
    detected_format <- "UNKNOWN"
  }
  
  return(detected_format)
}

#' Validate file accessibility and basic structure
#'
#' @param file_path Path to the file
#' @param source_name Source category name
#' @param file_type File type within source  
#' @return List with status and message
#' 
validate_file_accessibility <- function(file_path, source_name, file_type) {
  tryCatch({
    if (!file.exists(file_path)) {
      return(list(status = "ERROR", message = "File does not exist"))
    }
    if (!file.access(file_path, mode = 4) == 0) {
      return(list(status = "ERROR", message = "File is not readable"))
    }
    if (file.size(file_path) == 0) {
      return(list(status = "WARNING", message = "File is empty"))
    }
    
    # Correctly capture and check the result of the format validation
    format_validation <- validate_file_format_structure(file_path, determine_file_format(file_path), source_name)
    if (!format_validation$valid) {
      return(list(status = "INVALID", message = format_validation$message))
    }
    
    return(list(status = "VALID", message = "File passed all validation checks"))
    
  }, error = function(e) {
    return(list(status = "ERROR", message = paste("Accessibility validation error:", e$message)))
  })
}


#' Validate file format structure by attempting to read sample data
#'
#' @param file_path Path to the file
#' @param file_format Detected file format
#' @param source_name Source category name for context
#' @return List with validation result
#' 
# --- ENHANCED, SOURCE-SPECIFIC VALIDATION ---
validate_file_format_structure <- function(file_path, file_format, source_name) {
  tryCatch({
    if (source_name == "sacs") {
      # Use a tryCatch to see if reading works at all
      tryCatch({
        sample_data <- read_tsv(file_path, n_max = 5, col_names = FALSE, show_col_types = FALSE, progress = FALSE)
        if(ncol(sample_data) < 8) return(list(valid=F, message="Incorrect column count for SACS file"))
      }, error = function(e) {
        return(list(valid = FALSE, message = "Failed to parse as TSV."))
      })
    } else if (source_name == "ldac") {
      sheet_names <- excel_sheets(file_path)
      if(!all(c("Sheet 1", "Sheet 2", "Sheet 3") %in% sheet_names)) return(list(valid=F, message="Missing required LDAC sheets"))
    } else if (source_name == "lmdb") {
      sheet_names <- excel_sheets(file_path)
      if(!any(toupper(sheet_names) == "LINS_ACTIVE")) return(list(valid=F, message="Missing required LMDB sheet 'LINS_ACTIVE'"))
    }
    # If it passes all specific checks, it's valid
    return(list(valid = TRUE, message = "File format validation passed"))
    
  }, error = function(e) {
    # This outer tryCatch catches errors like a corrupt Excel file
    return(list(valid = FALSE, message = paste("File read error:", e$message)))
  })
}

# Processing priority determination
determine_processing_priority <- function(extracted_date, last_modified) {
  
  if (is.na(extracted_date)) {
    return(99)  # Lowest priority for files without dates
  }
  
  # Calculate days since file creation/modification
  days_old <- as.numeric(Sys.Date() - as.Date(last_modified))
  
  # Priority scoring (lower number = higher priority)
  if (days_old <= 7) {
    return(1)    # High priority - recent files
  } else if (days_old <= 30) {
    return(2)    # Medium priority 
  } else if (days_old <= 90) {
    return(3)    # Lower priority
  } else {
    return(4)    # Lowest priority - very old files
  }
}

# Date format determination
determine_date_format <- function(extracted_date) {
  if (is.na(extracted_date)) {
    return("UNKNOWN")
  }
  
  date_string <- as.character(extracted_date)
  
  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", date_string)) {
    return("YYYY-MM-DD")
  } else if (grepl("^[0-9]{2}/[0-9]{2}/[0-9]{4}$", date_string)) {
    return("MM/DD/YYYY")
  } else {
    return("DETECTED")
  }
}

#' Generate processing summary
generate_processing_summary <- function(file_inventory) {
  
  # Flatten the complex list into a simple list of data frames
  all_file_dfs <- unlist(file_inventory, recursive = FALSE)
  
  # Bind all the data frames together into one master inventory table
  if (length(all_file_dfs) > 0) {
    master_inventory <- bind_rows(all_file_dfs)
    
    total_files <- nrow(master_inventory)
    valid_files <- sum(master_inventory$validation_status == "VALID")
    sources_found <- n_distinct(master_inventory$source)
  } else {
    total_files <- 0
    valid_files <- 0
    sources_found <- 0
  }
  
  summary <- list(
    total_data_sources = 7, # This is a fixed number based on our design
    sources_with_files = sources_found,
    total_files_found = total_files,
    valid_files_found = valid_files,
    validation_pass_rate = ifelse(total_files > 0, valid_files / total_files, 0),
    processing_recommendation = ifelse(valid_files >= 9, # We expect 9 files
                                       "PROCEED_WITH_PROCESSING", 
                                       "REVIEW_DATA_QUALITY_ISSUES")
  )
  
  return(summary)
}

# Create audit entry for file detection
create_file_detection_audit <- function(file_inventory, base_input_path) {
  
  audit_entry <- list(
    audit_timestamp = Sys.time(),
    audit_id = generate_audit_id(),
    base_path = base_input_path,
    detection_summary = generate_processing_summary(file_inventory),
    file_details = file_inventory,
    system_info = list(
      r_version = R.version.string,
      platform = Sys.info()["sysname"],
      user = Sys.info()["user"],
      working_directory = getwd()
    )
  )
  
  return(audit_entry)
}

# Save audit information
save_audit_information <- function(audit_entry) {
  
  audit_dir <- "logs/audit"
  if (!dir.exists(audit_dir)) {
    dir.create(audit_dir, recursive = TRUE)
  }
  
  audit_filename <- paste0("file_detection_audit_", 
                          format(audit_entry$audit_timestamp, "%Y%m%d_%H%M%S"), 
                          ".json")
  
  audit_filepath <- file.path(audit_dir, audit_filename)
  
  # Convert to JSON for audit trail
  jsonlite::write_json(audit_entry, audit_filepath, pretty = TRUE)
  
  log_info("Audit information saved to: {audit_filepath}")
  
  return(audit_filepath)
}

# Generate unique audit ID
generate_audit_id <- function() {
  paste0("NGRER_AUDIT_", 
         format(Sys.time(), "%Y%m%d_%H%M%S"), 
         "_", 
         sample(1000:9999, 1))
}