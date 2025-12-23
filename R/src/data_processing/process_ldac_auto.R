# R/src/data_processing/process_ldac_auto.R
# LDAC Inventory Processing with Enhanced Auditing and Cross-Validation
#
# Author: NGRER Development Team
# Last Modified: 2025-12-17 (Retains 3-digit UICs and logs mismatches)

library(dplyr)
library(readr)
library(stringr)
library(logger)
library(readxl)
library(jsonlite)

# Setup logging
log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

#' Main LDAC processing function
#' @export
process_ldac_auto <- function(ldac_directory = "../data/inputs/current/ldac",
                              sacs_data,
                              output_dir = "../data/intermediate/r_processing/ldac",
                              audit_log_dir = "../logs/audit/data_lineage") {
  
  audit_log <- list()
  audit_log$start_time <- Sys.time()
  
  # Create output directories
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (!dir.exists(audit_log_dir)) dir.create(audit_log_dir, recursive = TRUE)
  
  # --- 1. Read Raw Data ---
  ldac_file <- list.files(ldac_directory, pattern = "AE2S_LIN_DATA_G8_NIIN_File.*\\.xlsx$", full.names = TRUE)[1]
  sheet_names <- excel_sheets(ldac_file)
  ldac_raw <- sheet_names %>%
    set_names() %>%
    map_dfr(~ read_excel(ldac_file, sheet = .x, col_types = "text"), .id = "source_sheet")
  
  audit_log$input_file <- list(filename = basename(ldac_file), total_rows_read = nrow(ldac_raw))
  
  # --- 2. Column Standardization & Cleaning ---
  ldac_std_names <- ldac_raw %>%
    rename_with(~"uic", all_of(c("SUPPLY_RECORD"))) %>%
    rename_with(~"lin", all_of(c("LIN_NSLIN"))) %>%
    rename_with(~"on_hand_qty", all_of(c("ON_HAND_QTY"))) %>%
    rename_with(~"compo", all_of(c("COMPONENT_CODE"))) %>%
    select(uic, lin, on_hand_qty, compo)
  
  ldac_cleaned <- ldac_std_names %>%
    mutate(
      uic = str_trim(uic),
      lin = str_trim(lin),
      compo = str_trim(compo),
      on_hand_qty_num = as.numeric(on_hand_qty)
    )
  
  # --- 3. Validation and Mismatch Identification ---
  sacs_uic_compo_map <- sacs_data %>%
    select(uic, sacs_compo = compo) %>%
    distinct(uic, .keep_all = TRUE)
  
  validation_check <- ldac_cleaned %>%
    left_join(sacs_uic_compo_map, by = "uic") %>%
    mutate(
      # Relaxed UIC validation rule to include 3-digit UICs
      is_valid_uic = str_length(uic) >= 3 & !is.na(uic),
      is_valid_lin = str_length(lin) >= 5 & !is.na(lin),
      is_valid_qty = !is.na(on_hand_qty_num) & on_hand_qty_num >= 0,
      is_compo_mismatch = (compo != sacs_compo) & !is.na(sacs_compo)
    )
  
  # --- 4. Generate Detailed Audit Information ---
  mismatched_uics_df <- validation_check %>%
    filter(is_compo_mismatch) %>%
    select(uic, sacs_compo, ldac_compo = compo) %>%
    distinct()
  
  three_digit_uics_df <- validation_check %>%
    filter(str_length(uic) == 3) %>%
    group_by(compo) %>%
    summarise(count = n_distinct(uic), .groups = "drop")
  
  audit_log$validation_failures <- list(
    invalid_uic_format = sum(!validation_check$is_valid_uic),
    invalid_lin = sum(!validation_check$is_valid_lin),
    invalid_qty = sum(!validation_check$is_valid_qty),
    uic_compo_mismatch_count = nrow(mismatched_uics_df),
    three_digit_uic_counts_by_compo = three_digit_uics_df
  )
  
  # --- 5. Filter Data and Finalize ---
  validated_data <- validation_check %>%
    filter(is_valid_uic & is_valid_lin & is_valid_qty) %>% # This now keeps 3-digit UICs
    select(uic, lin, on_hand_qty = on_hand_qty_num, compo, is_compo_mismatch)
  
  # --- 6. Generate Output Audit Log & Save ---
  audit_log$output_file <- list(
    total_rows = nrow(validated_data),
    unique_uics = n_distinct(validated_data$uic),
    unique_lins = n_distinct(validated_data$lin),
    total_on_hand_qty = sum(validated_data$on_hand_qty, na.rm = TRUE)
  )
  
  audit_log$end_time <- Sys.time()
  audit_log$elapsed_time_seconds <- as.numeric(difftime(audit_log$end_time, audit_log$start_time, units = "secs"))
  
  # Save the detailed mismatch list and the main audit log
  write_csv(mismatched_uics_df, file.path(output_dir, "ldac_uic_compo_mismatches.csv"))
  write_json(audit_log, file.path(audit_log_dir, paste0("ldac_audit_log_", format(audit_log$start_time, "%Y%m%d_%H%M%S"), ".json")), auto_unbox = TRUE, pretty = TRUE)
  
  # Save the main processed file
  saveRDS(validated_data, file.path(output_dir, "ldac_processed_latest.rds"))
  log_info("Saved final processed LDAC data and audit files.")
  
  # --- 7. Print Console Summary ---
  print_ldac_audit_summary(audit_log)
  
  return(list(ldac_data = validated_data, audit = audit_log))
}

#' Helper to print a concise summary to the console
print_ldac_audit_summary <- function(audit_log) {
  # (Implementation remains the same, but will now print the new audit fields)
  cat("\n--- LDAC Processing Audit Summary ---\n")
  cat("Elapsed Time:", round(audit_log$elapsed_time_seconds, 2), "seconds\n")
  cat("\n--- VALIDATION --- \n")
  removed_count <- audit_log$input_file$total_rows_read - audit_log$output_file$total_rows
  cat("Rows Removed (Invalid Format):", scales::comma(removed_count), "\n")
  cat("  - UIC/COMPO Mismatches Found:", scales::comma(audit_log$validation_failures$uic_compo_mismatch_count), "(Not Removed)\n")
  
  three_digit_uics <- audit_log$validation_failures$three_digit_uic_counts_by_compo
  if(nrow(three_digit_uics) > 0) {
    cat("  - 3-Digit UICs Found:", scales::comma(sum(three_digit_uics$count)), "(Kept)\n")
    for(i in 1:nrow(three_digit_uics)) {
      cat("    - COMPO", three_digit_uics$compo[i], ":", scales::comma(three_digit_uics$count[i]), "UICs\n")
    }
  }
  
  cat("\n--- OUTPUT: Final Dataset ---\n")
  cat("Final Rows:", scales::comma(audit_log$output_file$total_rows), "\n")
  cat("Total On-Hand Quantity:", scales::comma(audit_log$output_file$total_on_hand_qty), "\n")
  cat("----------------------------------\n")
}

#' Main function wrapper for testing
main_ldac_processing <- function() {
  sacs_file <- "../data/intermediate/r_processing/sacs/sacs_processed_latest.rds"
  if(!file.exists(sacs_file)){
    log_error("SACS processed file not found. Please run SACS processing first.")
    return(NULL)
  }
  sacs_data <- readRDS(sacs_file)
  
  process_ldac_auto(sacs_data = sacs_data)
}
