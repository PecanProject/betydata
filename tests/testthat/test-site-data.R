# Website tooling is deliberately excluded from built R packages.
site_root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
site_helpers <- file.path(site_root, "scripts", "site-data.R")
if (file.exists(site_helpers)) source(site_helpers, local = TRUE)

site_fixture <- function() {
  data.frame(
    result_type = c("traits", "traits", "yields"), id = c(1L, 2L, 1L),
    trait = c("SLA", "SLA", "yield"),
    trait_description = c("Leaf area", NA, "Harvest"), mean = c(1.2, 2.3, 3.4),
    units = c("m2 kg-1", NA, "Mg ha-1"),
    scientificname = c("Panicum virgatum", "Quercus alba", NA),
    commonname = c("switchgrass", NA, NA), author = c("Smith", "Wu", NA),
    citation_year = c(2010L, 2011L, NA_integer_), sitename = c("A", "B", NA),
    checked = c(0L, 1L, 0L), species_id = c(1L, 2L, NA_integer_),
    site_id = c(1L, 2L, NA_integer_), citation_id = c(1L, 2L, NA_integer_),
    stringsAsFactors = FALSE
  )
}

site_variables_fixture <- function() {
  data.frame(id = c(11, 12, 13), name = c("SLA", "SLA", "yield"),
             description = c("Leaf area", "Alternate definition", NA),
             units = c("m2 kg-1", "m2 kg-1", NA))
}

site_fixture_root <- function() {
  root <- tempfile("site-source-")
  dir.create(file.path(root, "data"), recursive = TRUE)
  dir.create(file.path(root, "data-raw", "csv"), recursive = TRUE)
  traitsview <- site_fixture()
  variables <- site_variables_fixture()
  save(traitsview, file = file.path(root, "data", "traitsview.rda"))
  save(variables, file = file.path(root, "data", "variables.rda"))
  raw <- traitsview
  raw$access_level <- 4L
  excluded <- raw[rep(1, 3), ]
  excluded$id <- 100L + seq_len(3)
  excluded$access_level <- c(1L, NA_integer_, 4L)
  excluded$checked <- c(1L, 1L, -1L)
  raw <- rbind(raw, excluded)
  readr::write_csv(raw, file.path(root, "data-raw", "csv", "traitsview.csv"))
  root
}

test_that("public policy excludes private and failed QC data, normalizing unchecked data", {
  skip_if_not(file.exists(site_helpers))
  raw <- site_fixture()[rep(1, 6), ]
  raw$id <- seq_len(6)
  raw$access_level <- c(4L, 4L, 4L, 1L, NA_integer_, 4L)
  raw$checked <- c(NA_integer_, -1L, 1L, 1L, 1L, -2L)
  filtered <- site_filter_public(raw)
  expect_equal(filtered$id, c(1L, 3L))
  expect_equal(filtered$checked, c(0L, 1L))
  expect_false("access_level" %in% names(filtered))
})

test_that("observation keys are composite and QC is validated", {
  skip_if_not(file.exists(site_helpers))
  data <- site_fixture()
  expect_true(site_validate_observations(data))
  expect_error(site_validate_observations(rbind(data, data[1, ])), "Duplicate observation")
  for (value in c(NA, -1, Inf, 0.5, 2)) {
    invalid <- data
    invalid$checked[1] <- value
    expect_error(site_validate_observations(invalid), "QC")
  }
  invalid <- data
  invalid$result_type[1] <- "unexpected"
  expect_error(site_validate_observations(invalid), "identity")
  data$id[1] <- NA
  expect_error(site_validate_observations(data), "identity")
})

