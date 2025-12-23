# R/src/data_processing/process_darpl_auto.R
# DARPL (The Department of the Army Master Priority List) Processing with Enhanced Auditing
#
# Author: NGRER Development Team
# Last Modified: 2025-12-17 (Definitively fixed JSON conversion error for audit log)

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

#' Main DARPL processing function
#' @export
process_darpl_auto <- function(darpl_directory = "../data/inputs/current/darpl",
                               output_dir = "../data/intermediate/r_processing/darpl",
                               audit_log_dir = "../logs/audit/data_lineage") {
  
  audit_log <- list()
  audit_log$start_time <- Sys.time()
  
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (!dir.exists(audit_log_dir)) dir.create(audit_log_dir, recursive = TRUE)
  
  # 1. Read Data
  darpl_file <- list.files(darpl_directory, pattern = "^CUI_.*DARPL.*\\.(xlsx|xls)$", full.names = TRUE)[1]
  sheet_names <- excel_sheets(darpl_file)
  target_sheet <- sheet_names[str_detect(toupper(sheet_names), "TABLE")][1]
  if(is.na(target_sheet)) target_sheet <- sheet_names[1]
  darpl_raw <- read_excel(darpl_file, sheet = target_sheet, col_types = "text")
  audit_log$input_file <- list(filename = basename(darpl_file), total_rows_read = nrow(darpl_raw))
  
  # 2. Clean and Standardize
  required_cols <- c("FY", "darpl_rank", "COMPO", "UIC", "UIC_TYPE", "TYPCO")
  current_names <- names(darpl_raw)
  names(darpl_raw)[toupper(current_names) == "DARPL_RANK"] <- "darpl_rank"
  darpl_selected <- darpl_raw %>% select(any_of(required_cols))
  
  darpl_cleaned <- darpl_selected %>%
    mutate(
      fy_num = as.numeric(gsub("FY", "", FY)),
      darpl_rank_num = as.numeric(darpl_rank),
      uic_clean = str_trim(str_to_upper(UIC)),
      compo_clean = str_trim(str_to_upper(COMPO)),
      uic_type_clean = str_trim(str_to_upper(UIC_TYPE)),
      typco_clean = str_trim(str_to_upper(TYPCO))
    )
  
  # 3. Validation
  validated_data <- darpl_cleaned %>%
    filter(!is.na(uic_clean) & str_length(uic_clean) == 6, !is.na(darpl_rank_num) & darpl_rank_num > 0, !is.na(fy_num))
  
  # --- 4. Generate Audit Log (CORRECTED SECTION) ---
  
  # First, create the summary objects
  rank_summary_obj <- summary(validated_data$darpl_rank_num)
  compo_counts_df <- as.data.frame(count(validated_data, compo_clean))
  uic_type_counts_df <- as.data.frame(count(validated_data, uic_type_clean))
  typco_counts_df <- as.data.frame(count(validated_data, typco_clean))
  
  # Now, create the audit log list using simple, JSON-safe data types
  audit_log$output_file <- list(
    total_rows = nrow(validated_data),
    unique_uics = n_distinct(validated_data$uic_clean),
    fy_range = if(nrow(validated_data)>0) paste(range(validated_data$fy_num), collapse=" to ") else NA,
    # Convert the summary object to a named list
    rank_stats = list(
      Min = as.numeric(rank_summary_obj["Min."]),
      Q1 = as.numeric(rank_summary_obj["1st Qu."]),
      Median = as.numeric(rank_summary_obj["Median"]),
      Mean = as.numeric(rank_summary_obj["Mean"]),
      Q3 = as.numeric(rank_summary_obj["3rd Qu."]),
      Max = as.numeric(rank_summary_obj["Max."])
    ),
    # The data frames from as.data.frame() are already JSON-safe
    compo_counts = compo_counts_df,
    uic_type_counts = uic_type_counts_df,
    typco_counts = typco_counts_df
  )
  
  audit_log$end_time <- Sys.time()
  audit_log$elapsed_time_seconds <- as.numeric(difftime(audit_log$end_time, audit_log$start_time, units = "secs"))
  
  # --- 5. Save Results ---
  audit_filename <- paste0("darpl_audit_log_", format(audit_log$start_time, "%Y%m%d_%H%M%S"), ".json")
  write_json(audit_log, file.path(audit_log_dir, audit_filename), auto_unbox = TRUE, pretty = TRUE)
  
  saveRDS(validated_data, file.path(output_dir, "darpl_processed_latest.rds"))
  log_info("Saved final processed DARPL data and audit log.")
  
  print_darpl_audit_summary(audit_log)
  return(list(darpl_data = validated_data, audit = audit_log))
}

#' Helper to print a concise summary to the console
print_darpl_audit_summary <- function(audit_log) {
  # This function is now safe because the audit_log contains simple types
  cat("\n--- DARPL Processing Audit Summary ---\n")
  cat("Final Rows:", scales::comma(audit_log$output_file$total_rows), "\n")
  cat("Unique UICs:", scales::comma(audit_log$output_file$unique_uics), "\n")
  cat("Fiscal Year(s):", audit_log$output_file$fy_range, "\n")
  
  rank_stats <- audit_log$output_file$rank_stats
  if (!is.null(rank_stats)) {
    cat("DARPL Rank Range:", scales::comma(rank_stats$Min), "to", scales::comma(rank_stats$Max), "\n")
  }
  
  cat("\n--- Categorical Counts ---\n")
  cat("Components:\n"); print(audit_log$output_file$compo_counts)
  cat("UIC Types:\n"); print(audit_log$output_file$uic_type_counts)
  cat("TYPCOs:\n"); print(audit_log$output_file$typco_counts)
  cat("----------------------------------\n")
}

#' Main function wrapper for testing
main_darpl_processing <- function() {
  process_darpl_auto()
}
