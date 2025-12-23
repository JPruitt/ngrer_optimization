# R/src/data_processing/process_sacs_auto.R
# SACS Requirements Processing with Enhanced Auditing
#
# Author: NGRER Development Team
# Last Modified: 2025-12-17 (Added detailed validation and dropped record auditing)

library(dplyr)
library(readr)
library(stringr)
library(logger)
library(lubridate)
library(jsonlite)

# Setup logging
log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

#' Main SACS processing function with detailed validation and auditing.
#' @export
process_sacs_auto <- function(sacs_directory = "../data/inputs/current/sacs",
                              output_dir = "../data/intermediate/r_processing/sacs",
                              audit_log_dir = "../logs/audit/data_lineage"){
  
  audit_log <- list()
  audit_log$start_time <- Sys.time()
  
  # Create output directories if they don't exist
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (!dir.exists(audit_log_dir)) dir.create(audit_log_dir, recursive = TRUE)
  
  # --- 1. Define Column Structures ---
  header_cols <- c("runid", "uic", "edatei", "tpsn", "macom", "actco", "adcco", "mdep", "compo", "untds", "carss", "typco", "unmbr", "fpa", "dampl", "src", "alo", "srcpara", "asgmt", "locco", "amsco", "brnch", "ccnum", "docno", "dpmnt", "elseq", "forco", "mbcmd", "mbloc", "mbprd", "mbsta", "mtoec", "ntref", "phase", "robco", "roc", "staco", "tdate", "ulccc", "utc", "col41", "col42")
  equip_cols <- c("runid", "uic", "edatei", "lin", "erc", "rmk1", "rmk2", "rqeqp", "aueqp", "rqboi", "auboi", "sorce", "mduic", "modpath", "col15")
  
  # --- 2. Read Raw Data ---
  eqp_file <- list.files(sacs_directory, pattern = "cla_eqpdet_roll.*\\.txt$", full.names = TRUE)[1]
  hdr_file <- list.files(sacs_directory, pattern = "cla_header_roll.*\\.txt$", full.names = TRUE)[1]
  
  log_info("Reading raw data files...")
  eqp_raw <- read_tsv(eqp_file, col_names = FALSE, col_types = cols(.default = "c"))
  names(eqp_raw) <- equip_cols[1:ncol(eqp_raw)]
  
  hdr_raw <- read_tsv(hdr_file, col_names = FALSE, col_types = cols(.default = "c"))
  names(hdr_raw) <- header_cols[1:ncol(hdr_raw)]
  
  # --- 3. Generate Input Audit Log ---
  log_info("Generating audit log for input files...")
  audit_log$input_files$equipment_file <- list(
    filename = basename(eqp_file), runid_date = as.character(as.Date(as.character(eqp_raw$runid[1]), 
                                                                     format="%Y%m%d")),
    total_rows = nrow(eqp_raw), unique_uics = n_distinct(eqp_raw$uic)
  )
  audit_log$input_files$header_file <- list(
    filename = basename(hdr_file), total_rows = nrow(hdr_raw), unique_uics = n_distinct(hdr_raw$uic)
  )
  
  # --- 4. Select, Clean, and Join Data ---
  log_info("Cleaning, selecting, and joining data...")
  
  equip_selected <- eqp_raw %>% select(runid, uic, lin, erc, rqeqp, aueqp) %>% mutate(uic = str_trim(uic))
  
  header_selected <- hdr_raw %>% select(uic, compo) %>% mutate(uic = str_trim(uic)) %>% 
    filter(!is.na(uic) & uic != "") %>% distinct(uic, .keep_all = TRUE)
  
  combined_data <- left_join(equip_selected, header_selected, by = "uic")
  
  uics_dropped_from_header <- setdiff(unique(header_selected$uic), unique(equip_selected$uic))
  
  audit_log$join_details <- list(uics_from_header_dropped_in_join = length(uics_dropped_from_header))
  log_info("{length(uics_dropped_from_header)} UICs from header file were dropped (no equipment records).")
  
  uics_in_header <- unique(header_selected$uic)
  uics_in_equip <- unique(equip_selected$uic)
  uics_dropped_from_header <- setdiff(uics_in_header, uics_in_equip)
  audit_log$join_details <- list(
    uics_in_header_deduplicated = length(uics_in_header),
    uics_in_equipment = length(uics_in_equip),
    uics_from_header_dropped_in_join = length(uics_dropped_from_header)
  )
  log_info("{length(uics_dropped_from_header)} UICs from header file were dropped (no equipment records).")
  
  # --- 5. Data Type Conversion and Validation ---
  log_info("Validating data formats and types...")
  pre_validation_rows <- nrow(combined_data)
  
  validation_check <- combined_data %>%
    mutate(
      runid_date = ymd(runid),
      rqeqp_num = as.numeric(rqeqp),
      aueqp_num = as.numeric(aueqp),
      is_valid_runid = !is.na(runid_date),
      is_valid_lin = str_length(lin) == 6 & !is.na(lin),
      is_valid_erc = erc %in% c("A", "P", "B", "C", "N", "S", "T"),
      is_valid_uic = str_length(uic) == 6 & !is.na(uic)
    )
  
  audit_log$validation_failures <- list(
    invalid_runid = sum(!validation_check$is_valid_runid),
    invalid_lin = sum(!validation_check$is_valid_lin),
    invalid_erc = sum(!validation_check$is_valid_erc),
    invalid_uic = sum(!validation_check$is_valid_uic),
    invalid_rqeqp = sum(is.na(validation_check$rqeqp_num)),
    invalid_aueqp = sum(is.na(validation_check$aueqp_num))
  )
  
  validated_data <- validation_check %>%
    filter(is_valid_runid & is_valid_lin & is_valid_erc & is_valid_uic & !is.na(rqeqp_num) & !is.na(aueqp_num)) %>%
    select(runid, uic, compo, lin, erc, rqeqp = rqeqp_num, aueqp = aueqp_num)
  
  log_info("Retained {nrow(validated_data)} of {pre_validation_rows} records after validation.")
  
  # --- 6. Generate Output Audit Log & Save ---
  log_info("Generating audit log for final dataset...")
  audit_log$output_file <- list(
    filename = "sacs_processed_latest.rds",
    total_rows = nrow(validated_data),
    unique_uics = n_distinct(validated_data$uic),
    erc_p_lins = n_distinct(filter(validated_data, erc == "P")$lin),
    erc_a_lins = n_distinct(filter(validated_data, erc == "A")$lin),
    total_rqeqp = sum(validated_data$rqeqp, na.rm = TRUE),
    total_aueqp = sum(validated_data$aueqp, na.rm = TRUE)
  )
  
  audit_log$end_time <- Sys.time()
  audit_log$elapsed_time_seconds <- as.numeric(difftime(audit_log$end_time, audit_log$start_time, units = "secs"))
  
  # *** Save audit log to centralized directory ***
  audit_filename <- paste0("sacs_audit_log_", format(audit_log$start_time, "%Y%m%d_%H%M%S"), ".json")
  audit_path <- file.path(audit_log_dir, audit_filename)
  write_json(audit_log, audit_path, auto_unbox = TRUE, pretty = TRUE)
  log_info("Saved audit log to: {audit_path}")
  
  # Save the intermediate data 
  saveRDS(validated_data, file.path(output_dir, "sacs_processed_latest.rds"))
  write_csv(validated_data, file.path(output_dir, "sacs_processed_latest.csv"))
  log_info("Saved final processed SACS data to {output_dir}")
  
  # --- 7. Print Console Summary ---
  print_audit_summary(audit_log)
  
  return(list(sacs_data = validated_data, audit = audit_log))
}

