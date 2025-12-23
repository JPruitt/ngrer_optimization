---
editor_options: 
  markdown: 
    wrap: 80
---

# NGRER Phase 1 Week 2: File I/O Specifications - Standardized Data Ingestion Procedures

## **Detailed Implementation Plan**

Based on the comprehensive SAS code analysis and technical requirements, here's
the detailed plan to implement standardized data ingestion procedures for the
NGRER R system:

--------------------------------------------------------------------------------

## **1. Data Source Architecture Analysis**

### **Primary Data Sources Identified** (Source: ngrerSasCodeComplete.txt)

**A. SACS (Standard Army Command Structure) Data:** - Equipment Requirements
Files: `equipment_details` with columns `RUNID`, `UIC`, `EDATE`, `LIN`, `ERC`,
`RMK1`, `RMK2`, `RQEQP`, `AUEQP`, `RQBOI`, `AUBOI`, `SORCE`, `MDUIC` - Header
Files: `uic_header_details` with unit identification and DARPL priority data

**B. LDAC (Logistics Data Analysis Center) Inventory:** - Multi-sheet Excel
files: `AE2S_LIN_DATA_G8_NIIN_File_YYYYMMDD.xlsx` - Current inventory positions
by UIC and LIN

**C. LMDB (LIN Management Database):** - Equipment specifications:
`LINS_ACTIVE_YYYY-MM-DD.xlsx` - Substitution rules and modernization levels

**D. Financial Management Data:** - Procurement information: FDIIS LQA files
with delivery schedules

**E. LMI DST Transfer Data:** - Equipment transfer records for inter-component
movements

--------------------------------------------------------------------------------

## **2. Standardized File I/O Framework Implementation**

### **Core Data Ingestion Engine**

\`\`\`r \# R/data_processing/file_io_framework.R

\#' NGRER Standardized Data Ingestion Framework \#' \#' This module provides
standardized procedures for ingesting all NGRER data sources \#' with
comprehensive validation, error handling, and audit trail capabilities.

library(data.table) library(readxl) library(logger) library(yaml)

# Initialize data ingestion system

initialize_data_ingestion_system \<- function(config_path =
"config/ngrer_config.yaml") {

config \<- yaml::read_yaml(config_path)

\# Setup logging for data ingestion operations log_info("Initializing NGRER data
ingestion system")

\# Create data ingestion audit table ingestion_audit \<- data.table( timestamp =
character(), data_source = character(), file_name = character(),
records_processed = integer(), validation_status = character(), errors =
character(), processing_time = numeric() )

return(list( config = config, audit_table = ingestion_audit, validation_rules =
load_validation_rules(), file_specifications = load_file_specifications() )) }

# Load file specifications based on SAS implementation analysis

load_file_specifications \<- function() {

file_specs \<- list(

```         
# SACS Equipment Details Specification
sacs_equipment = list(
  description = "SACS Equipment Requirements Data",
  file_pattern = "equipment_details*.txt",
  delimiter = "\t",  # Tab-delimited based on SAS code analysis
  expected_columns = c("RUNID", "UIC", "EDATE", "LIN", "ERC", "RMK1", "RMK2", 
                      "RQEQP", "AUEQP", "RQBOI", "AUBOI", "SORCE", "MDUIC"),
  column_types = list(
    RUNID = "integer",
    UIC = "character",
    EDATE = "Date", 
    LIN = "character",
    ERC = "character",
    RMK1 = "character",
    RMK2 = "character",
    RQEQP = "numeric",
    AUEQP = "numeric", 
    RQBOI = "numeric",
    AUBOI = "numeric",
    SORCE = "integer",
    MDUIC = "character"
  ),
  validation_rules = c("validate_uic_format", "validate_lin_format", 
                      "validate_erc_values", "validate_quantities"),
  processing_function = "process_sacs_equipment_data"
),

