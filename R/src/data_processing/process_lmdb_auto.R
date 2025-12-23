# R/src/data_processing/process_lmdb_auto.R
# LMDB (LIN Management Database) Processing with Enhanced Auditing
#
# Author: NGRER Development Team
# Last Modified: 2025-12-17 (Definitive version with case-insensitive sheet detection)

library(dplyr)
library(readr)
library(stringr)
library(logger)
library(readxl)
library(tidyr)
library(jsonlite)

log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

# --- HELPER FUNCTIONS ---

#' Build substitution rules from cleaned LMDB data
build_substitution_rules <- function(lmdb_cleaned) {
  log_info("Building substitution rules...")
  replaces_cols <- paste0("REPLACES", 1:5)
  replaced_by_cols <- paste0("REPLACED_BY", 1:5)
  
  replaces_rules <- lmdb_cleaned %>%
    select(substitute_lin = lin, all_of(replaces_cols)) %>%
    pivot_longer(cols = all_of(replaces_cols), values_to = "primary_lin", values_drop_na = TRUE) %>%
    filter(primary_lin != "" & !is.na(primary_lin)) %>%
    select(primary_lin, substitute_lin)
  
  replaced_by_rules <- lmdb_cleaned %>%
    select(primary_lin = lin, all_of(replaced_by_cols)) %>%
    pivot_longer(cols = all_of(replaced_by_cols), values_to = "substitute_lin", values_drop_na = TRUE) %>%
    filter(substitute_lin != "" & !is.na(substitute_lin)) %>%
    select(primary_lin, substitute_lin)
  
  substitution_rules <- bind_rows(replaces_rules, replaced_by_rules) %>%
    filter(primary_lin != substitute_lin) %>%
    distinct()
  
  return(substitution_rules)
}

# --- MAIN FUNCTION ---

#' Main LMDB processing function with detailed validation and auditing.
#' @export
process_lmdb_auto <- function(lmdb_directory = "../data/inputs/current/lmdb",
                              output_dir = "../data/intermediate/r_processing/lmdb",
                              audit_log_dir = "../logs/audit/data_lineage") {
  
  audit_log <- list()
  audit_log$start_time <- Sys.time()
  
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (!dir.exists(audit_log_dir)) dir.create(audit_log_dir, recursive = TRUE)
  
  # --- 1. Read Raw Data ---
  lmdb_file <- list.files(lmdb_directory, pattern = "LINS_ACTIVE.*\\.xlsx$", full.names = TRUE)[1]
  log_info("Reading raw LMDB data from: {basename(lmdb_file)}")
  
  # Case-insensitive sheet detection
  sheet_names <- excel_sheets(lmdb_file)
  target_sheet_index <- which(toupper(sheet_names) == "LINS_ACTIVE")
  
  if (length(target_sheet_index) == 0) {
    log_error("CRITICAL: Sheet containing 'LINS_ACTIVE' not found in {basename(lmdb_file)}. Available sheets: {paste(sheet_names, collapse=', ')}")
    stop("Required sheet 'LINS_ACTIVE' not found.")
  }
  
  target_sheet_name <- sheet_names[target_sheet_index[1]]
  log_info("Found target sheet: '{target_sheet_name}'")
  
  lmdb_raw <- read_excel(lmdb_file, sheet = target_sheet_name, col_types = "text")
  audit_log$input_file <- list(filename = basename(lmdb_file), total_rows_read = nrow(lmdb_raw))
  
  # --- 2. Select, Clean, and Standardize ---
  log_info("Cleaning and standardizing LMDB data...")
  required_cols <- c("LIN", "SSN", "MOD_LEVEL", "MAJOR_CAPABILITY_NAME", "PORTFOLIO", "STATUS", "LIN_TYPE", "PUC",
                     "REPLACES1", "REPLACES2", "REPLACES3", "REPLACES4", "REPLACES5",
                     "REPLACED_BY1", "REPLACED_BY2", "REPLACED_BY3", "REPLACED_BY4", "REPLACED_BY5")
  
  lmdb_selected <- lmdb_raw %>% select(any_of(required_cols))
  
  lmdb_cleaned <- lmdb_selected %>%
    mutate(
      lin = str_trim(str_to_upper(LIN)),
      ssn = str_trim(str_to_upper(SSN)),
      mod_level = as.numeric(MOD_LEVEL),
      puc_numeric = as.numeric(gsub("[$,]", "", PUC)),
      status = str_trim(str_to_upper(STATUS))
    ) %>%
    filter(!is.na(lin) & lin != "")
  
  # --- 3. Build Substitution Rules ---
  substitution_rules <- build_substitution_rules(lmdb_cleaned)
  
  # --- 4. Generate Audit Log ---
  audit_log$output_file <- list(
    total_lins = n_distinct(lmdb_cleaned$lin),
    active_lins = n_distinct(filter(lmdb_cleaned, status == "ACTIVE")$lin),
    total_puc_value = sum(lmdb_cleaned$puc_numeric, na.rm = TRUE)
  )
  audit_log$substitution_rules <- list(
    total_rules_found = nrow(substitution_rules),
    lins_with_substitutes = n_distinct(substitution_rules$primary_lin)
  )
  
  audit_log$end_time <- Sys.time()
  audit_log$elapsed_time_seconds <- as.numeric(difftime(audit_log$end_time, audit_log$start_time, units = "secs"))
  
  # --- 5. Save Results ---
  audit_filename <- paste0("lmdb_audit_log_", format(audit_log$start_time, "%Y%m%d_%H%M%S"), ".json")
  write_json(audit_log, file.path(audit_log_dir, audit_filename), auto_unbox = TRUE, pretty = TRUE)
  
  # Save both the main data and the rules in one RDS file for the integration layer
  saveRDS(
    list(lmdb_data = lmdb_cleaned, substitution_rules = substitution_rules), 
    file.path(output_dir, "lmdb_processed_latest.rds")
  )
  
  write_csv(lmdb_cleaned, file.path(output_dir, "lmdb_data.csv"))
  write_csv(substitution_rules, file.path(output_dir, "lmdb_substitutions.csv"))
  log_info("Saved final processed LMDB data, substitution rules, and audit log.")
  
  return(list(lmdb_data = lmdb_cleaned, substitution_rules = substitution_rules, audit = audit_log))
}

#' Main function wrapper for testing
main_lmdb_processing <- function() {
  process_lmdb_auto()
}
