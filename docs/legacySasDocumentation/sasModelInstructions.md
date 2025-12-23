# NGRER Optimization Model - Complete User Instructions

## Overview
This guide provides step-by-step instructions for users with no SAS or model experience to run the NGRER (Next Generation Readiness Enhancement Review) optimization model from start to finish.

## Prerequisites

### Software Requirements
- SAS software installed on your computer
- Access to the required data libraries and file paths
- Sufficient disk space for temporary files and outputs

### Required Access
- Network access to the O: drive (specifically O:\G8_DATA\FD\17 FDA (Warfighting Analysis)\NGRER\)
- Read/write permissions to input and output directories

## Step 1: Prepare Your Environment

### 1.1 Set Up Directory Structure
1. Navigate to: `O:\G8_DATA\FD\17 FDA (Warfighting Analysis)\NGRER\Cycle\[CURRENT_FY]\`
2. Create the following subdirectories if they don't exist:
   - `OPT_Input\`
   - `OPT_Output\`
   - `Deliverables\`

### 1.2 Verify Required Input Data Sources
Ensure the following data sources are available and current:
- **LMDB (Logistics Modernization Database)**: Contains equipment LIN data, nomenclature, and pricing
- **SACS (Standard Army Command System)**: Contains unit requirements data
- **Inventory data**: Current equipment on-hand by unit
- **Procurement data**: Future equipment deliveries
- **DARPL priority data**: Equipment priority classifications
- **Substitution rules**: LIN-to-LIN substitution relationships

## Step 2: Configure Run Parameters

### 2.1 Open the Main SAS File
1. Launch SAS
2. Open the main optimization file (typically named similar to `Optimization_SubModule_[TYPE].sas`)

### 2.2 Set Key Macro Variables
Locate and modify these critical parameters at the top of the code:

```sas
%let current_cycle = FY25;          /* Set to current fiscal year cycle */
%let current_fy = 2025;             /* Set to current fiscal year */
%let Y1 = 2025;                     /* First year of analysis */
%let Y7 = 2031;                     /* Last year of analysis */
%let run_name = "YOUR_RUN_NAME";    /* Descriptive name for this run */
%let code_path = "PATH_TO_CODE";    /* Directory containing SAS programs */
%let Data_Output_Path = "OUTPUT_PATH"; /* Where results will be saved */
```

### 2.3 Set Analysis Options
Configure these flags based on your analysis needs:

```sas
%let run_all_inputs = 1;           /* 1 = regenerate inputs, 0 = use existing */
%let run_cluster = 1;              /* 1 = process clusters, 0 = skip */
%let subs_allowed = 1;             /* 1 = allow substitutions, 0 = no subs */
%let show_log = 0;                 /* 1 = display log, 0 = save to file */
%let single_component = 0;         /* Set to component number for single run */
```

## Step 3: Input Data Preparation

### 3.1 Verify Data Currency
1. Check that LMDB data is from the most recent month
2. Confirm SACS requirements data matches your analysis timeframe
3. Validate inventory data reflects current status date

### 3.2 Review Substitution Rules
1. Check the substitution rules in `lmdb.subrules_final`
2. Modify `idm_i.subs_to_ignore` if certain substitution sources should be excluded
3. Common sources to potentially ignore:
   - Source "3-" (REPLACES rules)
   - Source "4-" through "9-" (various rule types)

### 3.3 Configure Component Transfers
Review and modify transfer permissions in the code:
```sas
/* Example: Allow transfers from Active to Guard/Reserve */
data idm_i.xfer_additions;
    input to_compos $ from_compos $ valid;
    datalines;
2,1,1    /* ARNG can receive from Active */
3,1,1    /* USAR can receive from Active */
;
run;
```

## Step 4: Execute the Model

### 4.1 Run Input Generation (if needed)
If `run_all_inputs = 1`, the model will:
1. Process requirements data from SACS
2. Load current inventory positions
3. Import procurement schedules
4. Generate component clusters
5. Create optimization input datasets

### 4.2 Execute Optimization
The model will automatically:
1. Process each component cluster sequentially
2. Solve the optimization problem for inventory allocation
3. Generate shortage, excess, and transfer recommendations
4. Output detailed results to the specified directories

### 4.3 Monitor Progress
- Watch the SAS log for progress messages
- Look for "processing component X" messages
- Check for any error or warning messages
- The run may take several hours for large datasets

## Step 5: Review Outputs

### 5.1 Primary Output Datasets
The model generates these key result files in `idm_o` library:

- **shortage**: Equipment shortfalls by unit, LIN, and ERC
- **assigned**: Equipment assignments from inventory
- **subbed**: Substitution assignments (when allowed)
- **xferred**: Inter-component transfers
- **inv_positions**: Final inventory positions
- **Run_Parameters**: Complete record of run settings

### 5.2 Generate Reports
1. Execute the reporting modules:
   ```sas
   %include "&code_path\generate_reports_NGRER_new.sas";
   %include "&code_path\NGRER_Summary_reports.sas";
   ```

2. Run Excel output generation:
   ```sas
   %include "&code_path\write_ngrer_reports.sas";
   ```

### 5.3 Key Output Files
Look for these deliverables:
- **TAEDP_ERC1**: Equipment readiness summary by component
- **Excel reports**: Formatted charts and summary tables
- **Component-level analysis**: Detailed breakdowns by Army component

## Step 6: Validate Results

### 6.1 Sanity Checks
1. Verify total requirements equal total assignments plus shortages
2. Check that no negative inventory values exist
3. Confirm transfers respect component rules
4. Review substitution assignments for appropriateness

### 6.2 Review Key Metrics
- Equipment On-Hand (EOH) percentages by component
- Total dollar value of shortages
- Critical (ERC P) vs. non-critical shortages
- Transfer volumes between components

## Troubleshooting Common Issues

### Data Issues
- **Missing LINs**: Check LMDB currency and LIN validity
- **Zero requirements**: Verify SACS data completeness
- **Inventory mismatches**: Confirm status dates align

### Performance Issues
- **Long run times**: Consider using single_component mode for testing
- **Memory errors**: Check available disk space and SAS work library size
- **Failed optimization**: Review constraint feasibility and data quality

### Output Issues
- **Missing Excel files**: Verify Excel template path and DDE connections
- **Incomplete results**: Check log for component processing errors
- **Inconsistent totals**: Validate input data relationships

## Final Notes

1. **Save your work**: Copy all output files to a permanent location
2. **Document changes**: Record any parameter modifications made
3. **Archive run**: Save complete run parameters and key results
4. **Validate**: Have subject matter experts review critical results before distribution

This optimization model is complex and results should always be reviewed by personnel familiar with Army equipment management policies and procedures before being used for decision-making purposes.