# SACS Header Specification  
sacs_header = list(
  description = "SACS Unit Header Information",
  file_pattern = "uic_header*.txt", 
  delimiter = "\t",
  expected_columns = c("RUNID", "UIC", "EDATEI", "TPSN", "MACOM", "ACTCO", 
                      "ADCCO", "MDEP", "COMPO", "UNTDS", "CARSS", "TYPCO", 
                      "UNMBR", "FPA", "DAMPL", "SRC", "ALO", "SRCPARA", 
                      "ASGMT", "LOCCO", "AMSCO", "BRNCH", "CCNUM", "DOCNO", 
                      "DPMNT", "ELSEQ", "FORCO", "MBCMD", "MBLOC", "MBPRD", 
                      "MBSTA", "MTOEC", "NTREF", "PHASE", "ROBCO", "ROC", 
                      "STACO", "TDATE", "ULCCC", "UTC", "COP_BDE_TYPE", "THEATER"),
  processing_function = "process_sacs_header_data"
),

# LDAC Inventory Specification
ldac_inventory = list(
  description = "LDAC Equipment Inventory Data",
  file_pattern = "AE2S_LIN_DATA_G8_NIIN_File_*.xlsx",
  file_type = "xlsx",
  sheet_names = c("Sheet 1", "Sheet 2", "Sheet 3"),  # Based on SAS analysis
  expected_columns = c("LIN", "UIC", "COMPO", "QTY", "CONDITION_CODE", 
                      "REPORTING_DATE", "SERIAL_NUMBER"),
  processing_function = "process_ldac_inventory_data"
),

# LMDB LIN Master Data
lmdb_master = list(
  description = "LMDB LIN Master Data", 
  file_pattern = "LINS_ACTIVE_*.xlsx",
  file_type = "xlsx",
  sheet_name = "LINS_Active",
  expected_columns = c("LIN", "NOMENCLATURE", "MAJOR_CAPABILITY_NAME", 
                      "LIN_FAMILY_NAME", "PUC", "MOD_LEVEL", "Portfolio", 
                      "SSO_OFFICE_SYMBOL"),
  processing_function = "process_lmdb_master_data"
),

# Financial Management Procurement Data
fdiis_lqa = list(
  description = "FDIIS LQA Procurement Data",
  file_pattern = "*.xlsx",
  file_type = "xlsx", 
  sheet_name = "AE2S_CURRENT_POSITION",
  expected_columns = c("LIN", "COMPO", "FY", "QTY", "COST", "DELIVERY_DATE"),
  processing_function = "process_fdiis_procurement_data"
),

# LMI DST Transfer Data
lmi_dst = list(
  description = "LMI DST Equipment Transfer Data",
  file_pattern = "LMI_DST_PSDs*.xlsx", 
  file_type = "xlsx",
  expected_columns = c("FROM_UIC", "TO_UIC", "LIN", "QTY", "TRANSFER_DATE", 
                      "TRANSFER_TYPE"),
  processing_function = "process_lmi_dst_data"
),

# SB 700-20 Substitution Rules
sb_700_20 = list(
  description = "SB 700-20 Substitution Rules",
  file_pattern = "SB_700_20_*.xlsx",
  file_type = "xlsx",
  sheet_names = c("SB_700_20_CHAPTERS", "SB_700_20_APPENDIX_H"), 
  expected_columns = c("LIN", "LIN_NAME", "SUBLIN", "SUB_NAME", "SOURCE"),
  processing_function = "process_substitution_rules_data"
),

# DARPL Priority Data
darpl_priority = list(
  description = "DARPL Unit Priority Rankings",
  file_pattern = "DARPL_*.xlsx",
  file_type = "xlsx",
  expected_columns = c("UIC", "COMPO", "DARPL_RANK", "FY"),
  processing_function = "process_darpl_priority_data"
)
```

)

return(file_specs) }

# Universal file ingestion function with comprehensive error handling

ingest_data_file \<- function(file_path, data_source_name, ingestion_system) {

start_time \<- Sys.time()

log_info("Starting ingestion of {data_source_name}: {file_path}")

\# Get file specification for this data source file_spec \<-
ingestion_system\$file_specifications[[data_source_name]]

if (is.null(file_spec)) { stop("No file specification found for data source:
{data_source_name}") }

tryCatch({

```         
# Determine file type and call appropriate reader
if (file_spec$file_type == "xlsx" || tools::file_ext(file_path) == "xlsx") {
  data <- ingest_excel_file(file_path, file_spec)
} else {
  data <- ingest_delimited_file(file_path, file_spec)
}

