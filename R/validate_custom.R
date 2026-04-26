# R/validate_custom.R
#
# Validation functions for BETYdb constraints that cannot be expressed in
# Frictionless Table Schema: cross-field arithmetic rules, conditional
# if/then rules, and cross-table lookup range checks.
#
# These implement the logic originally enforced by PostgreSQL CHECK constraints
# and trigger functions in the bety Rails application.
#
# The YAML file data-raw/custom_constraints.yaml is the single source of
# truth for what constraints exist and why. These functions interpret that file.

#' Load the custom constraints definition file
#'
#' @param path Path to custom_constraints.yaml. During development, this should
#'   point to data-raw/custom_constraints.yaml. After package installation,
#'   it points to system.file("extdata", "custom_constraints.yaml", package = "betydata").
#' @return A named list parsed from the YAML file.
#' @keywords internal
load_custom_constraints <- function(
    path = "data-raw/custom_constraints.yaml") {
  
  # Try development path first, then installed package path
  if (!file.exists(path)) {
    path <- system.file("extdata", "custom_constraints.yaml", package = "betydata")
  }
  
  if (!nzchar(path) || !file.exists(path)) {
    warning("custom_constraints.yaml not found at: ", path,
            " — skipping custom constraint validation")
    return(list())
  }
  
  yaml::read_yaml(path)
}

# ---------------------------------------------------------------------------
# Composite constraint runners (within a single table)
# ---------------------------------------------------------------------------

#' Run a sum_limit constraint
#'
#' Checks that the row-wise sum of specified columns does not exceed a value.
#' Example: sand_pct + clay_pct <= 100
#'
#' @param df data frame
#' @param con a single composite_constraint list element of type "sum_limit"
#' @return character vector of error messages (empty if all rows pass)
#' @keywords internal
run_sum_limit <- function(df, con) {
  cols <- con$columns
  present <- cols[cols %in% names(df)]
  if (length(present) == 0) return(character(0))

  row_sums <- rowSums(df[, present, drop = FALSE], na.rm = FALSE)

  # Only check rows where ALL columns are non-NA (skip rows with any NA)
  all_present <- rowSums(!is.na(df[, present, drop = FALSE])) == length(present)
  bad_rows <- which(all_present & row_sums > con$value)

  if (length(bad_rows) == 0) return(character(0))
  
  sprintf("[%s] %s (%d rows, indices: %s)",
          con$id, con$message, length(bad_rows),
          paste(head(bad_rows, 10), collapse = ", "))
}

#' Run a conditional constraint (if field A is set, field B must also be set)
#'
#' @param df data frame
#' @param con a single composite_constraint list element of type "conditional"
#' @return character vector of error messages (empty if all rows pass)
#' @keywords internal
run_conditional <- function(df, con) {
  if_col   <- con[["if"]][["column"]]
  then_col <- con[["then"]][["column"]]

  if (!all(c(if_col, then_col) %in% names(df))) return(character(0))

  if_cond   <- con[["if"]][["condition"]]
  then_cond <- con[["then"]][["condition"]]

  # Evaluate the IF trigger
  trigger <- switch(if_cond,
    "not_null" = {
      !is.na(df[[if_col]])
    },
    "not_null_and_not_empty" = {
      !is.na(df[[if_col]]) & nzchar(as.character(df[[if_col]]))
    },
    rep(FALSE, nrow(df))
  )

  # Evaluate the THEN requirement
  satisfied <- switch(then_cond,
    "not_null" = {
      !is.na(df[[then_col]])
    },
    "not_null_and_not_empty" = {
      !is.na(df[[then_col]]) & nzchar(as.character(df[[then_col]]))
    },
    rep(TRUE, nrow(df))
  )

  bad_rows <- which(trigger & !satisfied)
  if (length(bad_rows) == 0) return(character(0))
  
  sprintf("[%s] %s (%d rows, indices: %s)",
          con$id, con$message, length(bad_rows),
          paste(head(bad_rows, 10), collapse = ", "))
}

#' Run a unique_combination constraint
#'
#' Checks that no two rows share the same values in ALL specified columns.
#' Example: (name, specie_id) must be unique in cultivars.
#'
#' @param df data frame
#' @param con a single composite_constraint list element of type
#'   "unique_combination"
#' @return character vector of error messages (empty if all rows pass)
#' @keywords internal
run_unique_combination <- function(df, con) {
  cols <- con$columns
  present <- cols[cols %in% names(df)]
  if (length(present) == 0) return(character(0))

  dupes <- duplicated(df[, present, drop = FALSE]) |
           duplicated(df[, present, drop = FALSE], fromLast = TRUE)
  bad_rows <- which(dupes)

  if (length(bad_rows) == 0) return(character(0))
  
  sprintf("[%s] %s (%d rows, indices: %s)",
          con$id, con$message, length(bad_rows),
          paste(head(bad_rows, 10), collapse = ", "))
}

#' Dispatch and run all composite_constraints for a single table
#'
#' @param df data frame for the table being validated
#' @param constraints the composite_constraints list from the YAML for this table
#' @return character vector of all error messages
#' @keywords internal
run_composite_constraints <- function(df, constraints) {
  errors <- character(0)
  for (con in constraints) {
    result <- switch(con$type,
      "sum_limit"          = run_sum_limit(df, con),
      "conditional"        = run_conditional(df, con),
      "unique_combination" = run_unique_combination(df, con),
      "all_or_none"        = character(0),  # documented only; geometry handled elsewhere
      character(0)
    )
    errors <- c(errors, result)
  }
  errors
}

