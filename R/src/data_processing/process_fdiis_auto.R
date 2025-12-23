# R/src/data_processing/process_fdiis_auto.R
# FDIIS Procurement Data Processing with Enhanced Auditing
#
# Author: NGRER Development Team
# Last Modified: 2025-12-17 (Corrected LIN column name in integration step)

library(dplyr)
library(readr)
library(stringr)
library(logger)
library(readxl)
library(jsonlite)

log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

# --- HELPER FUNCTIONS ---

#' Integrate FDIIS data with existing data sources - CORRECTED
integrate_fdiis_with_existing_data <- function(fdiis_data, sacs_data, ldac_data, lmdb_data) {
  log_info("Auditing for new LINs not present in SACS/LDAC/LMDB...")
  
  # CORRECTED: Use the standardized 'LIN_CLEAN' column from dependency data
  previous_lins <- c()
  if (!is.null(sacs_data) && "LIN_CLEAN" %in% names(sacs_data)) previous_lins <- c(previous_lins, unique(sacs_data$LIN_CLEAN))
  if (!is.null(ldac_data) && "LIN_CLEAN" %in% names(ldac_data)) previous_lins <- c(previous_lins, unique(ldac_data$LIN_CLEAN))
  if (!is.null(lmdb_data) && "lin" %in% names(lmdb_data)) previous_lins <- c(previous_lins, unique(lmdb_data$lin))
  previous_lins <- unique(previous_lins)
  
  fdiis_lins <- unique(c(fdiis_data$LIN_IN_CLEAN, fdiis_data$LIN_OUT_CLEAN))
  fdiis_lins <- fdiis_lins[!is.na(fdiis_lins) & fdiis_lins != ""]
  
  new_lins_found <- setdiff(fdiis_lins, previous_lins)
  
  return(list(
    fdiis_data = fdiis_data,
    new_lins_found = new_lins_found
  ))
}

#' Analyze procurement patterns and constraints
analyze_procurement_patterns <- function(fdiis_cleaned) {
  log_info("Auditing unique LINs by categorical pairs...")
  
  ba_summary <- fdiis_cleaned %>%
    filter(!is.na(BA) & BA != "") %>%
    group_by(BA, BA_DESC) %>%
    summarise(unique_lin_count = n_distinct(LIN_OUT_CLEAN, na.rm = TRUE), .groups = "drop")
  
  pid_summary <- fdiis_cleaned %>%
    filter(!is.na(OSDPE_PID) & OSDPE_PID != "") %>%
    group_by(OSDPE_PID, OSDPE_PID_DESC) %>%
    summarise(unique_lin_count = n_distinct(LIN_OUT_CLEAN, na.rm = TRUE), .groups = "drop")
  
  group_summary <- fdiis_cleaned %>%
    filter(!is.na(OSDPE_PID_GROUP) & OSDPE_PID_GROUP != "") %>%
    group_by(OSDPE_PID_GROUP, OSD_PID_GROUP_DESC) %>%
    summarise(unique_lin_count = n_distinct(LIN_OUT_CLEAN, na.rm = TRUE), .groups = "drop")
  
  return(list(
    by_ba = ba_summary,
    by_pid = pid_summary,
    by_pid_group = group_summary
  ))
}


# --- MAIN FUNCTION ---

