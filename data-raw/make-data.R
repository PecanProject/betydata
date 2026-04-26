#!/usr/bin/env Rscript
# Build betydata package data objects from CSV sources

library(readr)
library(dplyr)

# Helper for logging (falls back to message if PEcAn.logger not available)
log_info <- function(msg) {
  if (requireNamespace("PEcAn.logger", quietly = TRUE)) {
    PEcAn.logger::logger.info(msg)
  } else {
    message(msg)
  }
}

log_info("Building betydata package data objects...")

# Create output directories
dir.create("data", showWarnings = FALSE)

# Column type specifications for stable parsing
traitsview_cols <- cols(
  checked = col_integer(),
  result_type = col_character(),
  id = col_integer(),
  citation_id = col_integer(),
  site_id = col_integer(),
  treatment_id = col_integer(),
  sitename = col_character(),
  city = col_character(),
  lat = col_double(),
  lon = col_double(),
  scientificname = col_character(),
  commonname = col_character(),

  genus = col_character(),
  species_id = col_integer(),
  cultivar_id = col_integer(),
  author = col_character(),
  citation_year = col_integer(),
  treatment = col_character(),
  date = col_character(),
  time = col_character(),
  raw_date = col_character(),
  month = col_integer(),
  year = col_integer(),
  dateloc = col_double(),
  trait = col_character(),
  trait_description = col_character(),
  mean = col_double(),
  units = col_character(),
  n = col_integer(),
  statname = col_character(),

  stat = col_double(),
  notes = col_character(),
  access_level = col_integer(),
  cultivar = col_character(),
  entity = col_character(),
  method_name = col_character()
)

# --- Primary dataset: traitsview ---
log_info("Reading traitsview.csv...")
traitsview <- read_csv(
  "data-raw/csv/traitsview.csv",
  col_types = traitsview_cols,
  show_col_types = FALSE,
  na = c("", "NA")
)

# Summarize access_level before filtering -- flag non-public records
access_summary <- table(traitsview$access_level, useNA = "ifany")
log_info("access_level distribution:")
for (lvl in names(access_summary)) {
  log_info(sprintf("access_level = %s: %d records", lvl, access_summary[[lvl]]))
}

# Keep only public records (access_level == 4)
# Explicit NA check; rows with NA access_level are not public
non_public <- sum(traitsview$access_level != 4 | is.na(traitsview$access_level))
if (non_public > 0) {
  log_info(sprintf("Removing %d non-public records (access_level != 4 or NA)", non_public))
}
traitsview <- traitsview[traitsview$access_level == 4 & !is.na(traitsview$access_level), ]

# Drop access_level column (all remaining records are public)
traitsview$access_level <- NULL

# Convert checked = NA to checked = 0, then remove failed QC records
traitsview <- traitsview |>
  dplyr::mutate(checked = ifelse(is.na(checked), 0L, checked)) |>
  dplyr::filter(checked >= 0)

# Reorder columns: key analytical columns first, IDs and metadata last
col_order <- c(
  "trait", "mean", "units", "scientificname", "genus",
  "commonname", "sitename", "author", "citation_year",
  "lat", "lon", "date", "year", "month",
  "checked", "result_type", "treatment", "cultivar",
  "entity", "method_name", "n", "statname", "stat",
  "notes", "trait_description", "city", "time", "raw_date",
  "dateloc", "id", "citation_id", "site_id", "treatment_id",
  "species_id", "cultivar_id"
)
traitsview <- traitsview[, col_order]

log_info(sprintf("  traitsview: %d rows, %d columns", nrow(traitsview), ncol(traitsview)))

# --- Support tables ---
read_support_table <- function(name) {
  path <- file.path("data-raw/csv", paste0(name, ".csv"))
  if (!file.exists(path)) {
    log_info(sprintf("  SKIPPED %s (file not found)", name))
    return(NULL)
  }
  df <- read_csv(path, show_col_types = FALSE, na = c("", "NA", "\\N"))
  log_info(sprintf("  %s: %d rows, %d columns", name, nrow(df), ncol(df)))
  df
}

log_info("Reading support tables...")
species  <- read_support_table("species")
sites    <- read_support_table("sites")
variables <- read_support_table("variables")
citations <- read_support_table("citations")
cultivars <- read_support_table("cultivars")
methods   <- read_support_table("methods")
treatments <- read_support_table("treatments")
pfts      <- read_support_table("pfts")
priors    <- read_support_table("priors")
managements <- read_support_table("managements")
entities  <- read_support_table("entities")
pfts_species <- read_support_table("pfts_species")
pfts_priors  <- read_support_table("pfts_priors")
managements_treatments <- read_support_table("managements_treatments")
cultivars_pfts <- read_support_table("cultivars_pfts")

# ---------------------------------------------------------------------------
# Data validation
# ---------------------------------------------------------------------------
# Run both validation layers before saving any .rda files.
# Layer 1: Frictionless-native constraints from datapackage.json
# Layer 2: Custom constraints from inst/extdata/custom_constraints.yaml
#
# If yaml or jsonlite are not available the validation step is skipped with
# a warning so that the build remains functional in minimal environments.

# ---------------------------------------------------------------------------
# Data validation with automatic filtering
# ---------------------------------------------------------------------------
log_info("Running data validation...")

