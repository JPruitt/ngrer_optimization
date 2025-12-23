# R/tests/unit/test_ldac_processing.R
# This script remains the same as your Windows version.

rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

# Load required libraries
library(dplyr); library(readxl); library(stringr); library(logger); library(scales);

# Source the LDAC processing script
source("src/data_processing/process_ldac_auto.R")

cat("=== Testing LDAC Processing ===\n")

# Call the main wrapper function
result <- main_ldac_processing()

if (!is.null(result) && !is.null(result$ldac_data) && nrow(result$ldac_data) > 0) {
  cat("\n✅ LDAC processing test PASSED!\n")
} else {
  cat("\n❌ LDAC processing test FAILED!\n")
}
