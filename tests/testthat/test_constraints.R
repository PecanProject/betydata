# tests/testthat/test-constraints.R
#
# Tests for BETYdb data constraint validators.
# Covers both Frictionless-layer checks (via validate_frictionless_fields,
# validate_primary_key) and custom-layer checks (via run_composite_constraints,
# run_custom_constraints).
#
# Tests follow the pattern: one test for a valid case (should produce zero
# errors), one or more tests for each violation type.

# Source the validators directly so tests do not depend on package install state.
# In CI these files are at the repo root relative paths.

# ===========================================================================
# SITES — composite constraints
# ===========================================================================

test_that("sites: valid data produces no errors", {
  df <- data.frame(
    sitename = "Test Farm",
    lat      = 45.0,
    lon      = -93.0,
    sand_pct = 40,
    clay_pct = 30,
    mat      = 10,
    map      = 800,
    stringsAsFactors = FALSE
  )
  con <- list(list(
    id      = "soil_fraction_sum",
    type    = "sum_limit",
    columns = c("sand_pct", "clay_pct"),
    operator = "<=",
    value   = 100,
    message = "sand_pct + clay_pct must not exceed 100"
  ))
  expect_length(run_composite_constraints(df, con), 0)
})

test_that("sites: sand_pct + clay_pct > 100 is caught", {
  df <- data.frame(sitename = "Bad Site", sand_pct = 70, clay_pct = 50,
                   stringsAsFactors = FALSE)
  con <- list(list(
    id      = "soil_fraction_sum",
    type    = "sum_limit",
    columns = c("sand_pct", "clay_pct"),
    operator = "<=",
    value   = 100,
    message = "sand_pct + clay_pct must not exceed 100"
  ))
  errors <- run_composite_constraints(df, con)
  expect_gt(length(errors), 0)
  expect_true(any(grepl("soil_fraction_sum", errors)))
})

test_that("sites: sand_pct + clay_pct exactly 100 passes", {
  df <- data.frame(sand_pct = 60, clay_pct = 40, stringsAsFactors = FALSE)
  con <- list(list(
    id = "soil_fraction_sum", type = "sum_limit",
    columns = c("sand_pct", "clay_pct"), operator = "<=", value = 100,
    message = "sand_pct + clay_pct must not exceed 100"
  ))
  expect_length(run_composite_constraints(df, con), 0)
})

test_that("sites: NA in sand_pct or clay_pct skips the row silently", {
  df <- data.frame(sand_pct = NA_real_, clay_pct = 90, stringsAsFactors = FALSE)
  con <- list(list(
    id = "soil_fraction_sum", type = "sum_limit",
    columns = c("sand_pct", "clay_pct"), operator = "<=", value = 100,
    message = "sand_pct + clay_pct must not exceed 100"
  ))
  # Row with NA in any summed column is skipped; no error expected
  expect_length(run_composite_constraints(df, con), 0)
})

# ===========================================================================
# SITES — Frictionless field constraints (lat, lon, mat, map, sitename)
# ===========================================================================

test_that("sites: lat out of range [-90, 90] is caught", {
  schema <- list(fields = list(
    list(name = "lat", type = "number",
         constraints = list(minimum = -90, maximum = 90))
  ))
  df <- data.frame(lat = 200, stringsAsFactors = FALSE)
  errors <- validate_frictionless_fields(df, schema, "sites")
  expect_gt(length(errors), 0)
  expect_true(any(grepl("lat", errors)))
})

test_that("sites: lon out of range [-180, 180] is caught", {
  schema <- list(fields = list(
    list(name = "lon", type = "number",
         constraints = list(minimum = -180, maximum = 180))
  ))
  df <- data.frame(lon = -200, stringsAsFactors = FALSE)
  errors <- validate_frictionless_fields(df, schema, "sites")
  expect_gt(length(errors), 0)
  expect_true(any(grepl("lon", errors)))
})

test_that("sites: sitename required — NA value is caught", {
  schema <- list(fields = list(
    list(name = "sitename", type = "string",
         constraints = list(required = TRUE))
  ))
  df <- data.frame(sitename = NA_character_, stringsAsFactors = FALSE)
  errors <- validate_frictionless_fields(df, schema, "sites")
  expect_gt(length(errors), 0)
  expect_true(any(grepl("sitename", errors)))
})

test_that("sites: mat out of range is caught", {
  schema <- list(fields = list(
    list(name = "mat", type = "number",
         constraints = list(minimum = -25, maximum = 40))
  ))
  df <- data.frame(mat = 100, stringsAsFactors = FALSE)
  errors <- validate_frictionless_fields(df, schema, "sites")
  expect_gt(length(errors), 0)
})