#' Helper to print a concise summary to the console
print_audit_summary <- function(audit_log) {
  cat("\n--- SACS Processing Audit Summary ---\n")
  cat("Elapsed Time:", round(audit_log$elapsed_time_seconds, 2), "seconds\n")
  
  cat("\n--- INPUT: Equipment File ---\n")
  cat("Rows Read:", scales::comma(audit_log$input_files$equipment_file$total_rows), "\n")
  
  cat("\n--- JOIN & VALIDATION --- \n")
  cat("Header UICs Dropped (No Equipment):", scales::comma(audit_log$join_details$uics_from_header_dropped_in_join), "\n")
  cat("Rows Removed (Invalid Format/Data):", scales::comma(
    audit_log$input_files$equipment_file$total_rows - audit_log$output_file$total_rows
  ), "\n")
  cat("  - Invalid LIN:", scales::comma(audit_log$validation_failures$invalid_lin), "\n")
  cat("  - Invalid UIC:", scales::comma(audit_log$validation_failures$invalid_uic), "\n")
  cat("  - Invalid Qty:", scales::comma(audit_log$validation_failures$invalid_rqeqp), "\n")
  
  cat("\n--- OUTPUT: Final Dataset ---\n")
  cat("Final Rows:", scales::comma(audit_log$output_file$total_rows), "\n")
  cat("Unique UICs:", scales::comma(audit_log$output_file$unique_uics), "\n")
  cat("Unique ERC 'A' LINs:", scales::comma(audit_log$output_file$erc_a_lins), "\n")
  cat("Unique ERC 'P' LINs:", scales::comma(audit_log$output_file$erc_p_lins), "\n")
  cat("Total Required:", scales::comma(audit_log$output_file$total_rqeqp), "\n")
  cat("Total Authorized:", scales::comma(audit_log$output_file$total_aueqp), "\n")
  difference <- audit_log$output_file$total_rqeqp - audit_log$output_file$total_aueqp
  cat("REQ'D-AUTH Difference:", scales::comma(difference), "\n")
  
  cat("----------------------------------\n")
}


#' Main function wrapper for testing
main_sacs_processing <- function() {
  process_sacs_auto()
}