# Validate data structure
validation_results <- validate_data_structure(data, file_spec, data_source_name)

if (!validation_results$passed) {
  log_error("Data validation failed for {data_source_name}: {validation_results$errors}")
  return(create_ingestion_failure_result(file_path, data_source_name, validation_results$errors))
}

# Apply data transformations
processed_data <- apply_data_transformations(data, file_spec, data_source_name)

# Record successful ingestion
end_time <- Sys.time()
processing_time <- as.numeric(difftime(end_time, start_time, units = "secs"))

audit_record <- create_audit_record(
  file_path = file_path,
  data_source = data_source_name,
  records_processed = nrow(processed_data),
  validation_status = "PASSED",
  errors = "",
  processing_time = processing_time
)

log_info("Successfully ingested {nrow(processed_data)} records from {data_source_name} in {round(processing_time, 2)} seconds")

return(list(
  success = TRUE,
  data = processed_data,
  audit_record = audit_record,
  metadata = extract_file_metadata(file_path, processed_data)
))
```

}, error = function(e) {

```         
log_error("Error ingesting {data_source_name} from {file_path}: {e$message}")

return(create_ingestion_failure_result(file_path, data_source_name, e$message))
```

}) }

# Excel file ingestion with multi-sheet support

ingest_excel_file \<- function(file_path, file_spec) {

if (!file.exists(file_path)) { stop("File not found: {file_path}") }

\# Handle multi-sheet Excel files (like LDAC inventory) if ("sheet_names" %in%
names(file_spec)) {

```         
combined_data <- list()

for (sheet_name in file_spec$sheet_names) {
  
  log_info("Reading sheet: {sheet_name}")
  
  sheet_data <- readxl::read_excel(
    path = file_path,
    sheet = sheet_name,
    guess_max = 10000,  # Ensure proper column type detection
    .name_repair = "universal"
  )
  
  # Add sheet identifier
  sheet_data$source_sheet <- sheet_name
  combined_data[[sheet_name]] <- sheet_data
}

# Combine all sheets using rbind
if (length(combined_data) > 1) {
  data <- data.table::rbindlist(combined_data, fill = TRUE, use.names = TRUE)
} else {
  data <- data.table::as.data.table(combined_data[[1]])
}
```

} else { \# Single sheet processing sheet_name \<- file_spec\$sheet_name %\|\|%
1 \# Default to first sheet

```         
data <- readxl::read_excel(
  path = file_path,
  sheet = sheet_name,
  guess_max = 10000,
  .name_repair = "universal"
)