test_that("database IDs above the 32-bit limit retain exact identities", {
  skip_if_not(file.exists(site_helpers))
  data <- site_fixture()
  data$id <- c(5000000006, 5000000007, 5000000008)
  data$citation_id <- c(5000000007, 5000000007, NA_real_)
  expect_true(site_validate_observations(data))
  index <- site_make_index(data, site_variables_fixture())
  expect_equal(vapply(index$rows, function(row) row[[2]], 0), data$id)
  data$id[1] <- 9007199254740992
  expect_error(site_validate_observations(data), "identity")
})

test_that("index preserves separate variable IDs without multiplying observations", {
  skip_if_not(file.exists(site_helpers))
  index <- site_make_index(site_fixture(), site_variables_fixture())
  expect_length(index$rows, 3L)
  expect_equal(index$variables$id, c(11, 12, 13))
  expect_equal(sum(index$variables$name == "SLA"), 2L)
  expect_true(is.na(index$rows[[2]][[4]]))
  expect_equal(site_summary(site_fixture()), list(
    observations = 3L, variables = 2L, species = 2L, sites = 2L, sources = 2L
  ))
})

test_that("generation validates every exported column and is deterministic", {
  skip_if_not(file.exists(site_helpers))
  skip_if_not_installed("readr")
  skip_if_not_installed("jsonlite")
  root <- site_fixture_root()
  on.exit(unlink(root, recursive = TRUE))
  output <- file.path(root, "site-data")
  first <- build_site_data(root)
  files <- list.files(output, full.names = TRUE)
  hashes <- tools::md5sum(files)
  expect_identical(build_site_data(root), first)
  expect_identical(tools::md5sum(files), hashes)
  csv <- site_read_csv(file.path(output, "observations.csv"), site_fixture(), na = "NA")
  expect_identical(csv, site_fixture())
  index <- jsonlite::read_json(file.path(output, "search-index.json"))
  expect_length(index$rows, 3)
  expect_null(index$rows[[2]][[4]])

  # Alter a non-index metadata field: parity must still prevent publication.
  raw <- site_fixture()
  raw$site_id[1] <- 99L
  raw$access_level <- 4L
  readr::write_csv(raw, file.path(root, "data-raw", "csv", "traitsview.csv"))
  expect_error(build_site_data(root), "Filtered source does not match")
  expect_identical(tools::md5sum(files), hashes)
})

test_that("fresh source data regenerates summaries without changing scripts", {
  skip_if_not(file.exists(site_helpers))
  skip_if_not_installed("readr")
  skip_if_not_installed("jsonlite")
  root <- site_fixture_root()
  on.exit(unlink(root, recursive = TRUE))
  expect_equal(build_site_data(root)$observations, 3)
  traitsview <- site_fixture()[1:2, ]
  save(traitsview, file = file.path(root, "data", "traitsview.rda"))
  raw <- traitsview
  raw$access_level <- 4L
  readr::write_csv(raw, file.path(root, "data-raw", "csv", "traitsview.csv"))
  expect_equal(build_site_data(root)$observations, 2)
  summary <- jsonlite::read_json(file.path(root, "site-data", "summary.json"))
  expect_equal(summary$observations, 2)
  expect_equal(summary$variables, 1)
})

test_that("checkout source policy, packaged data and downloadable CSV agree", {
  skip_if_not(file.exists(site_helpers))
  skip_if_not_installed("readr")
  skip_if_not_installed("jsonlite")
  skip_if_not(file.exists(file.path(site_root, "data-raw", "csv", "traitsview.csv")))
  output <- tempfile("site-public-")
  on.exit(unlink(output, recursive = TRUE))
  observations <- load_site_dataset(site_root, "traitsview")
  expect_true(all(c(5000000006, 5000000007, 5000000008) %in% observations$id))
  expect_false(anyNA(observations$id))
  summary <- build_site_data(site_root, output)
  expect_equal(summary$observations, nrow(observations))
  expect_identical(summary[names(site_summary(observations))], site_summary(observations))
  expect_identical(site_read_csv(file.path(output, "observations.csv"), observations, na = "NA"),
                   site_sort_observations(observations))
})
