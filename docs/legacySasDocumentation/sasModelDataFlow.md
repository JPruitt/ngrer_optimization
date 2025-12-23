# NGRER Optimization Model Data Flow Analysis

Based on the comprehensive SAS code provided, here is a complete breakdown of all required inputs, interim files, and outputs for the NGRER (Next Generation Readiness Enhancement Review) optimization model.

## Required Inputs

### 1. Primary Data Sources
- **LMDB (Logistics Modernization Database)**
  - `lmdb_&lmdb_month` dataset containing LIN data, nomenclature, and pricing information
  - `subrules_final` - LIN-to-LIN substitution relationships
  - `lins` - Active LIN master list

- **SACS (Standard Army Command System) Files**
  - `cla_header_roll[date].txt` - Unit header information 
  - `cla_eqpdet_roll[date].txt` - Equipment detail requirements
  - Contains: UIC, LIN, ERC, required quantities, authorized quantities

- **Inventory Data (LDAC)**
  - `AE2S_LIN_DATA_G8_NIIN_File_[date]` - Current equipment on-hand by unit
  - `inventory_by_uic` - Unit-level inventory positions

- **Procurement Data**
  - `_fdiis_lqa_prt1` - Future equipment deliveries by fiscal year
  - Financial management files with procurement schedules

### 2. Configuration Files
- **DARPL Priority Data**
  - `CUI_[date]_FY25_DARPL_Update.xlsx` - Equipment priority classifications
  - Unit priority assignments for allocation decisions

- **Transfer Data (LMI)**
  - `LMI_DST_PSDs [date]` - Inter-component transfer schedules
  - `LMI_XFER_REMOVE` - Equipment transfers out
  - `LMI_XFER_ADD` - Equipment transfers in

### 3. Reference Files
  - `SB_700_20_CHAPTERS_[date]` - Technical manual references
  - `units` - Master unit listing with component assignments
  - `compos` - Component definitions (Active, Guard, Reserve, etc.)
  - `ercs` - Equipment Readiness Code definitions

## Interim Files by Processing Step

### Step 1: Input Data Processing (`generate_opt_model_inputs.sas`)
**Generated Files:**
- `idm_i.requirements` - Standardized requirements data
- `idm_i.inventory` - Standardized inventory data  
- `idm_i.procurements` - Standardized procurement data
- `idm_i.darpl` - Priority data
- `idm_i.sub_rules` - Substitution rules
- `idm_i.units_compo_number` - Unit-to-component mapping
- `idm_i.dates` - Analysis timeframe dates
- `idm_i.study_timeframe` - First and last analysis years
- `idm_i.compo_transfer` - Valid transfer relationships
- `idm_i.fill_target` - Target fill percentage (typically 1.0)
- `idm_i.subs_to_ignore` - Substitution sources to exclude

### Step 2: Cluster Generation (`generate_clusters.sas`)
**Generated Files:**
- `clusters` - LIN groupings for optimization processing
- `idm_i.clusters&cluster_tag` - Final cluster assignments
- `distinct_components` - Unique components to process
- `good_clusters` - Valid clusters with inventory data
- `lins_inv` - LINs with associated inventory/requirements

### Step 3: Optimization Processing (`model_optimization_nosubs.sas`)
**Component-Level Interim Files (created for each component):**
- `inventory_&working_comp` - Component inventory data
- `requirements_&working_comp` - Component requirements
- `procurements_&working_comp` - Component procurements
- `P_assigned_&working_comp` - ERC P assignments
- `A_assigned_&working_comp` - ERC A assignments
- `P_shortage_&working_comp` - ERC P shortages
- `A_shortage_&working_comp` - ERC A shortages
- `P_onhand_&working_comp` - ERC P on-hand positions
- `A_onhand_&working_comp` - ERC A on-hand positions

### Step 4: Report Generation (`generate_reports_NGRER_new.sas`)
**Analysis Files:**
- `add_ml_to_inv` - Inventory with mod-level data
- `sum_inv_to_lin_ml` - Aggregated inventory by mod-level
- `onhand_xtab_ml` - Transposed on-hand data by mod-level
- `TAEDP_ERC1` - Equipment readiness summary data

## Final Outputs and Results

### 1. **Primary Optimization Results** (Located in `idm_o` library)

#### **Key Decision Variables:**
- **`idm_o.assigned`** - Equipment assignments from inventory
  - Fields: modeling_dates, compos, units, lins, ercs, assign
- **`idm_o.shortage`** - Equipment shortfalls by unit and LIN  
  - Fields: modeling_dates, compos, units, lins, ercs, shortage
- **`idm_o.subbed`** - Substitution assignments (when allowed)
  - Fields: modeling_dates, compos, units, lins, sublins, ercs, sub_assign
- **`idm_o.xferred`** - Inter-component transfers
  - Fields: modeling_dates, to_compos, from_compos, units, lins, ercs, compo_transfer

#### **Inventory Positions:**
- **`idm_o.inv_positions`** - Final inventory positions with requirements and shortages
  - Fields: modeling_dates, compos, units, lins, ercs, reqd, onhand, shortages, total_excess

### 2. **Readiness Analysis Outputs**
- **`idm_o.TAEDP_ERC1`** - Equipment readiness by component and LIN
  - Includes Equipment On-Hand (EOH) percentages
  - Equipment ratings (1, 2, Below standards)
  - Component categories (AC, ARNG, USAR, etc.)

### 3. **Run Documentation**
- **`idm_o.Run_Parameters`** - Complete record of run settings and parameters
- **`idm_o.component_stats`** - Processing statistics by component

### 4. **Excel Deliverables** (Generated by `write_ngrer_reports.sas`)
- **Component-specific reports** using Excel DDE connections
- **Summary charts and tables** for stakeholder briefings
- **Equipment readiness dashboards**

### 5. **Performance Metrics**
- **Dollar value of shortages** by component and priority
- **Transfer volumes** between Army components  
- **Equipment fill rates** by major capability
- **Critical vs. non-critical shortages** (ERC P vs. ERC A)

## Critical Output Validation Metrics

### **Data Quality Checks:**
1. Total requirements = Total assignments + Total shortages
2. No negative inventory values
3. Transfers respect component rules
4. Substitution assignments follow modernization rules

### **Key Performance Indicators:**
- **EOH Percentage by Component** - Primary readiness metric
- **Shortage Cost Analysis** - Financial impact assessment  
- **Transfer Efficiency** - Optimization of inter-component moves
- **Critical Equipment Status** - ERC P items meeting 89.5% fill target

The optimization model produces a comprehensive equipment allocation solution that maximizes Army-wide readiness while respecting component priorities, transfer constraints, and equipment substitution rules. The final outputs enable detailed analysis of equipment shortfalls, optimal inventory positioning, and resource allocation decisions across the total Army enterprise.