test_that("sites: valid lat/lon/sitename passes all Frictionless checks", {
  schema <- list(fields = list(
    list(name = "sitename", type = "string",
         constraints = list(required = TRUE)),
    list(name = "lat", type = "number",
         constraints = list(minimum = -90, maximum = 90)),
    list(name = "lon", type = "number",
         constraints = list(minimum = -180, maximum = 180))
  ))
  df <- data.frame(sitename = "Good Site", lat = 45, lon = -93,
                   stringsAsFactors = FALSE)
  expect_length(validate_frictionless_fields(df, schema, "sites"), 0)
})

# ===========================================================================
# TRAITS — conditional stat/statname pairing
# ===========================================================================

test_that("traits: stat without statname is caught", {
  df <- data.frame(mean = 5.0, stat = 0.5, statname = NA_character_,
                   stringsAsFactors = FALSE)
  con <- list(list(
    id   = "stat_requires_statname",
    type = "conditional",
    `if`   = list(column = "stat",     condition = "not_null"),
    then   = list(column = "statname", condition = "not_null_and_not_empty"),
    message = "statname is required when stat is provided"
  ))
  errors <- run_composite_constraints(df, con)
  expect_gt(length(errors), 0)
  expect_true(any(grepl("stat_requires_statname", errors)))
})

test_that("traits: statname without stat is caught", {
  df <- data.frame(mean = 5.0, stat = NA_real_, statname = "SE",
                   stringsAsFactors = FALSE)
  con <- list(list(
    id   = "statname_requires_stat",
    type = "conditional",
    `if`   = list(column = "statname", condition = "not_null_and_not_empty"),
    then   = list(column = "stat",     condition = "not_null"),
    message = "stat is required when statname is provided"
  ))
  errors <- run_composite_constraints(df, con)
  expect_gt(length(errors), 0)
})

test_that("traits: stat and statname both present passes", {
  df <- data.frame(mean = 5.0, stat = 0.5, statname = "SE",
                   stringsAsFactors = FALSE)
  con <- list(list(
    id   = "stat_requires_statname",
    type = "conditional",
    `if`   = list(column = "stat",     condition = "not_null"),
    then   = list(column = "statname", condition = "not_null_and_not_empty"),
    message = "statname is required when stat is provided"
  ))
  expect_length(run_composite_constraints(df, con), 0)
})

test_that("traits: both stat and statname NA passes (neither required)", {
  df <- data.frame(mean = 5.0, stat = NA_real_, statname = NA_character_,
                   stringsAsFactors = FALSE)
  con <- list(list(
    id   = "stat_requires_statname",
    type = "conditional",
    `if`   = list(column = "stat",     condition = "not_null"),
    then   = list(column = "statname", condition = "not_null_and_not_empty"),
    message = "statname is required when stat is provided"
  ))
  expect_length(run_composite_constraints(df, con), 0)
})

# TRAITS — Frictionless field constraints (mean required, access_level enum)

test_that("traits: mean required — NA is caught", {
  schema <- list(fields = list(
    list(name = "mean", type = "number", constraints = list(required = TRUE))
  ))
  df <- data.frame(mean = NA_real_, stringsAsFactors = FALSE)
  errors <- validate_frictionless_fields(df, schema, "traits")
  expect_gt(length(errors), 0)
  expect_true(any(grepl("mean", errors)))
})

# ===========================================================================
# TRAITS — cross-table range check (trait mean within variable min/max)
# ===========================================================================

test_that("traits: mean within variable range passes", {
  traits    <- data.frame(mean = 50, trait = "SLA", stringsAsFactors = FALSE)
  variables <- data.frame(name = "SLA", min = "0", max = "100", stringsAsFactors = FALSE)
  tables    <- list(traitsview = traits, variables = variables)

  con <- list(list(
    id       = "trait_mean_in_variable_range",
    type     = "conditional_range",
    column   = "mean",
    lookup   = list(table = "variables", key_col = "name",
                    min_col = "min", max_col = "max"),
    join_on  = "trait",
    null_means_no_limit = TRUE,
    message  = "trait mean must fall within variable min/max"
  ))
  errors <- run_custom_constraints(tables, "traitsview", con)
  expect_length(errors, 0)
})

test_that("traits: mean below variable min is caught", {
  traits    <- data.frame(mean = -5, trait = "SLA", stringsAsFactors = FALSE)
  variables <- data.frame(name = "SLA", min = "0", max = "100", stringsAsFactors = FALSE)
  tables    <- list(traitsview = traits, variables = variables)

  con <- list(list(
    id       = "trait_mean_in_variable_range",
    type     = "conditional_range",
    column   = "mean",
    lookup   = list(table = "variables", key_col = "name",
                    min_col = "min", max_col = "max"),
    join_on  = "trait",
    null_means_no_limit = TRUE,
    message  = "trait mean must fall within variable min/max"
  ))
  errors <- run_custom_constraints(tables, "traitsview", con)
  expect_gt(length(errors), 0)
  expect_true(any(grepl("trait_mean_in_variable_range", errors)))
})