data <- data.table::as.data.table(data)
```

}

return(data) }

# Delimited file ingestion (tab, comma, pipe separated)

ingest_delimited_file \<- function(file_path, file_spec) {

if (!file.exists(file_path)) { stop("File not found: {file_path}") }

delimiter \<- file_spec\$delimiter %\|\|% "\t" \# Default to tab-delimited

\# Use data.table::fread for high performance reading data \<-
data.table::fread( file = file_path, sep = delimiter, header = TRUE, na.strings
= c("", "NA", "NULL", "."), strip.white = TRUE, fill = TRUE, blank.lines.skip =
TRUE )

return(data) }

# Comprehensive data validation framework

validate_data_structure \<- function(data, file_spec, data_source_name) {

validation_errors \<- character()

\# Check if data is empty if (nrow(data) == 0) { validation_errors \<-
c(validation_errors, "No data records found in file") }

\# Validate required columns exist if ("expected_columns" %in% names(file_spec))
{ missing_columns \<- setdiff(file_spec\$expected_columns, names(data)) if
(length(missing_columns) \> 0) { validation_errors \<- c(validation_errors,
paste("Missing required columns:", paste(missing_columns, collapse = ", "))) } }

\# Apply data type validations if specified if ("column_types" %in%
names(file_spec)) { type_errors \<- validate_column_types(data,
file_spec\$column_types) validation_errors \<- c(validation_errors, type_errors)
}

\# Apply business rule validations if ("validation_rules" %in% names(file_spec))
{ business_rule_errors \<- apply_business_rule_validations(data,
file_spec\$validation_rules, data_source_name) validation_errors \<-
c(validation_errors, business_rule_errors) }

\# Return validation results if (length(validation_errors) \> 0) { return(list(
passed = FALSE, errors = paste(validation_errors, collapse = "; ") )) } else {
return(list( passed = TRUE, errors = "" )) } }

# Business rule validation functions

apply_business_rule_validations \<- function(data, validation_rules,
data_source) {

errors \<- character()

if ("validate_uic_format" %in% validation_rules) { uic_errors \<-
validate_uic_format(data) errors \<- c(errors, uic_errors) }

if ("validate_lin_format" %in% validation_rules) { lin_errors \<-
validate_lin_format(data) errors \<- c(errors, lin_errors) }

if ("validate_erc_values" %in% validation_rules) { erc_errors \<-
validate_erc_values(data) errors \<- c(errors, erc_errors) }

if ("validate_quantities" %in% validation_rules) { quantity_errors \<-
validate_quantity_values(data) errors \<- c(errors, quantity_errors) }

\# Data source specific validations if (data_source == "sacs_equipment") {
sacs_errors \<- validate_sacs_specific_rules(data) errors \<- c(errors,
sacs_errors) }

if (data_source == "ldac_inventory") { ldac_errors \<-
validate_ldac_specific_rules(data) errors \<- c(errors, ldac_errors) }

return(errors) }

# UIC format validation based on Army standards

validate_uic_format \<- function(data) {

errors \<- character()

if ("UIC" %in% names(data)) { \# UIC should be 6 characters invalid_length \<-
nchar(as.character(data\$UIC)) != 6

```         
if (any(invalid_length, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid UIC format detected:", 
                           sum(invalid_length, na.rm = TRUE), "records with incorrect length"))
}

# UIC format validation based on SAS patterns
# First character should be W for most Active Army units, A for ARNG, etc.
invalid_format <- !grepl("^[WAR][A-Z0-9]{5}$", data$UIC)

if (any(invalid_format, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid UIC format pattern:", 
                           sum(invalid_format, na.rm = TRUE), "records"))
}
```

}

return(errors) }

# LIN format validation (Source: ngrerSasCodeComplete.txt)

validate_lin_format \<- function(data) {

errors \<- character()

if ("LIN" %in% names(data)) { \# LIN should be exactly 6 characters alphanumeric
invalid_lin_length \<- nchar(as.character(data\$LIN)) != 6

```         
if (any(invalid_lin_length, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid LIN length:", 
                           sum(invalid_lin_length, na.rm = TRUE), "records"))
}

# LIN should contain only alphanumeric characters
invalid_lin_chars <- !grepl("^[A-Z0-9]{6}$", toupper(data$LIN))

if (any(invalid_lin_chars, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid LIN character format:", 
                           sum(invalid_lin_chars, na.rm = TRUE), "records"))
}
```

}

return(errors) }

# ERC validation (P, A, S codes from SAS analysis)

validate_erc_values \<- function(data) {

errors \<- character()

if ("ERC" %in% names(data) \|\| "ERCS" %in% names(data)) { erc_col \<- if ("ERC"
%in% names(data)) "ERC" else "ERCS"

```         
valid_erc_values <- c("P", "A", "S")  # Primary, Augmentation, School
invalid_erc <- !toupper(data[[erc_col]]) %in% valid_erc_values

if (any(invalid_erc, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid ERC values:", 
                           sum(invalid_erc, na.rm = TRUE), "records with invalid codes"))
}
```

}

return(errors) }

# Quantity validation

validate_quantity_values \<- function(data) {

errors \<- character()

quantity_columns \<- intersect(names(data), c("RQEQP", "AUEQP", "QTY", "REQD",
"INV"))

for (col in quantity_columns) { \# Check for negative quantities negative_qty
\<- data[[col]] \< 0

```         
if (any(negative_qty, na.rm = TRUE)) {
  errors <- c(errors, paste("Negative quantities in", col, ":", 
                           sum(negative_qty, na.rm = TRUE), "records"))
}

