#!/usr/bin/env Rscript
# Integration regression: change only input datasets, then render the actual
# homepage again without --execute or edits to index.qmd. Never mutate checkout.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1]] else ".", mustWork = TRUE)
source(file.path(root, "scripts", "site-data.R"))
quarto <- Sys.which("quarto")
if (!nzchar(quarto)) stop("Quarto is required for the homepage freshness regression")
fixture <- tempfile("bety-freshness-")
dir.create(fixture)
# This is a top-level script, so cleanup belongs in a function's exit handler.
run_freshness_test <- function() {
  on.exit(unlink(fixture, recursive = TRUE), add = TRUE)
  sources <- c("_quarto.yml", "index.qmd", "search.qmd", "access.qmd", "contribute.qmd",
               "about.qmd", "site-assets", "scripts", "vignettes")
  for (path in sources) {
    if (!file.copy(file.path(root, path), fixture, recursive = TRUE)) {
      stop("Could not copy freshness fixture source: ", path)
    }
  }
  dir.create(file.path(fixture, "data"))
  dir.create(file.path(fixture, "data-raw", "csv"), recursive = TRUE)
  variables <- load_site_dataset(root, "variables")
  save(variables, file = file.path(fixture, "data", "variables.rda"))
  base <- load_site_dataset(root, "traitsview")[1:3, , drop = FALSE]
  write_fixture <- function(n) {
    traitsview <- base[seq_len(n), , drop = FALSE]
    save(traitsview, file = file.path(fixture, "data", "traitsview.rda"))
    raw <- traitsview
    raw$access_level <- 4L
    readr::write_csv(raw, file.path(fixture, "data-raw", "csv", "traitsview.csv"))
  }
  previous <- getwd()
  on.exit(setwd(previous), add = TRUE)
  setwd(fixture)
  source_hash <- tools::md5sum("index.qmd")
  render_count <- function(expected) {
    log <- tempfile("quarto-freshness-log-")
    on.exit(unlink(log), add = TRUE)
    status <- system2(quarto, c("render", "index.qmd"), stdout = log, stderr = log)
    if (status != 0) stop(paste(readLines(log, warn = FALSE), collapse = "\n"))
    html <- paste(readLines("_site/index.html", warn = FALSE), collapse = "\n")
    pattern <- sprintf('data-metric="observations">\\s*%s\\s*</dd>', expected)
    if (!grepl(pattern, html, perl = TRUE)) {
      stop("Rendered homepage did not show the fresh observation count: ", expected, "\n",
           paste(grep("data-metric|<dd|Observations", strsplit(html, "\n")[[1]], value = TRUE), collapse = "\n"))
    }
    stopifnot(identical(tools::md5sum("index.qmd"), source_hash))
  }
  write_fixture(3)
  render_count(3)
  write_fixture(2)
  render_count(2)
  message("Homepage freshness passed: 3 -> 2 observations without editing index.qmd or forcing execution.")
}
run_freshness_test()