test_that("traits: mean above variable max is caught", {
  traits    <- data.frame(mean = 200, trait = "SLA", stringsAsFactors = FALSE)
  variables <- data.frame(name = "SLA", min = "0", max = "100", stringsAsFactors = FALSE)
  tables    <- list(traitsview = traits, variables = variables)

  con <- list(list(
    id       = "trait_mean_in_variable_range",
    type     = "conditional_range",
    column   = "mean",
    lookup   = list(table = "variables", key_col = "name",
                    min_col = "min", max_col = "max"),
    join_on  = "trait",
    null_means_no_limit = TRUE,
    message  = "trait mean must fall within variable min/max"
  ))
  errors <- run_custom_constraints(tables, "traitsview", con)
  expect_gt(length(errors), 0)
})

test_that("traits: NULL variable min treated as -Infinity (no lower limit)", {
  traits    <- data.frame(mean = -9999, trait = "SLA", stringsAsFactors = FALSE)
  variables <- data.frame(name = "SLA", min = NA_character_, max = "100",
                           stringsAsFactors = FALSE)
  tables    <- list(traitsview = traits, variables = variables)

  con <- list(list(
    id       = "trait_mean_in_variable_range",
    type     = "conditional_range",
    column   = "mean",
    lookup   = list(table = "variables", key_col = "name",
                    min_col = "min", max_col = "max"),
    join_on  = "trait",
    null_means_no_limit = TRUE,
    message  = "trait mean must fall within variable min/max"
  ))
  # With null_means_no_limit = TRUE, NA min means no lower bound; should pass
  errors <- run_custom_constraints(tables, "traitsview", con)
  expect_length(errors, 0)
})

# ===========================================================================
# CULTIVARS — unique_combination constraint
# ===========================================================================

test_that("cultivars: duplicate name + specie_id is caught", {
  df <- data.frame(
    name      = c("Alpha", "Alpha"),
    specie_id = c(1, 1),
    stringsAsFactors = FALSE
  )
  con <- list(list(
    id      = "unique_name_per_species",
    type    = "unique_combination",
    columns = c("name", "specie_id"),
    message = "Cultivar name must be unique within a species"
  ))
  errors <- run_composite_constraints(df, con)
  expect_gt(length(errors), 0)
  expect_true(any(grepl("unique_name_per_species", errors)))
})

test_that("cultivars: same name, different species passes", {
  df <- data.frame(
    name      = c("Alpha", "Alpha"),
    specie_id = c(1, 2),
    stringsAsFactors = FALSE
  )
  con <- list(list(
    id      = "unique_name_per_species",
    type    = "unique_combination",
    columns = c("name", "specie_id"),
    message = "Cultivar name must be unique within a species"
  ))
  expect_length(run_composite_constraints(df, con), 0)
})

test_that("cultivars: required fields name and specie_id are checked", {
  schema <- list(fields = list(
    list(name = "name",      type = "string",  constraints = list(required = TRUE)),
    list(name = "specie_id", type = "number",  constraints = list(required = TRUE))
  ))
  df <- data.frame(name = NA_character_, specie_id = 1, stringsAsFactors = FALSE)
  errors <- validate_frictionless_fields(df, schema, "cultivars")
  expect_gt(length(errors), 0)
  expect_true(any(grepl("name", errors)))
})

# ===========================================================================
# PRIMARY KEY uniqueness
# ===========================================================================

test_that("primaryKey: duplicate id is caught", {
  schema <- list(primaryKey = list("id"))
  df <- data.frame(id = c(1, 1, 2), stringsAsFactors = FALSE)
  errors <- validate_primary_key(df, schema, "sites")
  expect_gt(length(errors), 0)
  expect_true(any(grepl("primaryKey", errors)))
})

test_that("primaryKey: unique ids pass", {
  schema <- list(primaryKey = list("id"))
  df <- data.frame(id = c(1, 2, 3), stringsAsFactors = FALSE)
  expect_length(validate_primary_key(df, schema, "sites"), 0)
})

test_that("primaryKey: compound key duplicate is caught", {
  schema <- list(primaryKey = list("pft_id", "specie_id"))
  df <- data.frame(
    pft_id    = c(1, 1, 2),
    specie_id = c(10, 10, 10),
    stringsAsFactors = FALSE
  )
  errors <- validate_primary_key(df, schema, "pfts_species")
  expect_gt(length(errors), 0)
})

# ===========================================================================
# VALIDATE_ALL integration — stop_on_error = FALSE returns results
# ===========================================================================