# Check for unreasonably large quantities (potential data entry errors)
large_qty <- data[[col]] > 100000

if (any(large_qty, na.rm = TRUE)) {
  errors <- c(errors, paste("Potentially invalid large quantities in", col, ":", 
                           sum(large_qty, na.rm = TRUE), "records exceeding 100,000"))
}
```

}

return(errors) }

# SACS-specific validation rules

validate_sacs_specific_rules \<- function(data) {

errors \<- character()

\# DARPL priority validation (should be 1-4) if ("DARPL" %in% names(data)) {
invalid_darpl \<- !data$DARPL %in% 1:4 & !is.na(data$DARPL)

```         
if (any(invalid_darpl)) {
  errors <- c(errors, paste("Invalid DARPL priorities:", 
                           sum(invalid_darpl), "records with values outside 1-4 range"))
}
```

}

\# Component validation if ("COMPO" %in% names(data)) { valid_compos \<- c("1",
"2", "3", "6", "01", "02", "03", "06") \# Active, Guard, Reserve, Other
invalid_compo \<- !data\$COMPO %in% valid_compos

```         
if (any(invalid_compo, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid component codes:", 
                           sum(invalid_compo, na.rm = TRUE), "records"))
}
```

}

\# Source code validation if ("SORCE" %in% names(data)) { invalid_source \<-
!data\$SORCE %in% 1:10 \# Typical source code range

```         
if (any(invalid_source, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid source codes:", 
                           sum(invalid_source, na.rm = TRUE), "records"))
}
```

}

return(errors) }

# LDAC-specific validation rules

validate_ldac_specific_rules \<- function(data) {

errors \<- character()

\# Condition code validation if ("CONDITION_CODE" %in% names(data)) {
valid_conditions \<- c("A", "B", "C", "D", "F", "H", "X") \# Standard Army
condition codes invalid_condition \<- !toupper(data\$CONDITION_CODE) %in%
valid_conditions

```         
if (any(invalid_condition, na.rm = TRUE)) {
  errors <- c(errors, paste("Invalid condition codes:", 
                           sum(invalid_condition, na.rm = TRUE), "records"))
}
```

}

\# Reporting date validation if ("REPORTING_DATE" %in% names(data)) {
future_dates \<- data\$REPORTING_DATE \> Sys.Date()

```         
if (any(future_dates, na.rm = TRUE)) {
  errors <- c(errors, paste("Future reporting dates detected:", 
                           sum(future_dates, na.rm = TRUE), "records"))
}
```

}

return(errors) }

# Column type validation and conversion

validate_column_types \<- function(data, expected_types) {

type_errors \<- character()

for (col_name in names(expected_types)) { if (col_name %in% names(data)) {
expected_type \<- expected_types[[col_name]]

```         
  # Attempt type conversion and validation
  conversion_result <- attempt_type_conversion(data[[col_name]], expected_type, col_name)
  
  if (!conversion_result$success) {
    type_errors <- c(type_errors, conversion_result$error_message)
  }
}
```

}

return(type_errors) }

# Type conversion with error handling

attempt_type_conversion \<- function(column_data, target_type, column_name) {

tryCatch({

```         
conversion_success <- TRUE
error_message <- ""

if (target_type == "numeric") {
  # Check if conversion to numeric is possible
  converted_data <- as.numeric(as.character(column_data))
  na_introduced <- sum(is.na(converted_data)) > sum(is.na(column_data))
  
  if (na_introduced) {
    conversion_success <- FALSE
    error_message <- paste("Column", column_name, "contains non-numeric values")
  }
  
} else if (target_type == "integer") {
  converted_data <- as.integer(as.character(column_data))
  na_introduced <- sum(is.na(converted_data)) > sum(is.na(column_data))
  
  if (na_introduced) {
    conversion_success <- FALSE
    error_message <- paste("Column", column_name, "contains non-integer values")
  }
  
} else if (target_type == "Date") {
  # Attempt multiple date formats
  date_formats <- c("%Y-%m-%d", "%m/%d/%Y", "%d%b%Y")
  conversion_successful <- FALSE
  
  for (fmt in date_formats) {
    test_conversion <- as.Date(as.character(column_data), format = fmt)
    if (sum(!is.na(test_conversion)) > sum(!is.na(column_data)) * 0.8) {
      conversion_successful <- TRUE
      break
    }
  }
  
  if (!conversion_successful) {
    conversion_success <- FALSE
    error_message <- paste("Column", column_name, "contains invalid date formats")
  }
}

