# R/validate.R
#
# Master validation entry point for the betydata package.
#
# Runs two layers of constraint checks:
#
#   Layer 1 — Frictionless-native constraints
#     Declared in datapackage.json: required, minimum/maximum, enum,
#     unique, primaryKey, foreignKeys.
#     Checked by inspecting the loaded data frames directly against the
#     schema (avoids re-reading CSVs; the data is already in memory).
#
#   Layer 2 — Custom constraints
#     Declared in data-raw/custom_constraints.yaml.
#     Covers composite cross-field rules and cross-table range lookups
#     that Frictionless Table Schema cannot express natively.
#     Implemented in R/validate_custom.R.
#
# Typical usage from data-raw/make-data.R:
#
#   source("R/validate_custom.R")
#   source("R/validate.R")
#   tables <- list(
#     sites      = sites,
#     traitsview = traitsview,
#     cultivars  = cultivars,
#     variables  = variables
#   )
#   validate_all(tables)

#' Validate Frictionless-native field-level constraints from datapackage.json
#'
#' Reads the schema from datapackage.json and checks each field's declared
#' constraints (required, minimum, maximum, enum, unique) against the
#' supplied data frame. Foreign key and primaryKey checks are handled
#' separately in validate_foreign_keys().
#'
#' @param df data frame to validate
#' @param schema the "schema" list for this resource from datapackage.json
#' @param table_name table name string for error messages
#' @return character vector of error messages (empty if all pass)
#' @keywords internal
validate_frictionless_fields <- function(df, schema, table_name) {
  errors <- character(0)
  fields <- schema$fields
  if (is.null(fields)) return(errors)

  for (field in fields) {
    fname  <- field$name
    ftype  <- field$type
    fcons  <- field$constraints
    if (is.null(fcons)) next
    if (!fname %in% names(df)) next   # column not present; schema mismatch caught elsewhere

    col <- df[[fname]]

    # required
    if (isTRUE(fcons$required)) {
      na_count <- sum(is.na(col))
      if (na_count > 0) {
        errors <- c(errors, sprintf(
          "[%s.%s] required field has %d NA value(s)", table_name, fname, na_count
        ))
      }
    }

    # unique (single-field; compound uniqueness via primaryKey handled separately)
    if (isTRUE(fcons$unique)) {
      non_na <- col[!is.na(col)]
      if (anyDuplicated(non_na) > 0) {
        errors <- c(errors, sprintf(
          "[%s.%s] unique constraint violated (%d duplicate values)",
          table_name, fname, sum(duplicated(non_na))
        ))
      }
    }

    # minimum / maximum (numeric and date fields)
    col_num <- suppressWarnings(as.numeric(col))

    if (!is.null(fcons$minimum)) {
      bad <- !is.na(col_num) & col_num < fcons$minimum
      if (any(bad)) {
        errors <- c(errors, sprintf(
          "[%s.%s] %d value(s) below minimum (%s)",
          table_name, fname, sum(bad), fcons$minimum
        ))
      }
    }

    if (!is.null(fcons$maximum)) {
      bad <- !is.na(col_num) & col_num > fcons$maximum
      if (any(bad)) {
        errors <- c(errors, sprintf(
          "[%s.%s] %d value(s) above maximum (%s)",
          table_name, fname, sum(bad), fcons$maximum
        ))
      }
    }

    # enum
    if (!is.null(fcons$enum)) {
      allowed <- unlist(fcons$enum)
      bad <- !is.na(col) & !col %in% allowed
      if (any(bad)) {
        errors <- c(errors, sprintf(
          "[%s.%s] %d value(s) not in allowed set {%s}",
          table_name, fname, sum(bad), paste(allowed, collapse = ", ")
        ))
      }
    }
  }
  errors
}

#' Validate primaryKey uniqueness for a table
#'
#' @param df data frame
#' @param schema the schema list for this resource
#' @param table_name string for error messages
#' @return character vector of error messages
#' @keywords internal
validate_primary_key <- function(df, schema, table_name) {
  errors <- character(0)
  pk <- schema$primaryKey
  if (is.null(pk)) return(errors)

  pk_cols <- unlist(pk)
  present <- pk_cols[pk_cols %in% names(df)]
  if (length(present) < length(pk_cols)) return(errors)

  dupes <- duplicated(df[, present, drop = FALSE])
  if (any(dupes)) {
    errors <- c(errors, sprintf(
      "[%s] primaryKey (%s) has %d duplicate combination(s)",
      table_name, paste(pk_cols, collapse = ", "), sum(dupes)
    ))
  }
  errors
}

