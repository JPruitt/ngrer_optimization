# R/tests/unit/test_integration_layer.R
# Standalone Test Script for the Master Data Integration Pipeline
#
# Author: NGRER Development Team
# Last Modified: [Current Date]

# --- 1. Setup Environment ---
rm(list = ls())
# Set working directory for ARC environment
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

# Load required libraries
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
library(profmem)


# Setup logging
log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn  
log_error <- logger::log_error

# --- 2. Source the Master Integration Script ---
cat("Loading NGRER master integration script...\n")
source("src/integration/integrate_ngrer_data.R")

# --- 3. Execute the Integration Pipeline ---
cat("=== Testing NGRer Master Integration Pipeline ===\n")
cat("Working directory:", getwd(), "\n\n")

result_list <- NULL
tryCatch({
  # Call the main integration function with corrected paths
  result_list <- integrate_ngrer_data(
    raw_data_root = "../data/inputs/current",
    output_dir = "../data/intermediate",
    log_root = "../logs"
  )
}, error = function(e) {
  log_error("Master integration pipeline failed during execution.")
  # The error is automatically logged to the error file by the main function
})

# --- 4. Validate and Summarize Results ---
if (!is.null(result_list) && !is.null(result_list$final_data) && !is.null(result_list$audit)) {
  cat("\n✅ Master Integration PASSED!\n")
  
  audit_log <- result_list$audit
  
  cat("\n--- Final Integration Audit Summary ---\n")
  cat("Total Pipeline Time:", round(audit_log$total_elapsed_seconds, 2), "seconds\n")
  
  final_summary <- audit_log$final_output_summary
  cat("Final Records Created:", scales::comma(final_summary$final_rows), "\n")
  cat("Final Unique UICs:", scales::comma(final_summary$unique_uics), "\n")
  cat("Final Unique LINs:", scales::comma(final_summary$unique_lins), "\n")
  cat("Final Total Required:", scales::comma(final_summary$total_required), "\n")
  cat("Final Total On-Hand:", scales::comma(final_summary$total_on_hand), "\n")
  cat("Final Total Shortfall:", scales::comma(final_summary$total_shortfall), "\n")
  cat("--------------------------------------\n")
  cat("A complete execution log, performance log, and master audit trail have been saved to the logs/ directory.\n")
  
} else {
  cat("\n❌ Master Integration FAILED. Review logs in the logs/errors/ directory for details.\n")
}

cat("\n=== End Integration Test ===\n")