return(list(
  success = conversion_success,
  error_message = error_message
))
```

}, error = function(e) { return(list( success = FALSE, error_message =
paste("Type conversion error for column", column_name, ":", e\$message) )) }) }

# Data transformation pipeline

apply_data_transformations \<- function(data, file_spec, data_source_name) {

log_info("Applying data transformations for {data_source_name}")

\# Apply source-specific transformations if (data_source_name ==
"sacs_equipment") { data \<- transform_sacs_data(data) } else if
(data_source_name == "ldac_inventory") { data \<- transform_ldac_data(data) }
else if (data_source_name == "lmdb_master") { data \<- transform_lmdb_data(data)
} else if (data_source_name == "fdiis_lqa") { data \<-
transform_fdiis_data(data) }

\# Apply standard transformations data \<- apply_standard_transformations(data)

return(data) }

# SACS-specific transformations (based on SAS code patterns)

transform_sacs_data \<- function(data) {

\# Uppercase LIN codes (Source: ngrerSasCodeComplete.txt shows lin =
upcase(LIN)) if ("LIN" %in% names(data)) { data$LIN <- toupper(data$LIN) }

\# Uppercase UIC codes if ("UIC" %in% names(data)) {
data$UIC <- toupper(data$UIC) }

\# Uppercase ERC codes if ("ERC" %in% names(data) \|\| "ERCS" %in% names(data))
{ erc_col \<- if ("ERC" %in% names(data)) "ERC" else "ERCS" data[[erc_col]] \<-
toupper(data[[erc_col]]) }

\# Convert component codes to standardized format if ("COMPO" %in% names(data))
{ data$COMPO <- standardize_component_codes(data$COMPO) }

\# Handle date columns if ("EDATE" %in% names(data)) {
data$EDATE <- standardize_dates(data$EDATE) }

return(data) }

# LMDB transformations (including substitution rule processing)

transform_lmdb_data \<- function(data) {

\# Uppercase LIN codes if ("LIN" %in% names(data)) {
data$LIN <- toupper(data$LIN) }

\# Process substitution columns (Source: ngrerSasCodeComplete.txt substitution
rule logic) substitution_columns \<- c("REPLACED_by1", "REPLACED_by2",
"REPLACED_by3", "REPLACED_by4", "REPLACED_by5", "REPLACES1", "REPLACES2",
"REPLACES3", "REPLACES4", "REPLACES5")

for (col in substitution_columns) { if (col %in% names(data)) { data[[col]] \<-
toupper(data[[col]]) \# Remove empty strings data[[col]][data[[col]] == ""] \<-
NA } }

\# Filter based on modernization level (Source: mod_level\>2 filter in SAS) if
("MOD_LEVEL" %in% names(data)) { data \<-
data[data$MOD_LEVEL > 2 | is.na(data$MOD_LEVEL), ] }

return(data) }

# Standard transformations applied to all data sources

apply_standard_transformations \<- function(data) {

\# Convert character columns to proper case where appropriate character_columns
\<- sapply(data, is.character)

for (col_name in names(character_columns)[character_columns]) { \# Trim
whitespace data[[col_name]] \<- trimws(data[[col_name]])

```         
# Replace empty strings with NA
data[[col_name]][data[[col_name]] == ""] <- NA
```

}

\# Standardize numeric precision numeric_columns \<- sapply(data, is.numeric)

for (col_name in names(numeric_columns)[numeric_columns]) { \# Round to
appropriate precision to avoid floating point issues if (any(data[[col_name]] %%
1 != 0, na.rm = TRUE)) { \# Has decimal values, round to 10 decimal places for
precision data[[col_name]] \<- round(data[[col_name]], 10) } }

return(data) }

# Component code standardization

standardize_component_codes \<- function(compo_codes) {

\# Standardize component codes based on SAS logic standardized \<-
character(length(compo_codes))

for (i in seq_along(compo_codes)) { code \<- as.character(compo_codes[i])

```         
# Handle various component code formats
if (code %in% c("1", "01", "11")) {
  standardized[i] <- "11"  # Active Army
} else if (code %in% c("2", "02", "21")) {
  standardized[i] <- "21"  # Army National Guard
} else if (code %in% c("3", "03", "31")) {
  standardized[i] <- "31"  # Army Reserve
} else if (code %in% c("6", "06", "61")) {
  standardized[i] <- "61"  # Army Prepositioned Stock
} else {
  # Keep original code if not recognized
  standardized[i] <- code
}
```

}

return(standardized) }

# Date standardization function

standardize_dates \<- function(date_column) {

\# Handle multiple date formats commonly found in SACS data standardized_dates
\<- as.Date(NA)

for (i in seq_along(date_column)) { date_str \<- as.character(date_column[i])

```         
# Try different date formats
date_formats <- c("%Y%m%d", "%m/%d/%Y", "%Y-%m-%d", "%d%b%Y")

