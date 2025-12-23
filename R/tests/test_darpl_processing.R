# R/tests/unit/test_darpl_processing.R
# Standalone Test Script for DARPL Priority Data Processing - ARC/Linux Version

rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

library(dplyr); library(readr); library(stringr); library(logger); library(readxl); library(jsonlite);

log_threshold(logger::INFO)
log_info <- logger::log_info

source("src/data_processing/process_darpl_auto.R")

cat("=== Testing DARPL Processing in ARC Environment ===\n")

result_list <- main_darpl_processing()
audit_log <- result_list$audit

if (!is.null(audit_log)) {
  cat("\n✅ DARPL processing test PASSED!\n")
} else {
  cat("\n❌ DARPL processing test FAILED! See logs for details.\n")
}

cat("\n=== End DARPL Test ===\n")
