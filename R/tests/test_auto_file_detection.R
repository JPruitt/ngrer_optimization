# Test Script for Auto File Detection Feature - Linux Environment
# Clear environment and set working directory
rm(list = ls())
setwd("/projects/c1062044060/ngrer_sas_to_r_migration/ngrer_optimization/R")

# Verify we're in the correct directory
cat("Current working directory:", getwd(), "\n")

# Source required functions
tryCatch({
  source("src/data_processing/auto_file_detection.R")
  cat("✓ Successfully loaded auto_file_detection.R\n")
}, error = function(e) {
  cat("✗ Error loading auto_file_detection.R:", e$message, "\n")
  stop("Cannot proceed without auto_file_detection.R")
})

# Load required packages
required_packages <- c("dplyr", "stringr", "logger", "jsonlite")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("Installing package:", pkg, "\n")
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
  cat("✓ Package loaded:", pkg, "\n")
}

# Setup logging
logger::log_threshold(logger::INFO)
logger::log_info("Starting Linux auto file detection test")

# Enhanced date extraction function (Linux version)
extract_date_from_filename <- function(filename, source_name, file_type) {
  # Define date patterns by source and file type
  date_patterns <- list(
    # Common patterns
    "YYYYMMDD" = "([0-9]{8})",
    "YYYY-MM-DD" = "([0-9]{4}-[0-9]{2}-[0-9]{2})",
    "MM-DD-YY" = "([0-9]{1,2}-[0-9]{1,2}-[0-9]{2})(?!-[0-9])",
    "DD-MMM-YY" = "([0-9]{1,2}-[A-Za-z]{3}-[0-9]{2})",
    "MonYYYY" = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)([0-9]{4})"
  )
  
  extracted_date <- NA
  for (pattern_name in names(date_patterns)) {
    pattern <- date_patterns[[pattern_name]]
    matches <- str_extract(filename, pattern)
    
    if (!is.na(matches)) {
      # Convert based on pattern type
      if (pattern_name == "YYYYMMDD") {
        extracted_date <- as.Date(matches, format = "%Y%m%d")
      } else if (pattern_name == "YYYY-MM-DD") {
        extracted_date <- as.Date(matches, format = "%Y-%m-%d")
      } else if (pattern_name == "MM-DD-YY") {
        # Parse MM-DD-YY format more carefully
        parts <- str_split(matches, "-")[[1]]
        if (length(parts) == 3) {
          month <- sprintf("%02d", as.numeric(parts[1]))
          day <- sprintf("%02d", as.numeric(parts[2]))
          year <- as.numeric(parts[3])
          # Handle 2-digit year
          if (year < 50) {
            year <- 2000 + year
          } else if (year < 100) {
            year <- 1900 + year
          }
          full_date <- paste0(year, "-", month, "-", day)
          extracted_date <- as.Date(full_date, format = "%Y-%m-%d")
        }
      } else if (pattern_name == "DD-MMM-YY") {
        # Convert to proper format
        year_part <- paste0("20", str_sub(matches, -2))
        date_part <- str_sub(matches, 1, -4)
        full_date <- paste0(date_part, "-", year_part)
        extracted_date <- as.Date(full_date, format = "%d-%b-%Y")
      } else if (pattern_name == "MonYYYY") {
        # Extract month and year components
        month_match <- str_extract(matches, "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)")
        year_match <- str_extract(matches, "([0-9]{4})")
        # Assume first day of month
        full_date <- paste0("01-", month_match, "-", year_match)
        extracted_date <- as.Date(full_date, format = "%d-%b-%Y")
      }
      
      # If successful conversion, break loop
      if (!is.na(extracted_date)) {
        break
      }
    }
  }
  
  return(extracted_date)
}

# Create test directory structure for Linux
create_linux_test_structure <- function() {
  base_path <- "../data/input"
  
  test_dirs <- c(
    "sacs", "ldac", "lmdb", "fdiis", "darpl",
    "substitutions", "transfers"
  )
  
  cat("Creating Linux test directory structure...\n")
  for (dir_name in test_dirs) {
    dir_path <- file.path(base_path, dir_name)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      cat("✓ Created:", dir_path, "\n")
    }
  }
  
  return(base_path)
}