#' Main FDIIS processing function with detailed validation and auditing.
#' @export
process_fdiis_auto <- function(fdiis_directory = "../data/inputs/current/fdiis",
                               sacs_data = NULL, ldac_data = NULL, lmdb_data = NULL,
                               output_dir = "../data/intermediate/r_processing/fdiis",
                               audit_log_dir = "../logs/audit/data_lineage") {
  
  audit_log <- list()
  audit_log$start_time <- Sys.time()
  
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (!dir.exists(audit_log_dir)) dir.create(audit_log_dir, recursive = TRUE)
  
  # 1. Read Raw Data
  fdiis_file <- list.files(fdiis_directory, pattern = "AE2S_CURRENT_POSITION.*\\.xlsx$", full.names = TRUE)[1]
  log_info("Reading raw FDIIS data from: {basename(fdiis_file)}")
  sheet_name <- "AE2S_CURRENT_POSITION"
  fdiis_raw <- read_excel(fdiis_file, sheet = sheet_name, col_types = "text")
  audit_log$input_file <- list(filename = basename(fdiis_file), total_rows_read = nrow(fdiis_raw))
  
  # 2. Standardize, Clean, and Select
  log_info("Standardizing columns and cleaning data...")
  required_cols <- c("POSITION", "PORTFOLIO", "APPN", "FUND_CAT", "COMPO", "LIN_IN", "LIN_OUT", 
                     "PROCUREMENT_TYPE", "FY", "AMOUNT", "PARENT_SSN", "BA", "BA_DESC", 
                     "OSDPE_PID", "OSDPE_PID_DESC", "OSDPE_PID_GROUP", "OSD_PID_GROUP_DESC")
  fdiis_selected <- fdiis_raw %>% select(any_of(required_cols))
  
  fdiis_cleaned <- fdiis_selected %>%
    mutate(
      FY_NUM = as.numeric(FY),
      AMOUNT_NUM = as.numeric(gsub("[$,]", "", AMOUNT)),
      LIN_IN_CLEAN = str_trim(str_to_upper(LIN_IN)),
      LIN_OUT_CLEAN = str_trim(str_to_upper(LIN_OUT)),
      PARENT_SSN_CLEAN = str_trim(str_to_upper(PARENT_SSN))
    ) %>%
    filter(!is.na(FY_NUM) & !is.na(AMOUNT_NUM))
  
  # 3. New LINs Identification
  integration_results <- integrate_fdiis_with_existing_data(fdiis_cleaned, sacs_data, ldac_data, lmdb_data)
  new_lins_found <- integration_results$new_lins_found
  
  audit_log$new_lin_audit <- list(
    new_lins_count = length(new_lins_found),
    new_lins_list_filename = if (length(new_lins_found) > 0) "fdiis_new_lins.csv" else NA
  )
  if (length(new_lins_found) > 0) {
    write_csv(data.frame(new_lin = new_lins_found), file.path(audit_log_dir, "fdiis_new_lins.csv"))
    log_info("Found and logged {length(new_lins_found)} new LINs present only in FDIIS data.")
  }
  
  # 4. Categorical Pair Audit
  categorical_summaries <- analyze_procurement_patterns(fdiis_cleaned)
  audit_log$categorical_summaries <- list(
    by_ba_count = nrow(categorical_summaries$by_ba),
    by_pid_count = nrow(categorical_summaries$by_pid),
    by_pid_group_count = nrow(categorical_summaries$by_pid_group)
  )
  write_csv(categorical_summaries$by_ba, file.path(output_dir, "fdiis_lins_by_ba.csv"))
  write_csv(categorical_summaries$by_pid, file.path(output_dir, "fdiis_lins_by_pid.csv"))
  write_csv(categorical_summaries$by_pid_group, file.path(output_dir, "fdiis_lins_by_pid_group.csv"))
  
  # 5. Save Final Results
  audit_log$end_time <- Sys.time()
  audit_log$elapsed_time_seconds <- as.numeric(difftime(audit_log$end_time, audit_log$start_time, units = "secs"))
  
  audit_filename <- paste0("fdiis_audit_log_", format(audit_log$start_time, "%Y%m%d_%H%M%S"), ".json")
  write_json(audit_log, file.path(audit_log_dir, audit_filename), auto_unbox = TRUE, pretty = TRUE)
  
  saveRDS(fdiis_cleaned, file.path(output_dir, "fdiis_processed_latest.rds"))
  write_csv(fdiis_cleaned, file.path(output_dir, "fdiis_processed_latest.csv"))
  log_info("Saved final processed FDIIS data and audit files.")
  
  return(list(fdiis_data = fdiis_cleaned, audit = audit_log))
}

#' Main function wrapper for testing
main_fdiis_processing <- function() {
  # Load dependencies
  sacs_data <- readRDS("../data/intermediate/r_processing/sacs/sacs_processed_latest.rds")
  ldac_data <- readRDS("../data/intermediate/r_processing/ldac/ldac_processed_latest.rds")
  lmdb_data <- readRDS("../data/intermediate/r_processing/lmdb/lmdb_processed_latest.rds")
  
  process_fdiis_auto(
    sacs_data = sacs_data,
    ldac_data = ldac_data,
    lmdb_data = lmdb_data
  )
}