test_that("validate_all returns empty list when no errors", {
  # Minimal valid tables with no violations
  tables <- list(
    sites = data.frame(
      id = 1L, sitename = "Good Site", lat = 45, lon = -93,
      sand_pct = 30, clay_pct = 20,
      stringsAsFactors = FALSE
    )
  )
  # Use a constraints path that exists; skip datapackage check via a fake path
  constraints_path <- system.file("extdata", "custom_constraints.yaml",
                                  package = "betydata")
  skip_if_not(nzchar(constraints_path) && file.exists(constraints_path),
              "custom_constraints.yaml not installed; skipping integration test")

  result <- validate_all(
    tables           = tables,
    datapackage_path = "nonexistent_datapackage.json",  # skip Frictionless layer
    constraints_path = constraints_path,
    stop_on_error    = FALSE
  )
  expect_length(result, 0)
})

test_that("validate_all returns errors without stopping when stop_on_error = FALSE", {
  tables <- list(
    sites = data.frame(
      id = 1L, sitename = "Bad Site",
      sand_pct = 80, clay_pct = 80,  # sum > 100 — violation
      stringsAsFactors = FALSE
    )
  )
  constraints_path <- system.file("extdata", "custom_constraints.yaml",
                                  package = "betydata")
  skip_if_not(nzchar(constraints_path) && file.exists(constraints_path),
              "custom_constraints.yaml not installed; skipping integration test")

  result <- validate_all(
    tables           = tables,
    datapackage_path = "nonexistent_datapackage.json",
    constraints_path = constraints_path,
    stop_on_error    = FALSE
  )
  expect_gt(length(result), 0)
  expect_true("sites" %in% names(result))
})
# Test 1: validate_all stops on hard errors
test_that("validate_all stops when stop_on_error = TRUE and errors exist", {
  tables <- list(
    sites = data.frame(sitename = NA_character_, sand_pct = 80, clay_pct = 80)
  )
  constraints_path <- system.file("extdata", "custom_constraints.yaml",
                                  package = "betydata")
  skip_if_not(file.exists(constraints_path))
  expect_error(
    validate_all(tables, datapackage_path = "nonexistent.json",
                 constraints_path = constraints_path, stop_on_error = TRUE)
  )
})

# Test 2: YAML file loads correctly
test_that("custom_constraints.yaml loads without error", {
  path <- system.file("extdata", "custom_constraints.yaml",
                      package = "betydata")
  skip_if_not(file.exists(path))
  rules <- yaml::read_yaml(path)
  expect_true("sites" %in% names(rules))
  expect_true("traits" %in% names(rules))
  expect_true("cultivars" %in% names(rules))
})

# Test 3: Real packaged data passes all constraints
test_that("packaged sites data passes all constraints", {

  data("sites", package = "betydata")

  expect_false(any(is.na(sites$sitename)))

  both_present <- !is.na(sites$sand_pct) &
                  !is.na(sites$clay_pct)

  if (any(both_present)) {
    sums <- sites$sand_pct[both_present] +
            sites$clay_pct[both_present]

    expect_true(all(sums <= 100))
  }

  valid_mat <- sites$mat[!is.na(sites$mat)]
  if(length(valid_mat) > 0){
    expect_true(all(valid_mat >= -25 &
                    valid_mat <= 40))
  }

  valid_map <- sites$map[!is.na(sites$map)]
  if(length(valid_map) > 0){
    expect_true(all(valid_map >= 0 &
                    valid_map <= 12000))
  }
})
# ===========================================================================
# NEW CONSTRAINTS ADDED IN PR2
# ===========================================================================

test_that("citations: duplicate author-year-title is caught", {

  df <- data.frame(
    author = c("Smith","Smith"),
    year   = c(2020,2020),
    title  = c("Paper","Paper"),
    stringsAsFactors = FALSE
  )

  con <- list(list(
    id="unique_citation_identity",
    type="unique_combination",
    columns=c("author","year","title"),
    message="citation author-year-title combination must be unique"
  ))

  errors <- run_composite_constraints(df, con)

  expect_gt(length(errors),0)
})


test_that("methods: duplicate name within citation is caught", {

  df <- data.frame(
    name=c("MethodA","MethodA"),
    citation_id=c(1,1),
    stringsAsFactors=FALSE
  )

  con <- list(list(
    id="unique_method_per_citation",
    type="unique_combination",
    columns=c("name","citation_id"),
    message="method name must be unique within citation"
  ))

  errors <- run_composite_constraints(df, con)

  expect_gt(length(errors),0)
})


test_that("managements: level requires units is caught", {

  df <- data.frame(
    level=5,
    units=NA_character_,
    stringsAsFactors=FALSE
  )

  con <- list(list(
    id="level_requires_units",
    type="conditional",
    `if`=list(
      column="level",
      condition="not_null"
    ),
    then=list(
      column="units",
      condition="not_null_and_not_empty"
    ),
    message="units required when level is provided"
  ))
  errors <- run_composite_constraints(df, con)

  expect_gt(length(errors),0)
})