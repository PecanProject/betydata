# Tests for frictionless datapackage.json

context("Metadata validation")

test_that("datapackage.json exists and is valid JSON", {
  pkg_path <- system.file("metadata", "datapackage.json", package = "betydata")
  expect_true(file.exists(pkg_path))
  
  dp <- jsonlite::read_json(pkg_path)
  expect_true("name" %in% names(dp))
  expect_equal(dp$name, "betydata")
})

test_that("datapackage.json lists all datasets", {
  pkg_path <- system.file("metadata", "datapackage.json", package = "betydata")
  dp <- jsonlite::read_json(pkg_path)
  
  resource_names <- vapply(dp$resources, function(r) r$name, character(1))
  
  expected <- c("traitsview", "species", "sites", "variables", "citations",
                "pfts", "priors", "cultivars", "methods", "treatments")
  expect_true(all(expected %in% resource_names))
})

test_that("traitsview schema fields match actual columns", {
  pkg_path <- system.file("metadata", "datapackage.json", package = "betydata")
  dp <- jsonlite::read_json(pkg_path)
  
  tv_resource <- Filter(function(r) r$name == "traitsview", dp$resources)[[1]]
  schema_fields <- vapply(tv_resource$schema$fields, function(f) f$name, character(1))
  
  data("traitsview", package = "betydata")
  expect_equal(sort(schema_fields), sort(names(traitsview)))
})