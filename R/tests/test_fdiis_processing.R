# R/tests/unit/test_fdiis_processing.R
# Standalone Test Script for FDIIS Processing - ARC/Linux Version

rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

# Load libraries
library(dplyr); library(readr); library(stringr); library(logger); library(readxl); library(jsonlite);

# Setup logging
log_threshold(logger::INFO)
log_info <- logger::log_info

# Source the processing script
source("src/data_processing/process_fdiis_auto.R")

cat("=== Testing FDIIS Processing in ARC Environment ===\n")

# Execute the main processing function
result_list <- main_fdiis_processing()
audit_log <- result_list$audit

if (!is.null(audit_log)) {
  cat("\n✅ FDIIS processing test PASSED!\n")
  
  cat("\n--- FDIIS Processing Audit Summary ---\n")
  cat("Elapsed Time:", round(audit_log$elapsed_time_seconds, 2), "seconds\n")
  cat("Input Rows Read:", scales::comma(audit_log$input_file$total_rows_read), "\n")
  
  cat("\n--- New LINs Audit ---\n")
  cat("New LINs Found (not in SACS/LDAC/LMDB):", scales::comma(audit_log$new_lin_audit$new_lins_count), "\n")
  if(audit_log$new_lin_audit$new_lins_count > 0) {
    cat(" -> List saved to logs/audit/data_lineage/fdiis_new_lins.csv\n")
  }
  
  cat("\n--- Categorical Analysis Audit ---\n")
  cat("Unique LINs analyzed across", scales::comma(audit_log$categorical_summaries$by_ba_count), "Budget Activity categories.\n")
  cat("Unique LINs analyzed across", scales::comma(audit_log$categorical_summaries$by_pid_count), "OSDPE PID categories.\n")
  cat("Unique LINs analyzed across", scales::comma(audit_log$categorical_summaries$by_pid_group_count), "OSDPE PID Group categories.\n")
  
  cat("\n----------------------------------\n")
  
} else {
  cat("\n❌ FDIIS processing test FAILED! See logs for details.\n")
}

cat("\n=== End FDIIS Test ===\n")
