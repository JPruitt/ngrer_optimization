# NGRER Optimization Model: Complete Assumptions and Business Rules

Based on the comprehensive analysis of the SAS code, here is a complete listing of all assumptions and business rules built into the NGRER optimization model:

## Data and Time Frame Assumptions

### Analysis Period
- **Multi-year analysis span**: Model analyzes equipment allocation across 7 fiscal years (FY 2025-2031)
- **Annual snapshots**: Equipment positions are evaluated on an annual basis
- **Forward-looking procurement**: Future equipment deliveries are incorporated into allocation decisions
- **Status date consistency**: All input data must align to the same reference date for validity

### Data Currency Requirements
- **LMDB data**: Must be from the most recent month available
- **SACS requirements**: Must match the analysis timeframe
- **Inventory positions**: Must reflect current on-hand status
- **Substitution rules**: Based on Army regulations and technical manuals (SB 700-20)

## Equipment Classification and Priority Rules

### Equipment Readiness Codes (ERC)
- **ERC P (Primary)**: Critical equipment items that directly impact unit readiness
- **ERC A (Additional)**: Important but non-critical equipment items
- **Priority hierarchy**: ERC P shortages are filled before ERC A shortages through objective function weighting

### Modernization Level (ML) Constraints
- **ML3+ requirement**: Only equipment with modernization level 3 or higher is considered for allocation (Source: ngrerSasCodeComplete.txt)
- **Modernization preference**: Newer equipment (higher ML) is preferred over older equipment
- **Substitution modernization rule**: Lower ML equipment cannot substitute for higher ML equipment when modern_subs toggle is enabled

### Fill Target Standards
- **100% fill target**: Model attempts to achieve 100% equipment fill rates where possible (fill_target = 1.0)
- **89.5% critical threshold**: Special focus on achieving 89.5% fill for critical equipment categories
- **Ceiling function**: Requirements are rounded up using ceiling function to ensure no fractional assignments

## Component and Unit Allocation Rules

### Army Component Structure
- **Component segregation**: Active Army (AC), Army National Guard (ARNG), and Army Reserve (USAR) are treated as separate entities
- **Component priority**: DARPL (Director of Army Resources Priority List) priorities determine allocation precedence
- **Unit-level granularity**: Allocations are made at the individual unit identification code (UIC) level

### Inter-Component Transfer Rules
- **Configurable transfers**: Component-to-component transfers can be enabled or disabled
- **Transfer penalties**: Economic penalties discourage unnecessary inter-component moves
- **Valid transfer relationships**: Only authorized component transfer pairs are permitted
- **Cascade timing**: Transfers are restricted before a user-specified cascade year (CASC_YEAR)

## Substitution Business Rules

### Substitution Authority Hierarchy
1. **SB 700-20 (Technical Manual)**: Highest authority (Source: "1-SB_700_20")
2. **REPLACES relationships**: Secondary authority (Source: "3-REPLACES") 
3. **REPLACED relationships**: Lower authority (Source: "4-REPLACED")
4. **In-lieu-of substitutions**: Sources 7+ are generally prohibited

### Substitution Constraints
- **Major capability alignment**: Substitutions only allowed within the same major capability area
- **Modernization restrictions**: Less modern equipment cannot substitute for more modern equipment
- **User-configurable exclusions**: Specific substitution sources can be disabled (subs_to_ignore parameter)
- **No self-substitution**: Equipment cannot substitute for itself (LIN ≠ SubLIN)

### Substitution Scenarios
- **Full substitution allowed**: When subs_allowed = 1
- **No substitutions**: When subs_allowed = 0, all substitution variables are fixed to zero
- **Modern substitutions only**: When modern_subs = 1, restricts to modernization-appropriate substitutions

## Inventory Management Rules