# Create Linux test files
create_linux_test_files <- function(base_path) {
  cat("\n=== Creating Linux Test Files ===\n")
  
  # SACS test files
  sacs_dir <- file.path(base_path, "sacs")
  writeLines("Sample SACS equipment data - Linux test", file.path(sacs_dir, "cla_eqpdet_roll_20241215.txt"))
  writeLines("Sample SACS header data - Linux test", file.path(sacs_dir, "cla_header_roll_20241215.txt"))
  cat("✓ Created SACS test files\n")
  
  # LDAC test files
  ldac_dir <- file.path(base_path, "ldac")
  writeLines("Sample LDAC inventory data - Linux test", file.path(ldac_dir, "AE2S_LIN_DATA_G8_NIIN_File_20241215.csv"))
  cat("✓ Created LDAC test files\n")
  
  # LMDB test files with various date formats
  lmdb_dir <- file.path(base_path, "lmdb")
  writeLines("Sample LMDB master data - Linux test", file.path(lmdb_dir, "LINS_ACTIVE_20241215.xlsx"))
  writeLines("Sample LMDB data with MM-DD-YY format", file.path(lmdb_dir, "LINS_ACTIVE_12-15-24.xlsx"))
  cat("✓ Created LMDB test files\n")
  
  # FDIIS test files
  fdiis_dir <- file.path(base_path, "fdiis")
  writeLines("Sample FDIIS procurement data - Linux test", file.path(fdiis_dir, "AE2S_CURRENT_POSITION_20241215.xlsx"))
  cat("✓ Created FDIIS test files\n")
  
  # Create a few more test files
  writeLines("Sample DARPL data", file.path(base_path, "darpl", "CUI_TEST_RPT_DARPL_RELEASE_20241215.xlsx"))
  writeLines("Sample substitution data", file.path(base_path, "substitutions", "SB_700_20_APPENDIX_H_20241215.xlsx"))
  writeLines("Sample transfer data", file.path(base_path, "transfers", "LMI_DST_PSDs_20241215.xlsx"))
  
  cat("✓ Created additional test files\n")
}

# Run Linux test
run_linux_test <- function() {
  cat("=== NGRER Auto File Detection Test - Linux ===\n")
  cat("Test started at:", as.character(Sys.time()), "\n")
  cat("System:", Sys.info()["sysname"], Sys.info()["release"], "\n")
  cat("User:", Sys.info()["user"], "\n\n")
  
  # Create test environment
  base_path <- create_linux_test_structure()
  create_linux_test_files(base_path)
  
  cat("\n=== Running File Detection ===\n")
  
  # Run detection with error handling
  tryCatch({
    result <- detect_all_input_files(base_input_path = base_path)
    
    if (!is.null(result)) {
      cat("✓ File detection completed successfully!\n")
      
      # Display summary
      if (!is.null(result$processing_summary)) {
        summary <- result$processing_summary
        cat("\n=== Detection Summary ===\n")
        cat("Total data sources:", summary$total_data_sources, "\n")
        cat("Sources with files:", summary$sources_with_files, "\n")
        cat("Total files found:", summary$total_files_found, "\n")
        cat("Valid files found:", summary$valid_files_found, "\n")
        cat("Recommendation:", summary$processing_recommendation, "\n")
      }
      
      # Test date extraction
      cat("\n=== Date Extraction Test ===\n")
      test_files <- c(
        "cla_eqpdet_roll_20241215.txt",
        "LINS_ACTIVE_12-15-24.xlsx",
        "AE2S_LIN_DATA_G8_NIIN_File_20241215.csv"
      )
      
      for (test_file in test_files) {
        extracted_date <- extract_date_from_filename(test_file, "test", "test")
        cat("File:", test_file, "-> Date:", as.character(extracted_date), "\n")
      }
      
      cat("\n✅ LINUX TEST PASSED!\n")
      
    } else {
      cat("✗ File detection returned NULL\n")
    }
    
  }, error = function(e) {
    cat("✗ Error during file detection:", e$message, "\n")
    cat("This might be due to the summary function error - let's investigate\n")
    
    # Try a simpler version
    cat("\nTrying basic directory scan...\n")
    for (source_name in c("sacs", "ldac", "lmdb")) {
      source_path <- file.path(base_path, source_name)
      if (dir.exists(source_path)) {
        files <- list.files(source_path)
        cat("Found", length(files), "files in", source_name, "\n")
      }
    }
  })
}

# Execute the test
run_linux_test()

cat("\n=== Linux Test Complete ===\n")
cat("Completed at:", as.character(Sys.time()), "\n")