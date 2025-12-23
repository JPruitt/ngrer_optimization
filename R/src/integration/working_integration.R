# R/src/integration/working_integration.R
# NGRER Master Data Integration Pipeline (Stable Baseline - Corrected Final Join Logic)
#
# Author: NGRER Development Team
# Last Modified: [Current Date]

# --- 1. Load Libraries ---
library(dplyr); library(readr); library(stringr); library(logger);
library(readxl); library(lubridate); library(jsonlite); library(tidyr);

# --- 2. Main Integration Function ---
#' @export
integrate_ngrer_data <- function(output_dir = "~/ngrer_optimization/data/intermediate",
                                 log_root = "~/ngrer_optimization/logs") {
  
  start_run_time <- Sys.time()
  start_time_str <- format(start_run_time, "%Y%m%d_%H%M%S")
  error_log_path <- file.path(log_root, "errors", paste0("error_log_", start_time_str, ".log"))
  dir.create(dirname(error_log_path), recursive = TRUE, showWarnings = FALSE)
  
  full_audit <- list(); performance_log <- list(); warnings_list <- list()
  
  tryCatch({
    
    log_info("--- Sourcing all data processing scripts ---")
    source("src/data_processing/process_sacs_auto.R")
    source("src/data_processing/process_ldac_auto.R")
    source("src/data_processing/process_lmdb_auto.R")
    source("src/data_processing/process_fdiis_auto.R")
    source("src/data_processing/process_darpl_auto.R")
    source("src/data_processing/process_substitutions_auto.R")
    source("src/data_processing/process_transfers_auto.R")
    
    log_info("--- Executing individual data processors ---")
    sacs_result <- main_sacs_processing(); sacs_clean <- sacs_result$sacs_data
    ldac_result <- main_ldac_processing(); ldac_clean <- ldac_result$ldac_data
    lmdb_result <- main_lmdb_processing(); lmdb_clean <- lmdb_result$lmdb_data
    fdiis_result <- main_fdiis_processing(); fdiis_clean <- fdiis_result$fdiis_data
    darpl_result <- main_darpl_processing(); darpl_clean <- darpl_result$darpl_data
    subs_result <- main_substitutions_processing(); subs_clean <- subs_result$substitution_data
    transfers_result <- main_transfers_processing(); transfers_clean <- transfers_result$transfer_data
    
    # --- Final Integration (RE-ENGINEERED FOR ROBUSTNESS) ---
    log_info("--- Master Integration: Joining all clean data sources ---")
    
    # Step 1: Explicitly ensure join keys are characters across all tables
    sacs_clean <- sacs_clean %>% mutate(uic = as.character(uic), lin = as.character(lin))
    ldac_clean <- ldac_clean %>% mutate(lin = as.character(lin))
    darpl_clean <- darpl_clean %>% mutate(uic = as.character(uic))
    fdiis_clean <- fdiis_clean %>% mutate(lin_in = as.character(lin_in), lin_out = as.character(lin_out))
    
    # Step 2: Create summaries
    ldac_summary <- ldac_clean %>%
      group_by(lin) %>%
      summarise(total_on_hand = sum(on_hand_qty, na.rm=TRUE), .groups="drop")
    
    fdiis_summary <- fdiis_clean %>%
      select(lin_in, lin_out, amount) %>%
      pivot_longer(cols = c(lin_in, lin_out), names_to = "lin_type", values_to = "lin") %>%
      filter(!is.na(lin) & lin != "") %>%
      group_by(lin) %>%
      summarise(total_funding = sum(amount, na.rm=TRUE), .groups="drop")
    
    # Step 3: Perform hardened joins
    final_data <- sacs_clean %>%
      left_join(ldac_summary, by = "lin") %>%
      mutate(total_on_hand = replace_na(total_on_hand, 0)) %>% # Immediately handle NAs from join
      
      left_join(darpl_clean, by = "uic") %>%
      mutate(darpl_rank = replace_na(darpl_rank, 99999)) %>% # Assign a low-priority default
      
      left_join(fdiis_summary, by = "lin") %>%
      mutate(total_funding = replace_na(total_funding, 0)) %>% # Immediately handle NAs
      
      mutate(shortfall = pmax(0, rqeqp - total_on_hand)) # Now this calculation is safe
    
    # --- Final Audit & Save ---
    log_info("--- Final Audit & Save ---")
    full_audit$final_output_summary <- list(
      final_rows = nrow(final_data), unique_uics = n_distinct(final_data$uic),
      unique_lins = n_distinct(final_data$lin), total_required = sum(final_data$rqeqp),
      total_on_hand = sum(ldac_summary$total_on_hand), # Correct calculation from summary
      total_shortfall = sum(final_data$shortfall)
    )
    
    audit_log_path <- tempfile() 
    perf_log_path <- tempfile()
    
    write_json(full_audit, audit_log_path, auto_unbox = TRUE, pretty = TRUE)
    write_json(performance_log, perf_log_path, auto_unbox = TRUE, pretty = TRUE)
    
    saveRDS(final_data, file.path(output_dir, "intermediate_R_results_R.rds"))
    saveRDS(subs_clean, file.path(output_dir, "substitutions_R_results.rds"))
    
    if(length(warnings_list) == 0) { cat("Pipeline completed successfully with no critical errors.", file = error_log_path) }
    else { cat("Pipeline completed with warnings:\n", paste(sapply(warnings_list, conditionMessage), collapse="\n\n"), file = error_log_path) }
    
    return(list(final_data = final_data, audit = full_audit))
    
  }, error = function(e) {
    log_error("CRITICAL PIPELINE FAILURE: {e$message}")
    cat(paste("Timestamp:", Sys.time(), "\nError:", e$message, "\nTraceback:\n", paste(capture.output(rlang::trace_back()), collapse="\n")),
        file = error_log_path)
    return(NULL)
  })
}
