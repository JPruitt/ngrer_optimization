# NGRER Data Directory Input Files Requirements

## **Primary Data Sources (data/input/)**

### **SACS (Standard Army Command Structure) - data/input/sacs/**
- `cla_eqpdet_roll[YYYYMMDD].txt` - Equipment details file
- `cla_header_roll[YYYYMMDD].txt` - Unit header information file

**Example files:**
- `cla_eqpdet_roll20250811.txt`
- `cla_header_roll20250811.txt`

### **LDAC (Logistics Data Analysis Center) - data/input/ldac/**
- `AE2S_LIN_DATA_G8_NIIN_File_[YYYYMMDD].xlsx` - Multi-sheet inventory file
  - Sheet 1, Sheet 2, Sheet 3 (combined during processing)

**Example file:**
- `AE2S_LIN_DATA_G8_NIIN_File_20250811.xlsx`

### **LMDB (LIN Management Database) - data/input/lmdb/**
- `LINS_ACTIVE_[YYYY-MM-DD].xlsx` - Master LIN database with substitution rules
  - Sheet: "LINS_Active"

**Example file:**
- `LINS_ACTIVE_2025-08-11.xlsx`

### **FDIIS-LQA (Procurement Data) - data/input/fdiis/**
- `AE2S_CURRENT_POSITION_[YYYYMMDD].xlsx` - Procurement and financial data
  - Sheet: "AE2S_CURRENT_POSITION"

**Example file:**
- `AE2S_CURRENT_POSITION_20250811.xlsx`

### **DARPL Priority Data - data/input/darpl/**
- `CUI_[YYYYMMDD]_RPT_DARPL_RELEASE_FY[YYYY].xlsx` - Unit priority rankings

**Example file:**
- `CUI_20250811_RPT_DARPL_RELEASE_FY2025.xlsx`

### **Substitution Rules - data/input/substitutions/**
- `SB_700_20_APPENDIX_H_[YYYY-MM-DD].xlsx` - Army regulation substitution rules
- `SB_700_20_CHAPTERS_[YYYY-MM-DD].xlsx` - Supplementary substitution data

**Example files:**
- `SB_700_20_APPENDIX_H_2025-08-11.xlsx`
- `SB_700_20_CHAPTERS_2025-08-11.xlsx`

### **LMI Transfer Data - data/input/transfers/**
- `LMI_DST_PSDs [MM-DD-YY].xlsx` - Planned equipment transfers

**Example file:**
- `LMI_DST_PSDs 8-7-25.xlsx`
