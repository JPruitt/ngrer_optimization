# R/tests/unit/test_substitutions_processing.R
# Standalone Test Script for Substitutions Processing - ARC/Linux Version

rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

library(dplyr); library(readr); library(stringr); library(logger); library(readxl); library(jsonlite);

log_threshold(logger::INFO)
log_info <- logger::log_info

source("src/data_processing/process_substitutions_auto.R")

cat("=== Testing Substitutions Processing in ARC Environment ===\n")

result_list <- main_substitutions_processing()
audit_log <- result_list$audit

if (!is.null(audit_log)) {
  cat("\n✅ Substitutions processing test PASSED!\n")
} else {
  cat("\n❌ Substitutions processing test FAILED! See logs for details.\n")
}

cat("\n=== End Substitutions Test ===\n")