for (fmt in date_formats) {
  parsed_date <- tryCatch({
    as.Date(date_str, format = fmt)
  }, error = function(e) NA)
  
  if (!is.na(parsed_date)) {
    standardized_dates[i] <- parsed_date
    break
  }
}
```

}

return(standardized_dates) }

# Create audit record for successful ingestion

create_audit_record \<- function(file_path, data_source, records_processed,
validation_status, errors, processing_time) {

audit_record \<- data.table( timestamp = Sys.time(), data_source = data_source,
file_name = basename(file_path), file_path = file_path, records_processed =
records_processed, validation_status = validation_status, errors = errors,
processing_time_seconds = processing_time, file_size_mb =
round(file.size(file_path) / (1024\^2), 2), file_modified_date =
file.mtime(file_path), r_session_info = paste(R.version.string, collapse = " "),
user_id = Sys.info()["user"], system_info = paste(Sys.info()["sysname"],
Sys.info()["release"]) )

return(audit_record) }

# Create failure result for ingestion errors

create_ingestion_failure_result \<- function(file_path, data_source_name,
error_message) {

failure_audit \<- data.table( timestamp = Sys.time(), data_source =
data_source_name, file_name = basename(file_path), records_processed = 0,
validation_status = "FAILED", errors = error_message, processing_time_seconds =
0 )

return(list( success = FALSE, data = NULL, audit_record = failure_audit,
error_details = error_message )) }

# Extract file metadata

extract_file_metadata \<- function(file_path, processed_data) {

file_info \<- file.info(file_path)

metadata \<- list( file_name = basename(file_path), file_size_bytes =
file_info$size,  file_size_mb = round(file_info$size / (1024\^2), 2),
file_created = file_info$ctime,  file_modified = file_info$mtime, records_count
= nrow(processed_data), columns_count = ncol(processed_data), column_names =
names(processed_data), data_types = sapply(processed_data, class),
memory_usage_mb = round(object.size(processed_data) / (1024\^2), 2) )

return(metadata) }

# Batch file processing function

process_data_source_batch \<- function(data_source_name, file_directory,
ingestion_system) {

log_info("Starting batch processing for data source: {data_source_name}")

\# Get file specification file_spec \<-
ingestion_system\$file_specifications[[data_source_name]]

if (is.null(file_spec)) { stop("No file specification found for data source:
{data_source_name}") }

\# Find files matching the pattern file_pattern \<- file_spec\$file_pattern
matching_files \<- list.files(path = file_directory, pattern =
glob2rx(file_pattern), full.names = TRUE)

if (length(matching_files) == 0) { log_warn("No files found matching pattern
{file_pattern} in directory {file_directory}") return(list( success = FALSE,
message = "No matching files found", files_processed = 0 )) }

log_info("Found {length(matching_files)} files to process for
{data_source_name}")

\# Process each file batch_results \<- list() successful_files \<- 0
failed_files \<- 0

for (file_path in matching_files) {

```         
log_info("Processing file: {basename(file_path)}")

file_result <- ingest_data_file(file_path, data_source_name, ingestion_system)

