# R/tests/test_working_integration.R
# Standalone Test Script for the Stable Baseline Integration Pipeline
#
# Author: NGRER Development Team
# Last Modified: [Current Date]

# --- 1. Setup Environment ---
rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

# --- 2. Load Libraries ---
library(dplyr)
library(readr)
library(stringr)
library(logger)
library(purrr)
library(scales)
library(jsonlite)
library(readxl)
library(lubridate)
library(tidyr)

# --- 3. Setup Logging ---
log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

# --- 4. Source the Master Integration Script ---
cat("Loading NGRER baseline integration script...\n")
# Correctly sources your newly renamed file
source("src/integration/working_integration.R")

# --- 5. Execute the Integration Pipeline ---
cat("=== Testing NGRER Baseline Integration Pipeline ===\n")
cat("Working directory:", getwd(), "\n\n")

result_list <- NULL
tryCatch({
  # The main function in the baseline script is named 'integrate_ngrer_data'
  result_list <- integrate_ngrer_data(
    # Note: The baseline script uses internal sourcing, so no input_dirs are needed here
  )
}, error = function(e) {
  log_error("Baseline integration pipeline failed during execution: {e$message}")
  print(e)
})

# --- 6. Validate and Summarize Results ---
if (!is.null(result_list) && !is.null(result_list$final_data) && nrow(result_list$final_data) > 0) {
  cat("\n✅ Baseline Integration PASSED!\n")
  
  audit_summary <- result_list$audit$final_output_summary
  
  cat("\n--- Final Integration Audit Summary ---\n")
  cat("Final Records Created:", scales::comma(audit_summary$final_rows), "\n")
  cat("Final Unique UICs:", scales::comma(audit_summary$unique_uics), "\n")
  cat("Final Unique LINs:", scales::comma(audit_summary$unique_lins), "\n")
  cat("Final Total Required:", scales::comma(audit_summary$total_required), "\n")
  cat("Final Total On-Hand (Known Bug):", scales::comma(audit_summary$total_on_hand), "\n")
  cat("Final Total Shortfall (Known Bug):", scales::comma(audit_summary$total_shortfall), "\n")
  cat("--------------------------------------\n")
  
} else {
  cat("\n❌ Baseline Integration FAILED. Review logs for details.\n")
}

cat("\n=== End Baseline Integration Test ===\n")
