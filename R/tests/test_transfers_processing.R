# R/tests/unit/test_transfers_processing.R
# Standalone Test Script for Transfers Processing - ARC/Linux Version

rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

library(dplyr); library(readr); library(stringr); library(logger); library(readxl); library(jsonlite);

log_threshold(logger::INFO)
log_info <- logger::log_info

source("src/data_processing/process_transfers_auto.R")

cat("=== Testing LMI Transfers Processing in ARC Environment ===\n")

result_list <- main_transfers_processing()
audit_log <- result_list$audit

if (!is.null(audit_log)) {
  cat("\n✅ LMI Transfers processing test PASSED!\n")
} else {
  cat("\n❌ LMI Transfers processing test FAILED! See logs for details.\n")
}

cat("\n=== End Transfers Test ===\n")
