# R/tests/unit/test_lmdb_processing.R
# Standalone Test Script for LMDB Processing - ARC/Linux Version

rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

library(dplyr); library(readr); library(stringr); library(logger); library(readxl); library(jsonlite);

log_threshold(logger::INFO)
log_info <- logger::log_info

source("src/data_processing/process_lmdb_auto.R")

cat("=== Testing LMDB Processing in ARC Environment ===\n")

result_list <- main_lmdb_processing()
audit_log <- result_list$audit

if (!is.null(audit_log)) {
  cat("\n✅ LMDB processing test PASSED!\n")
  cat("\n--- LMDB Processing Audit Summary ---\n")
  cat("Elapsed Time:", round(audit_log$elapsed_time_seconds, 2), "seconds\n")
  cat("Input Rows Read:", scales::comma(audit_log$input_file$total_rows_read), "\n")
  
  cat("\n--- OUTPUT: Final Dataset ---\n")
  cat("Total Unique LINs:", scales::comma(audit_log$output_file$total_lins), "\n")
  cat("Active LINs:", scales::comma(audit_log$output_file$active_lins), "\n")
  cat("Total PUC Value:", scales::dollar(audit_log$output_file$total_puc_value), "\n")
  
  cat("\n--- SUBSTITUTION RULES ---\n")
  cat("Total Rules Found:", scales::comma(audit_log$substitution_rules$total_rules_found), "\n")
  cat("LINs with Substitutes:", scales::comma(audit_log$substitution_rules$lins_with_substitutes), "\n")
  
  cat("----------------------------------\n")
} else {
  cat("\n❌ LMDB processing test FAILED! See logs for details.\n")
}

cat("\n=== End LMDB Test ===\n")
