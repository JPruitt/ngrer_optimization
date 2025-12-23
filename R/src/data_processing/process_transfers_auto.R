# R/src/data_processing/process_transfers_auto.R
# LMI Transfers Processing with Enhanced Auditing
#
# Author: NGRER Development Team
# Last Modified: 2025-12-17 (Implemented robust two-step date parsing)

library(dplyr)
library(readr)
library(stringr)
library(logger)
library(readxl)
library(lubridate)
library(jsonlite)

log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

#' Main LMI transfers processing function
#' @export
process_transfers_auto <- function(transfers_directory = "../data/inputs/current/transfers",
                                   output_dir = "../data/intermediate/r_processing/transfers",
                                   audit_log_dir = "../logs/audit/data_lineage") {
  
  audit_log <- list(); audit_log$start_time <- Sys.time()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (!dir.exists(audit_log_dir)) dir.create(audit_log_dir, recursive = TRUE)
  
  # --- 1. Read Raw Data ---
  transfer_file <- list.files(transfers_directory, pattern = "^LMI_DST_PSDs.*\\.(xlsx|xls)$", full.names = TRUE)[1]
  log_info("Reading raw LMI transfer data from: {basename(transfer_file)}")
  transfer_raw <- read_excel(transfer_file, col_types = "text")
  audit_log$input_file <- list(filename = basename(transfer_file), total_rows_read = nrow(transfer_raw))
  
  # --- 2. Standardize, Clean, and Select ---
  log_info("Standardizing columns and cleaning data...")
  names(transfer_raw) <- toupper(names(transfer_raw))
  names(transfer_raw) <- gsub(" ", "_", names(transfer_raw))
  
  required_cols <- c("VETTING_STATUS", "FROM_COMPO", "TO_COMPO", "FROM_CODE", "FROM_PB_LIN", 
                     "TO_PB_LIN", "CATALOG_LIN", "PLANNING_ESTIMATE", "TO_CODE", 
                     "VALIDATED_QUANTITY", "SUSPENSE_DATE", "EXTENDED_PRICE")
  
  transfers_selected <- transfer_raw %>% select(any_of(required_cols))
  
  transfers_cleaned <- transfers_selected %>%
    mutate(
      from_compo_code = case_when(
        toupper(FROM_COMPO) == "ACTIVE ARMY" ~ "1", toupper(FROM_COMPO) == "NATIONAL GUARD" ~ "2",
        toupper(FROM_COMPO) == "ARMY RESERVE" ~ "3", toupper(FROM_COMPO) == "ARMY PREPOSITIONED SETS" ~ "6", TRUE ~ NA_character_
      ),
      to_compo_code = case_when(
        toupper(TO_COMPO) == "ACTIVE ARMY" ~ "1", toupper(TO_COMPO) == "NATIONAL GUARD" ~ "2",
        toupper(TO_COMPO) == "ARMY RESERVE" ~ "3", toupper(TO_COMPO) == "ARMY PREPOSITIONED SETS" ~ "6", TRUE ~ NA_character_
      ),
      from_code_parsed_compo = str_extract(FROM_CODE, "(?<=Compo )\\d"),
      final_from_compo = coalesce(from_code_parsed_compo, from_compo_code),
      lin = coalesce(CATALOG_LIN, TO_PB_LIN, FROM_PB_LIN),
      to_uic = str_trim(str_to_upper(TO_CODE)),
      vetting_status = str_trim(str_to_upper(VETTING_STATUS)),
      quantity = as.numeric(VALIDATED_QUANTITY),
      extended_price = as.numeric(gsub("[$,]", "", EXTENDED_PRICE)),
      
      # Robust Two-Step Date Parsing
      date_from_numeric_pe = as.Date(suppressWarnings(as.numeric(PLANNING_ESTIMATE)), origin = "1899-12-30"),
      date_from_numeric_sd = as.Date(suppressWarnings(as.numeric(SUSPENSE_DATE)), origin = "1899-12-30"),
      planning_date = coalesce(date_from_numeric_pe, parse_date_time(PLANNING_ESTIMATE, orders = c("mdy", "Ymd", "dmy"))),
      suspense_date = coalesce(date_from_numeric_sd, parse_date_time(SUSPENSE_DATE, orders = c("mdy", "Ymd", "dmy")))
    )
  
  # --- 3. Validation ---
  log_info("Validating data formats...")
  pre_validation_rows <- nrow(transfers_cleaned)
  
  validated_data <- transfers_cleaned %>%
    filter(
      !is.na(lin) & str_length(lin) >= 5,
      !is.na(to_uic) & str_length(to_uic) == 6,
      !is.na(quantity) & quantity > 0
    )
  log_info("Retained {nrow(validated_data)} of {pre_validation_rows} records after validation.")
  
  # --- 4. Generate Audit Log ---
  audit_log$output_file <- list(
    total_records = nrow(validated_data),
    total_quantity = sum(validated_data$quantity, na.rm = TRUE),
    total_value = sum(validated_data$extended_price, na.rm = TRUE),
    unique_lins = n_distinct(validated_data$lin),
    unique_to_uics = n_distinct(validated_data$to_uic),
    vetting_status_counts = as.data.frame(count(validated_data, vetting_status, sort = TRUE)),
    from_compo_counts = as.data.frame(count(validated_data, final_from_compo, sort = TRUE)),
    to_compo_counts = as.data.frame(count(validated_data, to_compo_code, sort = TRUE))
  )
  
  audit_log$end_time <- Sys.time()
  audit_log$elapsed_time_seconds <- as.numeric(difftime(audit_log$end_time, audit_log$start_time, units = "secs"))
  
  # --- 5. Save Results ---
  audit_filename <- paste0("transfers_audit_log_", format(audit_log$start_time, "%Y%m%d_%H%M%S"), ".json")
  write_json(audit_log, file.path(audit_log_dir, audit_filename), auto_unbox = TRUE, pretty = TRUE)
  
  saveRDS(validated_data, file.path(output_dir, "transfers_processed_latest.rds"))
  write_csv(validated_data, file.path(output_dir, "transfers_processed_latest.csv"))
  log_info("Saved final processed transfers data and audit log.")
  
  print_transfers_audit_summary(audit_log)
  return(list(transfer_data = validated_data, audit = audit_log))
}

#' Helper to print a concise summary to the console
print_transfers_audit_summary <- function(audit_log) {
  cat("\n--- LMI Transfers Processing Audit Summary ---\n")
  cat("Total Records Processed:", scales::comma(audit_log$output_file$total_records), "\n")
  cat("Total Quantity Transferred:", scales::comma(audit_log$output_file$total_quantity), "\n")
  cat("Total Value of Transfers:", scales::dollar(audit_log$output_file$total_value), "\n")
  cat("Unique LINs:", scales::comma(audit_log$output_file$unique_lins), "\n")
  cat("Unique Receiving UICs:", scales::comma(audit_log$output_file$unique_to_uics), "\n")
  
  cat("\n--- Vetting Status ---\n"); print(audit_log$output_file$vetting_status_counts)
  cat("\n--- Transfers From Component ---\n"); print(audit_log$output_file$from_compo_counts)
  cat("\n--- Transfers To Component ---\n"); print(audit_log$output_file$to_compo_counts)
  cat("----------------------------------\n")
}

#' Main function wrapper for testing
main_transfers_processing <- function() {
  process_transfers_auto()
}
