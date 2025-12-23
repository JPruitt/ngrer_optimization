# R/src/clustering/generate_clusters.R
# Graph-Based Clustering of Equipment LINs
#
# Purpose: Decomposes the optimization problem by grouping substitutable
#          equipment (LINs) into connected clusters.
#
# Author: NGRER Development Team
# Last Modified: [Current Date] (Corrected column names in graph building)

library(dplyr)
library(igraph)
library(logger)

# Setup logging functions
logger::log_threshold(logger::INFO)
log_info <- logger::log_info
log_warning <- logger::log_warn
log_error <- logger::log_error

#' Generate equipment clusters based on substitution rules
#'
#' @param integrated_data The main integrated dataset containing all requirements and LINs.
#' @param substitution_rules A dataframe of substitution rules (PRIMARY_LIN_CLEAN, SUBSTITUTE_LIN_CLEAN).
#' @param output_dir Directory for saving the cluster output.
#' @return A dataframe with LINs mapped to their respective cluster IDs.
#'
#' @export
generate_clusters <- function(integrated_data, substitution_rules, output_dir = "../data/intermediate/clustering") {
  
  log_info("Starting equipment clustering process...")
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # 1. Identify all unique, relevant LINs from the integrated data
  relevant_lins <- unique(integrated_data$LIN_CLEAN)
  log_info("Identified {length(relevant_lins)} unique LINs from the integrated dataset.")
  
  # 2. Build the substitution graph
  log_info("Building substitution network graph...")
  sub_graph <- build_substitution_graph(substitution_rules, relevant_lins)
  
  # 3. Find connected components (clusters)
  log_info("Identifying connected components (clusters)...")
  components <- igraph::components(sub_graph)
  
  cluster_assignments <- data.frame(
    LIN_CLEAN = V(sub_graph)$name,
    CLUSTER_ID = components$membership,
    stringsAsFactors = FALSE
  )
  
  # 4. Analyze and summarize the clusters
  cluster_summary <- cluster_assignments %>%
    group_by(CLUSTER_ID) %>%
    summarise(
      CLUSTER_SIZE = n(),
      LINS_IN_CLUSTER = paste(sort(LIN_CLEAN), collapse = ", ")
    ) %>%
    arrange(desc(CLUSTER_SIZE))
  
  log_info("Found {nrow(cluster_summary)} total clusters.")
  log_info("Largest cluster contains {max(cluster_summary$CLUSTER_SIZE)} LINs.")
  
  # 5. Join cluster information back to the main data
  final_cluster_data <- cluster_assignments %>%
    left_join(cluster_summary, by = "CLUSTER_ID")
  
  # 6. Save the results
  save_path_rds <- file.path(output_dir, "lin_cluster_assignments.rds")
  save_path_csv <- file.path(output_dir, "lin_cluster_assignments.csv")
  
  saveRDS(final_cluster_data, save_path_rds)
  write_csv(final_cluster_data, save_path_csv)
  log_info("Saved cluster assignments to {output_dir}")
  
  return(final_cluster_data)
}


#' Build a graph from substitution rules - CORRECTED FUNCTION
#'
#' @param substitution_rules A dataframe with 'PRIMARY_LIN_CLEAN' and 'SUBSTITUTE_LIN_CLEAN'.
#' @param relevant_lins A vector of all LINs to be included in the graph.
#' @return An igraph graph object.
build_substitution_graph <- function(substitution_rules, relevant_lins) {
  
  # *** CORRECTED THIS SECTION to use the proper column names ***
  edges <- substitution_rules %>%
    filter(PRIMARY_LIN_CLEAN %in% relevant_lins, SUBSTITUTE_LIN_CLEAN %in% relevant_lins) %>%
    select(from = PRIMARY_LIN_CLEAN, to = SUBSTITUTE_LIN_CLEAN) %>%
    distinct()
  
  # Create the graph from the edge list and the full list of LINs (vertices)
  g <- graph_from_data_frame(d = edges, directed = FALSE, vertices = relevant_lins)
  
  log_info("Created graph with {vcount(g)} vertices (LINs) and {ecount(g)} edges (substitutions).")
  return(g)
}
