#!/usr/bin/env Rscript
# Build betydata package data objects from CSV sources


library(readr)

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
dir.create("inst/extdata/parquet", showWarnings = FALSE, recursive = TRUE)

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

# Filter out checked = -1
traitsview <- traitsview[is.na(traitsview$checked) | traitsview$checked != -1, ]

# Drop access_level column (all records are public, access_level = 4)
traitsview$access_level <- NULL

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
species <- read_support_table("species")
sites <- read_support_table("sites")
variables <- read_support_table("variables")
citations <- read_support_table("citations")
cultivars <- read_support_table("cultivars")
methods <- read_support_table("methods")
treatments <- read_support_table("treatments")
pfts <- read_support_table("pfts")
priors <- read_support_table("priors")
managements <- read_support_table("managements")
entities <- read_support_table("entities")
pfts_species <- read_support_table("pfts_species")
pfts_priors <- read_support_table("pfts_priors")
managements_treatments <- read_support_table("managements_treatments")
cultivars_pfts <- read_support_table("cultivars_pfts")


log_info("Saving .rda files to data/...")
usethis::use_data(traitsview, overwrite = TRUE, compress = "xz")

# Only save support tables that exist
if (!is.null(species)) usethis::use_data(species, overwrite = TRUE, compress = "xz")
if (!is.null(sites)) usethis::use_data(sites, overwrite = TRUE, compress = "xz")
if (!is.null(variables)) usethis::use_data(variables, overwrite = TRUE, compress = "xz")
if (!is.null(citations)) usethis::use_data(citations, overwrite = TRUE, compress = "xz")
if (!is.null(cultivars)) usethis::use_data(cultivars, overwrite = TRUE, compress = "xz")
if (!is.null(methods)) usethis::use_data(methods, overwrite = TRUE, compress = "xz")
if (!is.null(treatments)) usethis::use_data(treatments, overwrite = TRUE, compress = "xz")
if (!is.null(pfts)) usethis::use_data(pfts, overwrite = TRUE, compress = "xz")
if (!is.null(priors)) usethis::use_data(priors, overwrite = TRUE, compress = "xz")
if (!is.null(managements)) usethis::use_data(managements, overwrite = TRUE, compress = "xz")
if (!is.null(entities)) usethis::use_data(entities, overwrite = TRUE, compress = "xz")
if (!is.null(pfts_species)) usethis::use_data(pfts_species, overwrite = TRUE, compress = "xz")
if (!is.null(pfts_priors)) usethis::use_data(pfts_priors, overwrite = TRUE, compress = "xz")
if (!is.null(managements_treatments)) usethis::use_data(managements_treatments, overwrite = TRUE, compress = "xz")
if (!is.null(cultivars_pfts)) usethis::use_data(cultivars_pfts, overwrite = TRUE, compress = "xz")


log_info("Saving Parquet files to inst/extdata/parquet/...")
if (requireNamespace("arrow", quietly = TRUE)) {
  arrow::write_parquet(traitsview, "inst/extdata/parquet/traitsview.parquet")
  if (!is.null(species)) arrow::write_parquet(species, "inst/extdata/parquet/species.parquet")
  if (!is.null(sites)) arrow::write_parquet(sites, "inst/extdata/parquet/sites.parquet")
  if (!is.null(variables)) arrow::write_parquet(variables, "inst/extdata/parquet/variables.parquet")
  if (!is.null(citations)) arrow::write_parquet(citations, "inst/extdata/parquet/citations.parquet")
  if (!is.null(cultivars)) arrow::write_parquet(cultivars, "inst/extdata/parquet/cultivars.parquet")
  if (!is.null(methods)) arrow::write_parquet(methods, "inst/extdata/parquet/methods.parquet")
  if (!is.null(treatments)) arrow::write_parquet(treatments, "inst/extdata/parquet/treatments.parquet")
  if (!is.null(pfts)) arrow::write_parquet(pfts, "inst/extdata/parquet/pfts.parquet")
  if (!is.null(priors)) arrow::write_parquet(priors, "inst/extdata/parquet/priors.parquet")
  if (!is.null(managements)) arrow::write_parquet(managements, "inst/extdata/parquet/managements.parquet")
  if (!is.null(entities)) arrow::write_parquet(entities, "inst/extdata/parquet/entities.parquet")
  if (!is.null(pfts_species)) arrow::write_parquet(pfts_species, "inst/extdata/parquet/pfts_species.parquet")
  if (!is.null(pfts_priors)) arrow::write_parquet(pfts_priors, "inst/extdata/parquet/pfts_priors.parquet")
  if (!is.null(managements_treatments)) arrow::write_parquet(managements_treatments, "inst/extdata/parquet/managements_treatments.parquet")
  if (!is.null(cultivars_pfts)) arrow::write_parquet(cultivars_pfts, "inst/extdata/parquet/cultivars_pfts.parquet")
} else {
  log_info("arrow package not available, skipping Parquet export")
}


# --- Generate datapackage.json ---
log_info("Generating inst/metadata/datapackage.json...")
dir.create("inst/metadata", showWarnings = FALSE, recursive = TRUE)

# Helper to infer Frictionless type from R class
r_to_frictionless_type <- function(x) {
  if (is.integer(x)) return("integer")
  if (is.numeric(x)) return("number")
  if (inherits(x, "Date")) return("date")
  if (inherits(x, "POSIXt")) return("datetime")
  if (is.logical(x)) return("boolean")
  "string"
}

# Build schema for any data frame
build_schema <- function(df) {
  fields <- lapply(names(df), function(col) {
    list(name = col, type = r_to_frictionless_type(df[[col]]))
  })
  list(fields = fields)
}

# Build resources list
datasets <- c("traitsview", "species", "sites", "variables", "citations",
              "cultivars", "methods", "treatments", "pfts", "priors",
              "managements", "entities", "pfts_species", "pfts_priors",
              "managements_treatments", "cultivars_pfts")

resources <- lapply(datasets, function(nm) {
  df <- get(nm)
  base <- list(
    name = nm,
    path = paste0("data/", nm, ".rda"),
    format = "rda"
  )
  if (nm == "traitsview") {
    base$title <- "Traits and Yields View"
    base$description <- "Denormalized view of plant trait measurements and crop yields"
  }
  if (!is.null(df)) {
    base$schema <- build_schema(df)
  }
  base
})

datapackage <- list(
  name = "betydata",
  title = "BETYdb Plant Traits and Yields Data Package",
  version = as.character(read.dcf("DESCRIPTION", fields = "Version")),
  created = format(Sys.Date(), "%Y-%m-%d"),
  licenses = list(list(
    name = "ODC-By-1.0",
    title = "Open Data Commons Attribution License 1.0",
    path = "https://opendatacommons.org/licenses/by/1-0/"
  )),
  sources = list(
    list(title = "BETYdb", path = "https://betydb.org"),
    list(title = "LeBauer et al. (2018) GCB Bioenergy", path = "https://doi.org/10.1111/gcbb.12420")
  ),
  resources = resources
)

jsonlite::write_json(datapackage, "inst/metadata/datapackage.json", 
                     auto_unbox = TRUE, pretty = TRUE)
log_info("  datapackage.json written")