#' Validate foreign key referential integrity across tables
#'
#' OPTIMIZED: Uses fast set membership checking instead of row-by-row comparison.
#'
#' @param tables named list of all loaded data frames
#' @param schema the schema list for the child resource
#' @param table_name name of the child table
#' @return character vector of error messages
#' @keywords internal
validate_foreign_keys <- function(tables, schema, table_name) {
  errors <- character(0)
  fks <- schema$foreignKeys
  if (is.null(fks)) return(errors)

  df <- tables[[table_name]]

  for (fk in fks) {
    child_cols  <- unlist(fk$fields)
    ref_resource <- fk$reference$resource
    ref_cols    <- unlist(fk$reference$fields)

    ref_df <- tables[[ref_resource]]
    if (is.null(ref_df)) next  # referenced table not loaded; skip silently

    if (!all(child_cols %in% names(df))) next
    if (!all(ref_cols %in% names(ref_df))) next

    # OPTIMIZATION: For single-column FKs, use fast %in% operator
    if (length(child_cols) == 1) {
      child_vals <- df[[child_cols[1]]]
      ref_vals   <- ref_df[[ref_cols[1]]]
      
      bad <- !is.na(child_vals) & !child_vals %in% ref_vals
      if (any(bad)) {
        bad_rows <- which(bad)
        errors <- c(errors, sprintf(
          "[%s] foreign key %s -> %s(%s): %d value(s) not found in reference table (row indices: %s)",
          table_name,
          child_cols[1],
          ref_resource,
          ref_cols[1],
          sum(bad),
          paste(head(bad_rows, 10), collapse = ", ")
        ))
      }
    } else {
      # Multi-column FK: create composite keys as paste-separated strings
      child_key <- do.call(paste, c(df[, child_cols, drop = FALSE], sep = "||"))
      ref_key   <- do.call(paste, c(ref_df[, ref_cols, drop = FALSE], sep = "||"))
      
      bad <- !is.na(child_key) & !child_key %in% ref_key
      if (any(bad)) {
        bad_rows <- which(bad)
        errors <- c(errors, sprintf(
          "[%s] composite foreign key (%s) -> %s(%s): %d value(s) not found in reference table",
          table_name,
          paste(child_cols, collapse = ", "),
          ref_resource,
          paste(ref_cols, collapse = ", "),
          sum(bad)
        ))
      }
    }
  }
  errors
}

#' Run all Frictionless-layer validation across all loaded tables
#'
#' @param tables named list of data frames (ONLY constrained tables)
#' @param datapackage_path path to datapackage.json
#' @return named list of character vectors; each name is a table with errors
#' @keywords internal
validate_frictionless_layer <- function(
    tables,
    datapackage_path = "datapackage.json") {

  if (!file.exists(datapackage_path)) {
    message("datapackage.json not found at: ", datapackage_path,
            " — skipping Frictionless layer validation")
    return(list())
  }

  dp      <- jsonlite::read_json(datapackage_path)
  results <- list()

  for (resource in dp$resources) {
    tname  <- resource$name
    schema <- resource$schema
    if (is.null(schema) || !tname %in% names(tables)) next

    df <- tables[[tname]]
    errors <- character(0)

    errors <- c(errors, validate_frictionless_fields(df, schema, tname))
    errors <- c(errors, validate_primary_key(df, schema, tname))
    errors <- c(errors, validate_foreign_keys(tables, schema, tname))

    if (length(errors) > 0) results[[tname]] <- errors
  }
  results
}

#' Run all validation layers and report results
#'
#' This is the main entry point. It runs both the Frictionless-native
#' constraint checks and the custom constraint checks, then collates
#' results and either stops (on hard errors) or messages warnings.
#'
#' @param tables Named list of data frames. Names must match resource names
#'   in datapackage.json and table names in custom_constraints.yaml.
#'   Only include tables that have constraints; exclude junction tables.
#' @param datapackage_path Path to datapackage.json (default: repo root).
#' @param constraints_path Path to custom_constraints.yaml.
#' @param stop_on_error If TRUE (default), calls stop() when errors are found.
#'   Set to FALSE to return results without stopping (useful in tests).
#' @return Invisibly returns a named list of error vectors per table.
#'   Empty list means all checks passed.
#'
#' @export
validate_all <- function(
    tables,
    datapackage_path  = "datapackage.json",
    constraints_path  = "data-raw/custom_constraints.yaml",
    stop_on_error     = TRUE) {

  # Validate only the constrained tables passed to this function.
  # Junction/lookup tables should already be filtered by the caller
  # (in data-raw/make-data.R) to avoid wasting validation time on tables
  # that have no constraints defined.
  
  if (length(tables) == 0) {
    message("No tables to validate.")
    return(invisible(list()))
  }

  message(sprintf("Running Layer 1: Frictionless-native constraint checks (%d tables)...",
                  length(tables)))
  fl_errors <- validate_frictionless_layer(tables, datapackage_path)

  message("Running Layer 2: Custom constraint checks (composite + cross-table)...")
  custom_errors <- validate_custom(tables, constraints_path)

  # Merge results
  all_tables <- union(names(fl_errors), names(custom_errors))
  if (length(all_tables) == 0) {
    message("✓ All validation checks passed.")
    return(invisible(list()))
  }

  results <- setNames(
    lapply(all_tables, function(tname) {
      c(fl_errors[[tname]], custom_errors[[tname]])
    }),
    all_tables
  )
  results <- results[lengths(results) > 0]

  # Report errors
  total <- sum(lengths(results))
  message(sprintf("✗ Validation found %d error(s) across %d table(s):",
                  total, length(results)))
  for (tname in names(results)) {
    message(sprintf("  [%s] — %d error(s)", tname, length(results[[tname]])))
    for (err in head(results[[tname]], 5)) {  # Show first 5 per table
      message("    - ", err)
    }
    if (length(results[[tname]]) > 5) {
      message(sprintf("    ... and %d more", length(results[[tname]]) - 5))
    }
  }

  if (stop_on_error) {
    stop("Data validation failed. Fix errors before saving package data.",
         call. = FALSE)
  }

  invisible(results)
}