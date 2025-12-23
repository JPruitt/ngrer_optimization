# R/tests/unit/test_clustering.R
# Standalone Test Script for Equipment Clustering - ARC/Linux Version
#
# Author: NGRER Development Team

# --- 1. Setup Environment ---
rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

# Load required libraries
library(dplyr)
library(igraph)
library(logger)
library(readr)
library(scales)

# Setup logging
logger::log_threshold(logger::INFO)

# --- 2. Source and Execute Script ---
source("src/clustering/generate_clusters.R")

cat("=== Testing Equipment Clustering in ARC Environment ===\n")
cat("Working directory:", getwd(), "\n\n")

# --- 3. Load Prerequisites ---
cat("Loading prerequisite data (integrated dataset and substitution rules)...\n")

integrated_data_path <- "../data/intermediate/integrated/ngrer_integrated_dataset.rds"
sub_rules_path <- "../data/intermediate/r_processing/substitutions/substitutions_processed_latest.rds"

if (!file.exists(integrated_data_path) || !file.exists(sub_rules_path)) {
  stop("Prerequisite files not found. Please run the full integration test first.")
}

integrated_data <- readRDS(integrated_data_path)
substitution_rules <- readRDS(sub_rules_path)

cat("✓ Loaded", scales::comma(nrow(integrated_data)), "integrated records.\n")
cat("✓ Loaded", scales::comma(nrow(substitution_rules)), "substitution rules.\n")

# --- 4. Execute Clustering ---
cat("\nRunning generate_clusters()...\n")
cluster_results <- NULL
tryCatch({
  cluster_results <- generate_clusters(
    integrated_data = integrated_data,
    substitution_rules = substitution_rules
  )
}, error = function(e) {
  log_error("Clustering script failed: {e$message}")
  print(e)
})

# --- 5. Validate and Summarize Results ---
if (!is.null(cluster_results) && nrow(cluster_results) > 0) {
  cat("\n✅ Clustering test PASSED!\n")
  
  total_clusters <- n_distinct(cluster_results$CLUSTER_ID)
  total_lins_clustered <- n_distinct(cluster_results$LIN_CLEAN)
  
  cat("✅ Generated", scales::comma(total_clusters), "clusters for", scales::comma(total_lins_clustered), "LINs.\n")
  
  # Cluster Size Distribution
  cluster_size_summary <- cluster_results %>%
    group_by(CLUSTER_ID) %>%
    summarise(CLUSTER_SIZE = n()) %>%
    ungroup() %>%
    count(CLUSTER_SIZE, name = "NUM_CLUSTERS", sort = TRUE)
  
  cat("\n--- Cluster Size Distribution ---\n")
  print(head(cluster_size_summary, 10))
  
  # Information about the largest cluster
  largest_cluster <- cluster_results %>%
    filter(CLUSTER_SIZE == max(CLUSTER_SIZE))
  
  cat("\n--- Largest Cluster Details ---\n")
  cat("✓ Largest cluster ID:", largest_cluster$CLUSTER_ID[1], "\n")
  cat("✓ Number of LINs in largest cluster:", max(cluster_results$CLUSTER_SIZE), "\n")
  cat("✓ Sample LINs from largest cluster:", paste(head(largest_cluster$LIN_CLEAN, 5), collapse = ", "), "...\n")
  
} else {
  cat("\n❌ Clustering test FAILED. Review the logs above.\n")
}

cat("\n=== End Clustering Test ===\n")
