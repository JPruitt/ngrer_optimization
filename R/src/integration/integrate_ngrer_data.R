# R/src/integration/integrate_ngrer_data.R
# NGRER Master Data Integration Pipeline (Stable Baseline)
#
# Author: NGRER Development Team
# Last Modified: [Current Date]

# --- 1. Load Libraries ---
library(dplyr)
library(readr)
library(stringr)
library(logger)
library(readxl)
library(lubridate)
library(jsonlite)
library(tidyr)

# --- 2. HELPER & RAW PROCESSING FUNCTIONS ---

# (This script assumes the individual processing scripts exist in `src/data_processing/`)
# We will source them directly.

# --- 3. MASTER INTEGRATION FUNCTION ---
#' @export
integrate_ngrer_data <- function(raw_data_root = "~/ngrer_optimization/data/inputs/current",
                                 output_dir = "~/ngrer_optimization/data/intermediate",
                                 log_root = "~/ngrer_optimization/logs") {
  
  start_run_time <- Sys.time()
  start_time_str <- format(start_run_time, "%Y%m%d_%H%M%S")
  
  exec_log_path <- file.path(log_root, "execution", paste0("exec_", start_time_str, ".log"))
  log_appender(appender_tee(exec_log_path))
  
  tryCatch({
    log_info("--- Sourcing all data processing scripts ---")
    source("src/data_processing/process_sacs_auto.R")
    source("src/data_processing/process_ldac_auto.R")
    source("src/data_processing/process_lmdb_auto.R")
    source("src/data_processing/process_fdiis_auto.R")
    source("src/data_processing/process_darpl_auto.R")
    source("src/data_processing/process_substitutions_auto.R")
    source("src/data_processing/process_transfers_auto.R")
    
    log_info("--- Executing individual data processors ---")
    sacs_result <- main_sacs_processing()
    ldac_result <- main_ldac_processing()
    lmdb_result <- main_lmdb_processing()
    fdiis_result <- main_fdiis_processing()
    darpl_result <- main_darpl_processing()
    subs_result <- main_substitutions_processing()
    transfers_result <- main_transfers_processing()
    
    sacs_clean <- sacs_result$sacs_data
    ldac_clean <- ldac_result$ldac_data
    darpl_clean <- darpl_result$darpl_data
    
    # --- Final Integration ---
    log_info("--- Master Integration: Joining all clean data sources ---")
    ldac_summary <- ldac_clean %>% 
      group_by(lin) %>% 
      summarise(total_on_hand = sum(on_hand_qty, na.rm=TRUE), .groups="drop")
    
    final_data <- sacs_clean %>%
      left_join(ldac_summary, by = "lin") %>%
      left_join(darpl_clean, by = "uic") %>%
      mutate(across(where(is.numeric), ~replace_na(., 0))) %>%
      mutate(shortfall = pmax(0, rqeqp - total_on_hand))
    
    # --- Final (but flawed) Audit & Save ---
    log_info("--- Final Audit & Save ---")
    final_audit_summary <- list(
      final_rows = nrow(final_data), unique_uics = n_distinct(final_data$uic),
      unique_lins = n_distinct(final_data$lin), total_required = sum(final_data$rqeqp),
      total_on_hand = sum(final_data$total_on_hand), # This is the known bug
      total_shortfall = sum(final_data$shortfall)
    )
    
    # Simple console print for this baseline version
    cat("\n--- Final Integration Audit Summary ---\n")
    cat("Total Pipeline Time:", round(as.numeric(difftime(Sys.time(), start_run_time, units="secs")), 2), "seconds\n")
    cat("Final Records Created:", scales::comma(final_audit_summary$final_rows), "\n")
    # ... and so on for the rest of the summary
    
    return(list(final_data = final_data, audit = list(final_output_summary = final_audit_summary)))
    
  }, error = function(e) {
    log_error("CRITICAL PIPELINE FAILURE: {e$message}")
    return(NULL)
  })
}
