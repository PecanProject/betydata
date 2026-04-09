# Tests for frictionless datapackage.json
# datapackage.json lives at repo root (not in installed package) per Frictionless spec.

test_that("datapackage.json exists and is valid JSON", {
  pkg_root <- testthat::test_path("..", "..")
  dp_path <- file.path(pkg_root, "datapackage.json")
  skip_if_not(file.exists(dp_path),
              "datapackage.json not found at repo root (skipped in installed package)")

  dp <- jsonlite::read_json(dp_path)
  expect_true("name" %in% names(dp))
  expect_equal(dp$name, "betydata")
})

test_that("datapackage.json lists all datasets", {
  pkg_root <- testthat::test_path("..", "..")
  dp_path <- file.path(pkg_root, "datapackage.json")
  skip_if_not(file.exists(dp_path),
              "datapackage.json not found at repo root (skipped in installed package)")

  dp <- jsonlite::read_json(dp_path)
  resource_names <- vapply(dp$resources, function(r) r$name, character(1))

  expected <- c("traitsview", "species", "sites", "variables", "citations",
                "pfts", "priors", "cultivars", "methods", "treatments")
  expect_true(all(expected %in% resource_names))
})

test_that("traitsview schema fields match actual columns", {
  pkg_root <- testthat::test_path("..", "..")
  dp_path <- file.path(pkg_root, "datapackage.json")
  skip_if_not(file.exists(dp_path),
              "datapackage.json not found at repo root (skipped in installed package)")

  dp <- jsonlite::read_json(dp_path)
  tv_resource <- Filter(function(r) r$name == "traitsview", dp$resources)[[1]]
  schema_fields <- vapply(tv_resource$schema$fields, function(f) f$name, character(1))

  data("traitsview", package = "betydata")
  expect_equal(sort(schema_fields), sort(names(traitsview)))
})