if (file_result$success) {
  successful_files <- successful_files + 1
} else {
  failed_files <- failed_files + 1
}

batch_results[[basename(file_path)]] <- file_result
```

}

log_info("Batch processing complete for {data_source_name}: {successful_files}
successful, {failed_files} failed")

\# Combine successful data if multiple files if (successful_files \> 1) {
combined_data \<- combine_batch_data(batch_results) } else if (successful_files
== 1) { successful_result \<- batch_results[[which(sapply(batch_results,
function(x) x$success))[1]]]  combined_data <- successful_result$data } else {
combined_data \<- NULL }

return(list( success = successful_files \> 0, files_processed =
length(matching_files), successful_files = successful_files, failed_files =
failed_files, individual_results = batch_results, combined_data = combined_data,
processing_summary = create_batch_processing_summary(batch_results) )) }

# Combine data from multiple files

combine_batch_data \<- function(batch_results) {

successful_results \<- batch_results[sapply(batch_results, function(x)
x\$success)]

if (length(successful_results) == 0) { return(NULL) }

\# Extract data from successful results data_list \<- lapply(successful_results,
function(x) x\$data)

\# Combine using rbindlist for efficiency combined_data \<-
data.table::rbindlist(data_list, fill = TRUE, use.names = TRUE)

\# Add source file tracking for (i in seq_along(data_list)) { file_name \<-
names(successful_results)[i] start_row \<- ifelse(i == 1, 1,
sum(sapply(data_list[1:(i-1)], nrow)) + 1) end_row \<- start_row +
nrow(data_list[[i]]) - 1

```         
combined_data[start_row:end_row, source_file := file_name]
```

}

return(combined_data) }

# Create batch processing summary

create_batch_processing_summary \<- function(batch_results) {

summary \<- list( total_files = length(batch_results), successful_files =
sum(sapply(batch_results, function(x)
x$success)),  failed_files = sum(sapply(batch_results, function(x) !x$success)),
total_records = sum(sapply(batch_results, function(x) { if
(x$success && !is.null(x$data))
nrow(x$data) else 0  })),  total_processing_time = sum(sapply(batch_results, function(x) {  if (!is.null(x$audit_record))
x$audit_record$processing_time_seconds else 0 })), error_summary =
compile_error_summary(batch_results) )

return(summary) }

# Compile error summary from batch results

compile_error_summary \<- function(batch_results) {

failed_results \<- batch_results[sapply(batch_results, function(x) !x\$success)]

if (length(failed_results) == 0) { return("No errors encountered") }

error_summary \<- data.table( file_name = names(failed_results), error_message =
sapply(failed_results, function(x) x\$error_details %\|\|% "Unknown error"),
stringsAsFactors = FALSE )

return(error_summary) }

# Null coalescing operator

`%||%` \<- function(x, y) { if (is.null(x) \|\| length(x) == 0 \|\| (length(x)
== 1 && is.na(x))) { y } else { x } }

# Validation rule loading

load_validation_rules \<- function() {

validation_rules \<- list(

```         
# UIC validation patterns
uic_patterns = list(
  active_army = "^W[A-Z0-9]{5}$",
  national_guard = "^[A-Z][0-9]{5}$",
  army_reserve = "^[A-Z][A-Z0-9]{5}$",
  general_format = "^[A-Z0-9]{6}$"
),

# LIN validation patterns  
lin_patterns = list(
  standard_format = "^[A-Z0-9]{6}$",
  numeric_only = "^[0-9]{6}$",
  alpha_numeric = "^[A-Z][0-9]{5}$"
),

# Component code mappings
component_mappings = list(
  active_army = c("1", "01", "11"),
  national_guard = c("2", "02", "21"), 
  army_reserve = c("3", "03", "31"),
  prepositioned = c("6", "06", "61")
),

# Valid ERC codes
valid_erc_codes = c("P", "A", "S"),

# DARPL priority range
darpl_priority_range = 1:4,

# Quantity validation thresholds
quantity_thresholds = list(
  minimum = 0,
  maximum = 100000,
  warning_threshold = 50000
)
```

)

return(validation_rules) }

log_info("File I/O specifications framework implementation completed
successfully")
