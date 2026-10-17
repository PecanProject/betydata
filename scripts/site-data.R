# Website-only data helpers. Never read data from an installed betydata package.
# Observation-based summary design follows PecanProject/betydata PR #33.

site_index_columns <- c(
  "result_type", "id", "trait", "trait_description", "mean", "units",
  "scientificname", "commonname", "author", "citation_year", "sitename", "checked"
)

load_site_dataset <- function(root, name) {
  env <- new.env(parent = emptyenv())
  path <- file.path(root, "data", paste0(name, ".rda"))
  loaded <- load(path, envir = env)
  if (!identical(loaded, name) || !is.data.frame(env[[name]])) {
    stop("Unexpected packaged dataset: ", name)
  }
  as.data.frame(env[[name]], stringsAsFactors = FALSE)
}

site_column_types <- function(data) {
  types <- lapply(data, function(column) {
    if (is.integer(column)) return(readr::col_integer())
    if (is.double(column)) return(readr::col_double())
    if (is.character(column)) return(readr::col_character())
    stop("Unsupported observation column type")
  })
  do.call(readr::cols, c(types, list(.default = readr::col_character())))
}

site_read_csv <- function(path, template, na = c("", "NA")) {
  value <- readr::read_csv(path, col_types = site_column_types(template),
                           na = na, show_col_types = FALSE, progress = FALSE,
                           trim_ws = TRUE)
  if (nrow(readr::problems(value))) stop("Invalid values in CSV: ", path)
  as.data.frame(value, stringsAsFactors = FALSE)
}

site_filter_public <- function(raw) {
  if (!all(c("access_level", "checked") %in% names(raw))) {
    stop("Source is missing access_level or checked")
  }
  public <- raw[!is.na(raw$access_level) & raw$access_level == 4, , drop = FALSE]
  public$access_level <- NULL
  public$checked[is.na(public$checked)] <- 0L
  public <- public[public$checked >= 0, , drop = FALSE]
  rownames(public) <- NULL
  public
}

site_validate_observations <- function(observations) {
  required <- unique(c(site_index_columns, "species_id", "site_id", "citation_id"))
  if (!all(required %in% names(observations))) stop("Missing observation columns")
  if (anyNA(observations$result_type) ||
      any(!observations$result_type %in% c("traits", "yields")) ||
      anyNA(observations$id) || !is.numeric(observations$id) ||
      any(!is.finite(observations$id) | observations$id < 0 |
          observations$id > 9007199254740991 | observations$id != floor(observations$id))) {
    stop("Invalid observation identity")
  }
  if (anyDuplicated(observations[c("result_type", "id")])) {
    stop("Duplicate observation identity (result_type, id)")
  }
  for (name in intersect(c("citation_id", "site_id", "treatment_id", "species_id", "cultivar_id"), names(observations))) {
    ids <- observations[[name]]
    if (!is.numeric(ids) || any(!is.na(ids) &
        (!is.finite(ids) | ids < 0 | ids > 9007199254740991 | ids != floor(ids)))) {
      stop("Invalid metadata identity: ", name)
    }
  }
  qc <- observations$checked
  if (!is.numeric(qc) || anyNA(qc) || any(!is.finite(qc) | !qc %in% c(0, 1))) {
    stop("Invalid public observation QC value")
  }
  invisible(TRUE)
}

site_sort_observations <- function(data) {
  data <- data[order(data$result_type, data$id, method = "radix"), , drop = FALSE]
  rownames(data) <- NULL
  data
}

site_assert_same <- function(actual, expected, label) {
  # Ignore table-class attributes, but compare every value, type and column.
  actual <- site_sort_observations(as.data.frame(actual))
  expected <- site_sort_observations(as.data.frame(expected))
  if (!identical(actual, expected)) stop(label, " does not match packaged public observations")
  invisible(TRUE)
}

site_summary <- function(observations) {
  count <- function(values) length(unique(values[!is.na(values) & values != ""]))
  list(
    observations = nrow(observations), variables = count(observations$trait),
    species = count(observations$species_id), sites = count(observations$site_id),
    sources = count(observations$citation_id)
  )
}

site_make_index <- function(observations, variables) {
  site_validate_observations(observations)
  if (!all(c("id", "name", "description", "units") %in% names(variables)) ||
      !is.numeric(variables$id) || anyNA(variables$id) ||
      any(!is.finite(variables$id) | variables$id < 0 |
          variables$id > 9007199254740991 | variables$id != floor(variables$id)) ||
      anyDuplicated(variables$id) ||
      anyNA(variables$name) || any(!nzchar(variables$name))) {
    stop("Invalid variable catalog")
  }
  observations <- site_sort_observations(observations)
  variables <- variables[order(variables$id, method = "radix"),
                         c("id", "name", "description", "units"), drop = FALSE]
  # Lists retain numbers as numbers and missing values as JSON null, without
  # coercing mixed rows to character vectors or joining duplicate catalog names.
  columns <- unname(as.list(observations[site_index_columns]))
  rows <- lapply(seq_len(nrow(observations)), function(i) {
    lapply(columns, function(column) column[[i]])
  })
  list(version = 1L, columns = site_index_columns, rows = rows, variables = variables)
}

build_site_data <- function(root = ".", output_dir = file.path(root, "site-data")) {
  root <- normalizePath(root, mustWork = TRUE)
  observations <- load_site_dataset(root, "traitsview")
  variables <- load_site_dataset(root, "variables")
  site_validate_observations(observations)

  raw_path <- file.path(root, "data-raw", "csv", "traitsview.csv")
  raw_template <- observations[FALSE, , drop = FALSE]
  raw_template$access_level <- integer()
  raw <- site_read_csv(raw_path, raw_template)
  expected <- site_filter_public(raw)
  if (!setequal(names(expected), names(observations))) stop("Source observation columns differ")
  expected <- expected[, names(observations), drop = FALSE]
  site_validate_observations(expected)
  site_assert_same(expected, observations, "Filtered source")

  observations <- site_sort_observations(observations)
  index <- site_make_index(observations, variables)
  summary <- site_summary(observations)
  source_paths <- c("data/traitsview.rda", "data/variables.rda", "data-raw/csv/traitsview.csv")
  summary$source_hashes <- as.list(setNames(
    unname(tools::md5sum(file.path(root, source_paths))), source_paths
  ))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  # Stage and validate every output before publishing anything to the render.
  stage <- tempfile("bety-site-data-")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  csv_path <- file.path(stage, "observations.csv")
  readr::write_csv(observations, csv_path, na = "NA")
  restored <- site_read_csv(csv_path, observations, na = "NA")
  site_assert_same(restored, observations, "CSV round trip")
  jsonlite::write_json(index, file.path(stage, "search-index.json"),
                       auto_unbox = TRUE, dataframe = "rows", na = "null",
                       null = "null", digits = NA)
  decoded <- jsonlite::read_json(file.path(stage, "search-index.json"))
  keys <- vapply(decoded$rows, function(row) paste(row[[1]], row[[2]], sep = ":"), "")
  expected_keys <- paste(observations$result_type, observations$id, sep = ":")
  if (!identical(keys, expected_keys)) stop("Index identities do not match observations")
  jsonlite::write_json(summary, file.path(stage, "summary.json"), auto_unbox = TRUE,
                       digits = NA)
  files <- c("observations.csv", "search-index.json", "summary.json")
  copied <- file.copy(file.path(stage, files), file.path(output_dir, files), overwrite = TRUE)
  if (!all(copied)) stop("Could not publish generated website data")
  invisible(summary)
}
