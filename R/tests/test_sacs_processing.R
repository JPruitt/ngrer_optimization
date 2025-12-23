# R/tests/unit/test_sacs_processing.R

rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

library(dplyr); library(readr); library(stringr); library(logger); library(scales);

log_threshold(logger::INFO)
log_info <- logger::log_info

source("src/data_processing/process_sacs_auto.R")

cat("=== Testing SACS Processing (Final, Definitive Version) ===\n")

result_list <- main_sacs_processing()
result <- result_list$sacs_data

if (!is.null(result) && nrow(result) > 0) {
  cat("\n✅ SACS processing test PASSED!\n")
} else {
  cat("\n❌ SACS processing test FAILED!\n")
}
