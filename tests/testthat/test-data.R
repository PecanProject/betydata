# Tests for betydata tables

test_that("traitsview loads correctly", {
  data("traitsview", package = "betydata")

  expect_s3_class(traitsview, "data.frame")
  expect_gt(nrow(traitsview), 40000)
  expect_equal(ncol(traitsview), 35)
})

test_that("traitsview has required columns", {
  data("traitsview", package = "betydata")

  expected_cols <- c(
    "id", "trait", "mean", "units", "scientificname",
    "sitename", "author", "checked"
  )
  expect_true(all(expected_cols %in% names(traitsview)))
})

test_that("traitsview excludes checked = -1 per data policy", {
  data("traitsview", package = "betydata")

  expect_false(any(traitsview$checked == -1, na.rm = TRUE))
})

test_that("traitsview coordinates are valid", {
  data("traitsview", package = "betydata")

  valid_lat <- traitsview$lat[!is.na(traitsview$lat)]
  valid_lon <- traitsview$lon[!is.na(traitsview$lon)]

  expect_true(all(valid_lat >= -90 & valid_lat <= 90))
  expect_true(all(valid_lon >= -180 & valid_lon <= 180))
})

test_that("traitsview key columns are first", {
  data("traitsview", package = "betydata")

  first_cols <- names(traitsview)[1:5]
  expect_equal(first_cols, c("trait", "mean", "units", "scientificname", "genus"))
})

test_that("species table loads correctly", {
  data("species", package = "betydata")

  expect_s3_class(species, "data.frame")
  expect_true("id" %in% names(species))
  expect_gt(nrow(species), 0)
})

test_that("variables table loads correctly", {
  data("variables", package = "betydata")

  expect_s3_class(variables, "data.frame")
  required_cols <- c("id", "name", "units")
  expect_true(all(required_cols %in% names(variables)))
})

test_that("pfts table loads correctly", {
  data("pfts", package = "betydata")

  expect_s3_class(pfts, "data.frame")
  expect_true(all(c("id", "name") %in% names(pfts)))
})
