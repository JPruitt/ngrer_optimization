# R/src/data_processing/process_substitutions_auto.R
# Army Regulation Substitution Rules Processing with Enhanced Auditing
#
# Author: NGRER Development Team
# Last Modified: 2025-12-17 (Corrected dplyr::rename syntax for cross-version compatibility)

library(dplyr)
library(readr)
library(stringr)
library(logger)
library(readxl)
library(jsonlite)

# Setup logging functions
log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

#' Main substitution rule processing function.
#' @export
process_substitutions_auto <- function(substitutions_directory = "../data/inputs/current/substitutions",
                                       output_dir = "../data/intermediate/r_processing/substitutions",
                                       audit_log_dir = "../logs/audit/data_lineage") {
  
  audit_log <- list()
  audit_log$start_time <- Sys.time()
  
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (!dir.exists(audit_log_dir)) dir.create(audit_log_dir, recursive = TRUE)
  
  # --- 1. Read Raw Data ---
  files <- list.files(substitutions_directory, pattern = "\\.xlsx$", full.names = TRUE)
  chapters_file <- files[str_detect(basename(files), "CHAPTERS")][1]
  appendix_file <- files[str_detect(basename(files), "APPENDIX_H")][1]
  
  chapters_raw <- read_excel(chapters_file, col_types = "text")
  appendix_raw <- read_excel(appendix_file, col_types = "text")
  
  audit_log$input_files <- list(
    chapters = list(filename = basename(chapters_file), rows = nrow(chapters_raw)),
    appendix_h = list(filename = basename(appendix_file), rows = nrow(appendix_raw))
  )
  
  # --- 2. Process Chapters File ---
  log_info("Processing Chapters file to extract price and other data...")
  required_cols_chapters <- c("LIN", "NSN", "SUPPLY_CLASS", "UNIT_PRICE", "UNIT_OF_ISSUE", "HQDA_LIN")
  chapters_cleaned <- chapters_raw %>% 
    select(any_of(required_cols_chapters)) %>%
    mutate(
      lin = str_trim(str_to_upper(LIN)),
      nsn = str_trim(str_to_upper(NSN)),
      unit_price_num = as.numeric(gsub("[$,]", "", UNIT_PRICE)),
      is_hqda_lin = toupper(HQDA_LIN) == "Y"
    ) %>%
    select(lin, nsn, supply_class = SUPPLY_CLASS, unit_price = unit_price_num, unit_of_issue = UNIT_OF_ISSUE, is_hqda_lin) %>%
    filter(!is.na(lin) & lin != "")
  
  # --- 3. Process Appendix H File for Substitution Rules ---
  log_info("Processing Appendix H file for substitution rules...")
  
  # Use the modern, robust `rename()` with `any_of()` to handle multiple possible column names
  appendix_cleaned <- appendix_raw %>%
    rename(primary_lin = any_of(c("AUTH_LIN", "Primary LIN"))) %>%
    rename(substitute_lin = any_of(c("SUB_LIN", "Substitute LIN"))) %>%
    select(primary_lin, substitute_lin) %>%
    mutate(across(everything(), ~str_trim(str_to_upper(.)))) %>%
    filter(!is.na(primary_lin) & !is.na(substitute_lin) & primary_lin != "" & substitute_lin != "" & primary_lin != substitute_lin) %>%
    distinct()
  
  # --- 4. Combine and Generate Final Dataset ---
  log_info("Joining substitution rules with chapters data...")
  
  final_substitutions <- appendix_cleaned %>%
    left_join(chapters_cleaned, by = c("primary_lin" = "lin"), relationship = "many-to-many") %>%
    rename(
      primary_nsn = nsn,
      primary_supply_class = supply_class,
      primary_unit_price = unit_price,
      primary_unit_of_issue = unit_of_issue,
      primary_is_hqda = is_hqda_lin
    ) %>%
    left_join(chapters_cleaned, by = c("substitute_lin" = "lin"), relationship = "many-to-many") %>%
    rename(
      substitute_nsn = nsn,
      substitute_supply_class = supply_class,
      substitute_unit_price = unit_price,
      substitute_unit_of_issue = unit_of_issue,
      substitute_is_hqda = is_hqda_lin
    )
  
  # --- 5. Generate Audit Log ---
  audit_log$output_file <- list(
    total_rules = nrow(final_substitutions),
    unique_primary_lins = n_distinct(final_substitutions$primary_lin),
    unique_substitute_lins = n_distinct(final_substitutions$substitute_lin),
    rules_with_price_data = sum(!is.na(final_substitutions$primary_unit_price))
  )
  
  audit_log$end_time <- Sys.time()
  audit_log$elapsed_time_seconds <- as.numeric(difftime(audit_log$end_time, audit_log$start_time, units = "secs"))
  
  # --- 6. Save Results ---
  audit_filename <- paste0("substitutions_audit_log_", format(audit_log$start_time, "%Y%m%d_%H%M%S"), ".json")
  write_json(audit_log, file.path(audit_log_dir, audit_filename), auto_unbox = TRUE, pretty = TRUE)
  
  saveRDS(final_substitutions, file.path(output_dir, "substitutions_processed_latest.rds"))
  write_csv(final_substitutions, file.path(output_dir, "substitutions_processed_latest.csv"))
  log_info("Saved final processed substitutions data and audit log.")
  
  print_substitutions_audit_summary(audit_log)
  return(list(substitution_data = final_substitutions, audit = audit_log))
}

#' Helper to print a concise summary
print_substitutions_audit_summary <- function(audit_log) {
  cat("\n--- Substitutions Processing Audit Summary ---\n")
  cat("Elapsed Time:", round(audit_log$elapsed_time_seconds, 2), "seconds\n")
  cat("\n--- INPUTS ---\n")
  cat("Chapters Rows:", scales::comma(audit_log$input_files$chapters$rows), "\n")
  cat("Appendix H Rows:", scales::comma(audit_log$input_files$appendix_h$rows), "\n")
  
  cat("\n--- OUTPUT: Final Substitution Rules ---\n")
  cat("Total Rules Processed:", scales::comma(audit_log$output_file$total_rules), "\n")
  cat("Unique Primary LINs:", scales::comma(audit_log$output_file$unique_primary_lins), "\n")
  cat("Unique Substitute LINs:", scales::comma(audit_log$output_file$unique_substitute_lins), "\n")
  cat("Rules with Unit Price Data:", scales::comma(audit_log$output_file$rules_with_price_data), "\n")
  cat("----------------------------------\n")
}

#' Main function wrapper for testing
main_substitutions_processing <- function() {
  process_substitutions_auto()
}
