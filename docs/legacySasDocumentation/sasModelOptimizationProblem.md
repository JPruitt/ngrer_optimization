## **Complete Mathematical Model Formulation**

### **Mixed-Integer Linear Programming Model**

**Decision Variables:** - $x_{c,u,l,e,d}$ = quantity of LIN $l$ at modernization
level $e$ allocated to unit $u$ in component $c$ for year $d$ - $s_{c,u,l,e,d}$
= quantity of substitutions from higher modernization levels - $h_{c,u,l,e,d}$ =
shortage quantity (unmet requirements) - $t_{c_1,c_2,l,e,d}$ = inter-component
transfers from component $c_1$ to $c_2$

**Objective Function:**
$$\min \sum_{c,u,l,e,d} \text{DARPL}[c,u] \times h_{c,u,l,e,d} + \sum_{transfers} \text{TransferPenalty} \times t_{c_1,c_2,l,e,d}$$

**Critical Constraints:**

1.  **Inventory Conservation:**
    $$\sum_{u,e} x_{c,u,l,e,d} + \sum_{c_2} t_{c,c_2,l,e,d} \leq I_{c,l,e,d} + \sum_{c_1} t_{c_1,c,l,e,d}$$

2.  **Requirement Satisfaction:**
    $$x_{c,u,l,e,d} + s_{c,u,l,e,d} + h_{c,u,l,e,d} = R_{c,u,l,e,d}$$

3.  **Substitution Constraints:**
    $$s_{c,u,l,e,d} \leq \sum_{l' \in Sub(l)} x_{c,u,l',e',d}$$ where $Sub(l)$
    represents valid substitutes for LIN $l$

4.  **Non-negativity:**
    $$x_{c,u,l,e,d}, s_{c,u,l,e,d}, h_{c,u,l,e,d}, t_{c_1,c_2,l,e,d} \geq 0$$

5.  **Integer Constraints:** All decision variables must be non-negative
    integers representing discrete equipment units.

**R Implementation Framework:**

``` r
# R/optimization/mathematical_model.R
formulate_ngrer_milp <- function(requirements, inventory, substitutions, penalties) {
  
  # Create decision variable index mapping
  variable_mapping <- create_variable_mapping(requirements, inventory)
  
  # Build objective function coefficients
  objective_coeffs <- create_objective_coefficients(
    variable_mapping = variable_mapping,
    darpl_penalties = penalties$darpl,
    transfer_penalties = penalties$transfer
  )
  
  # Build constraint matrix
  constraint_matrix <- create_constraint_matrix(
    requirements = requirements,
    inventory = inventory,
    substitutions = substitutions,
    variable_mapping = variable_mapping
  )
  
  # Create bounds and variable types
  variable_bounds <- create_variable_bounds(variable_mapping)
  variable_types <- rep("I", length(objective_coeffs))  # Integer variables
  
  return(list(
    objective = objective_coeffs,
    constraints = constraint_matrix,
    bounds = variable_bounds,
    types = variable_types,
    variable_mapping = variable_mapping
  ))
}

# Solve using ROI framework
solve_ngrer_optimization <- function(milp_model, solver = "lpSolve") {
  
  library(ROI)
  
  # Create optimization problem
  opt_problem <- OP(
    objective = L_objective(milp_model$objective),
    constraints = milp_model$constraints,
    bounds = milp_model$bounds,
    types = milp_model$types,
    maximum = FALSE
  )
  
  # Solve with specified solver
  solution <- ROI_solve(opt_problem, solver = solver)
  
  # Process and format results
  formatted_results <- process_optimization_solution(
    solution = solution,
    variable_mapping = milp_model$variable_mapping
  )
  
  return(formatted_results)
}
```