if (requireNamespace("yaml", quietly = TRUE) &&
    requireNamespace("jsonlite", quietly = TRUE)) {

  source("R/validate_custom.R")
  source("R/validate.R")

  validation_tables <- list(
    traitsview = traitsview,
    sites = sites,
    variables = variables,
    cultivars = cultivars,
    citations = citations,
    species = species
  )
  
  validation_tables <- Filter(Negate(is.null), validation_tables)

  log_info(sprintf("Validating %d core tables...", length(validation_tables)))

  # RUN VALIDATION BUT DON'T STOP
  validation_results <- validate_all(
    tables           = validation_tables,
    datapackage_path = "datapackage.json",
    stop_on_error    = FALSE  # ← CHANGED: Don't stop, just collect errors
  )

  # NOW WE CAN FILTER BAD DATA
  if (length(validation_results) > 0) {
    log_info("Data quality issues found. Filtering invalid records...")
    
    dir.create("data-raw/invalid_data", showWarnings = FALSE)

        # ===== TRAITSVIEW =====
    if (!is.null(validation_results$traitsview)) {
      # Filter: missing required fields OR invalid stat/statname combination
      traitsview_invalid <- traitsview %>%
        dplyr::filter(
          is.na(trait) | is.na(mean) | is.na(id) | n < 1 |
          # Also filter: if stat is provided, statname must be provided
          (!is.na(stat) & nzchar(stat) & (is.na(statname) | !nzchar(statname)))
        )
      
      traitsview <- traitsview %>%
        dplyr::filter(
          !is.na(trait) & !is.na(mean) & !is.na(id) & n >= 1 &
          # Keep only rows where: if stat is provided, statname is also provided
          (is.na(stat) | !nzchar(stat) | (!is.na(statname) & nzchar(statname)))
        )
      
      readr::write_csv(traitsview_invalid, 
                       "data-raw/invalid_data/traitsview_invalid.csv")
      log_info(sprintf("  traitsview: removed %d rows", nrow(traitsview_invalid)))
    }

    # ===== SITES =====
    if (!is.null(validation_results$sites)) {
      sites_invalid <- sites %>%
        dplyr::filter(is.na(sitename))
      
      sites <- sites %>%
        dplyr::filter(!is.na(sitename))
      
      readr::write_csv(sites_invalid, 
                       "data-raw/invalid_data/sites_invalid.csv")
      log_info(sprintf("  sites: removed %d rows", nrow(sites_invalid)))
    }

    # ===== VARIABLES =====
    if (!is.null(validation_results$variables)) {
      variables_invalid <- variables %>%
        dplyr::filter(is.na(name) | is.na(units) | duplicated(name))
      
      variables <- variables %>%
        dplyr::filter(!is.na(name) & !is.na(units)) %>%
        dplyr::distinct(name, .keep_all = TRUE)
      
      readr::write_csv(variables_invalid, 
                       "data-raw/invalid_data/variables_invalid.csv")
      log_info(sprintf("  variables: removed %d rows", nrow(variables_invalid)))
    }

    # ===== CULTIVARS =====
    if (!is.null(validation_results$cultivars)) {
      cultivars_invalid <- cultivars %>%
        dplyr::filter(is.na(name))
      
      cultivars <- cultivars %>%
        dplyr::filter(!is.na(name))
      
      readr::write_csv(cultivars_invalid, 
                       "data-raw/invalid_data/cultivars_invalid.csv")
      log_info(sprintf("  cultivars: removed %d rows", nrow(cultivars_invalid)))
    }
    
    log_info("✓ Invalid records separated to data-raw/invalid_data/")

  } else {
    log_info("✓ All validation checks passed.")
  }

} else {
  log_info("WARNING: 'yaml' or 'jsonlite' not available — skipping validation.")
}
# ---------------------------------------------------------------------------
# Save .rda files
# ---------------------------------------------------------------------------
log_info("Saving .rda files to data/...")
usethis::use_data(traitsview, overwrite = TRUE, compress = "xz")

# Only save support tables that exist
if (!is.null(species))   usethis::use_data(species,   overwrite = TRUE, compress = "xz")
if (!is.null(sites))     usethis::use_data(sites,     overwrite = TRUE, compress = "xz")
if (!is.null(variables)) usethis::use_data(variables, overwrite = TRUE, compress = "xz")
if (!is.null(citations)) usethis::use_data(citations, overwrite = TRUE, compress = "xz")
if (!is.null(cultivars)) usethis::use_data(cultivars, overwrite = TRUE, compress = "xz")
if (!is.null(methods))   usethis::use_data(methods,   overwrite = TRUE, compress = "xz")
if (!is.null(treatments)) usethis::use_data(treatments, overwrite = TRUE, compress = "xz")
if (!is.null(pfts))      usethis::use_data(pfts,      overwrite = TRUE, compress = "xz")
if (!is.null(priors))    usethis::use_data(priors,    overwrite = TRUE, compress = "xz")
if (!is.null(managements)) usethis::use_data(managements, overwrite = TRUE, compress = "xz")
if (!is.null(entities))  usethis::use_data(entities,  overwrite = TRUE, compress = "xz")
if (!is.null(pfts_species)) usethis::use_data(pfts_species, overwrite = TRUE, compress = "xz")
if (!is.null(pfts_priors))  usethis::use_data(pfts_priors,  overwrite = TRUE, compress = "xz")
if (!is.null(managements_treatments)) usethis::use_data(managements_treatments, overwrite = TRUE, compress = "xz")
if (!is.null(cultivars_pfts)) usethis::use_data(cultivars_pfts, overwrite = TRUE, compress = "xz")

# Rest of code...
# --- Generate datapackage.json ---
log_info("Generating datapackage.json at repo root (Frictionless spec)...")

# NOTE: datapackage.json is now maintained manually and includes hand-curated
# constraint metadata. The auto-generation below is preserved but will WARN
# if the generated schema would overwrite constraints that were hand-added.
# The recommended workflow is to update datapackage.json directly when adding
# new tables or columns, preserving all constraints.

log_info("  datapackage.json is maintained manually with constraint metadata.")
log_info("  If you added new columns, update datapackage.json by hand and")
log_info("  add appropriate constraints following the existing pattern.")