### Inventory Flow Logic
- **Current inventory + Procurements = Available inventory** for each component
- **First year constraints**: Initial inventory positions can be frozen if freeze_first_two = 1
- **Cumulative procurement**: Procurements are accumulated from first year through current year
- **Transfer accounting**: Transfers in and transfers out are tracked cumulatively

### Excess Inventory Handling
- **Modernization-weighted penalties**: More modern excess inventory receives higher penalties to encourage assignment
  - ML5 equipment: Highest penalty (&mod_5_e_pen)
  - ML4 equipment: High penalty (&mod_4_e_pen)
  - ML3 equipment: Medium penalty (&mod_3_e_pen)
  - ML2 equipment: Low penalty (&mod_2_e_pen)
  - ML1 equipment: Minimal penalty (&mod_1_e_pen)

### Inventory Relaxation
- **Feasibility protection**: Model can add virtual inventory (add_inv) to prevent infeasibility
- **Configurable flexibility**: Inventory relaxation can be disabled (fix_flex = 1) for stricter constraints

## Optimization Objective and Penalties

### Primary Objective
**Minimize total weighted shortages** across all units, equipment items, and time periods

### Penalty Structure
1. **ERC P shortage penalty**: &p_pri (highest priority)
2. **ERC A shortage penalty**: &a_pri (lower priority)  
3. **Transfer penalties**: &trans_pen (discourages unnecessary moves)
4. **Substitution penalties**: &sub_assign_pen (small penalty = 0.01)
5. **Excess inventory penalties**: Modernization-level dependent
6. **Component transfer penalties**: &unit_yearly_xfer_pen

## Clustering and Processing Rules

### Component Clustering
- **LIN-based clustering**: Equipment items (LINs) are grouped into clusters for computational efficiency
- **Component processing**: Each Army component cluster is processed independently
- **Processing criteria**: Clusters must have inventory, requirements, or procurement activity to be processed

### Processing Logic Validation
```
Process cluster if: (inventory > 0) OR (requirements > 0) OR (procurements > 0) OR (transfers_in > 0) OR (transfers_out > 0)
```

## Constraint Framework

### Inventory Balance Constraints
**For each year, component, and LIN:**
```
Assignments + Substitution Assignments + Excess = Available Inventory + Procurements ± Transfers
```

### Shortage Definition Constraints
**For each unit requirement:**
```
Shortage + Direct Assignment + Substitution Assignment = Ceiling(Fill_Target × Requirement)
```

### Transfer Feasibility
- **Non-negative transfers**: All transfer quantities must be ≥ 0
- **Integer constraints**: All decision variables are integer-valued
- **Component capacity**: Transfers cannot exceed available inventory in source component

## Special Operating Modes

### NGRER-Specific Rules
- **NGRER_RUN_TOGGLE = 1**: Disables assignment of ML1 and ML2 inventory
- **Component-specific runs**: Single component processing available via single_component parameter
- **LMI data integration**: Logistics Modernization Initiative transfer data can be incorporated

### Feasibility and Robustness
- **Decision variable fixing**: Zero-requirement scenarios have corresponding variables fixed to zero
- **Substitution source filtering**: Problematic substitution authorities can be excluded
- **Component validation**: Empty or invalid components are skipped during processing

## Output and Validation Rules

### Solution Validation Requirements
1. **Mass balance**: Total requirements = Total assignments + Total shortages
2. **Non-negative inventory**: No negative inventory positions allowed
3. **Transfer compliance**: All transfers respect component authorization rules
4. **Substitution appropriateness**: All substitutions follow Army regulations

### Key Performance Metrics
- **Equipment On-Hand (EOH) percentages**: Primary readiness metric by component
- **Shortage cost analysis**: Dollar value impact assessment
- **Transfer efficiency**: Optimization of inter-component moves
- **Critical equipment status**: ERC P items meeting fill targets

These business rules and assumptions collectively ensure that the NGRER optimization model produces Army-compliant equipment allocation solutions that maximize readiness while respecting operational constraints and Army regulations.