# ---------------------------------------------------------------------------
# Custom constraint runners (cross-table)
# ---------------------------------------------------------------------------

#' Run a conditional_range constraint (cross-table lookup)
#'
#' Checks that a column's values fall within the min/max bounds defined for
#' each row's linked record in another table. Replicates the logic of the
#' PostgreSQL restrict_trait_range trigger.
#'
#' OPTIMIZED: Uses vector operations and match() instead of merge() to avoid
#' creating large intermediate dataframes.
#'
#' @param df data frame for the table being validated (e.g. traitsview)
#' @param lookup_df data frame of the lookup table (e.g. variables)
#' @param con a single custom_constraint list element of type
#'   "conditional_range"
#' @return character vector of error messages (empty if all rows pass)
#' @keywords internal
run_conditional_range <- function(df, lookup_df, con) {
  val_col  <- con$column
  join_col <- con$join_on
  key_col  <- con$lookup$key_col
  min_col  <- con$lookup$min_col
  max_col  <- con$lookup$max_col
  null_ok  <- isTRUE(con$null_means_no_limit)

  if (!all(c(val_col, join_col) %in% names(df))) return(character(0))
  if (!all(c(key_col, min_col, max_col) %in% names(lookup_df))) return(character(0))

  # OPTIMIZATION: Use match() instead of merge() to look up bounds
  lookup_idx <- match(df[[join_col]], lookup_df[[key_col]])
  
  min_bounds <- lookup_df[[min_col]][lookup_idx]
  max_bounds <- lookup_df[[max_col]][lookup_idx]
  
  # Convert min/max from character to numeric
  # Variables table stores bounds as strings ("Infinity", "-Infinity", or numeric)
  to_numeric_bound <- function(x, default) {
    ifelse(
      x == "Infinity" | x == "Inf", Inf,
      ifelse(x == "-Infinity" | x == "-Inf", -Inf, as.numeric(x))
    )
  }
  
  min_num <- to_numeric_bound(min_bounds, -Inf)
  max_num <- to_numeric_bound(max_bounds, Inf)
  val_num <- suppressWarnings(as.numeric(df[[val_col]]))

  # Check: value must be within bounds (skip if value, min, or max is NA)
  bad <- !is.na(val_num) &
         !is.na(min_num) &
         !is.na(max_num) &
         (val_num < min_num | val_num > max_num)

  bad_rows <- which(bad)
  if (length(bad_rows) == 0) return(character(0))

  sprintf("[%s] %s (%d rows, indices: %s)",
          con$id, con$message,
          length(bad_rows),
          paste(head(bad_rows, 10), collapse = ", "))
}

#' Dispatch and run all custom_constraints for a single table
#'
#' @param tables named list of all data frames (all tables loaded)
#' @param table_name name of the table currently being validated
#' @param constraints the custom_constraints list from the YAML for this table
#' @return character vector of all error messages
#' @keywords internal
run_custom_constraints <- function(tables, table_name, constraints) {
  errors <- character(0)
  df <- tables[[table_name]]

  for (con in constraints) {
    if (con$type == "conditional_range") {
      lookup_table_name <- con$lookup$table
      lookup_df <- tables[[lookup_table_name]]
      if (is.null(lookup_df)) {
        warning(sprintf(
          "[%s] lookup table '%s' not loaded, skipping cross-table check",
          con$id, lookup_table_name
        ), call. = FALSE)
        next
      }
      result <- run_conditional_range(df, lookup_df, con)
      errors <- c(errors, result)
    }
  }
  errors
}

# ---------------------------------------------------------------------------
# Master custom validator
# ---------------------------------------------------------------------------

#' Run all custom (non-Frictionless) constraints across all loaded tables
#'
#' Loads the constraint definitions from the YAML file and applies each
#' applicable constraint to the corresponding data frame in \code{tables}.
#'
#' @param tables Named list of data frames. Names must match table names used
#'   in the YAML (e.g. "sites", "traitsview", "cultivars", "variables").
#'   Should ONLY include tables that have constraints; exclude junction tables.
#' @param constraints_path Path to custom_constraints.yaml. Defaults to
#'   data-raw/custom_constraints.yaml (development) or installed package path.
#' @return Named list of character vectors. Each name is a table that had
#'   errors; each value is a vector of error messages. Tables with no errors
#'   are omitted from the output.
#'
#' @export
validate_custom <- function(
    tables,
    constraints_path = "data-raw/custom_constraints.yaml") {
  
  rules   <- load_custom_constraints(constraints_path)
  if (length(rules) == 0) {
    return(list())
  }
  
  results <- list()

  for (table_name in names(rules)) {
    if (!table_name %in% names(tables)) next
    table_rules <- rules[[table_name]]
    errors <- character(0)

    if (!is.null(table_rules$composite_constraints)) {
      errors <- c(errors, run_composite_constraints(
        tables[[table_name]],
        table_rules$composite_constraints
      ))
    }

    if (!is.null(table_rules$custom_constraints)) {
      errors <- c(errors, run_custom_constraints(
        tables, table_name, table_rules$custom_constraints
      ))
    }

    if (length(errors) > 0) {
      results[[table_name]] <- errors
    }
  }

  results
}