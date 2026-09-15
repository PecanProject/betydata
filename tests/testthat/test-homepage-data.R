homepage_fixture <- function() {
  tibble::tibble(
    trait = c("SLA", "SLA", "  ", NA, "Vcmax"),
    trait_description = c(
      "Specific leaf area",
      "Specific leaf area",
      "Ignored blank trait",
      "Ignored missing trait",
      "Maximum carboxylation rate"
    ),
    species_id = c(1, 1, 2, NA, 3),
    site_id = c(10, 10, 11, NA, 20),
    citation_id = c(100, 100, 101, NA, 200),
    scientificname = c(
      "Alpha plant",
      "Alpha plant",
      "Beta plant",
      NA,
      "Gamma plant"
    ),
    commonname = c(
      "Alpha common",
      "Alpha common",
      NA,
      NA,
      "Gamma common"
    )
  )
}

test_that("homepage metrics count observations and linked entities", {
  metrics <- betydata:::homepage_metrics(homepage_fixture())

  expect_s3_class(metrics, "tbl_df")
  expect_equal(metrics$value, c(5, 2, 3, 3, 3))
})

test_that("duplicating an observation affects only the observation total", {
  data <- homepage_fixture()
  duplicated_data <- dplyr::bind_rows(data, data[1, ])

  original <- betydata:::homepage_metrics(data)$value
  duplicated <- betydata:::homepage_metrics(duplicated_data)$value

  expect_equal(duplicated, original + c(1, 0, 0, 0, 0))
})

test_that("display fields do not change homepage metrics", {
  data <- homepage_fixture()
  original <- betydata:::homepage_metrics(data)$value

  data$scientificname <- paste("renamed", seq_len(nrow(data)))
  expect_equal(betydata:::homepage_metrics(data)$value, original)
})

test_that("top traits include descriptions and sort ties deterministically", {
  top_traits <- betydata:::homepage_top_traits(homepage_fixture())

  expect_named(top_traits, c("trait", "description", "observations"))
  expect_equal(top_traits$trait, c("SLA", "Vcmax"))
  expect_equal(
    top_traits$description,
    c("Specific leaf area", "Maximum carboxylation rate")
  )
  expect_equal(top_traits$observations, c(2L, 1L))
})

test_that("top traits retain missing descriptions and combine aliases", {
  data <- tibble::tibble(
    trait = c("c2n_stem", "c2n_stem", "c2n_stem", "unknown"),
    trait_description = c(
      " C:N ratio in stems ",
      "C:N ratio in stem",
      "C:N ratio in stem",
      "  "
    )
  )

  top_traits <- betydata:::homepage_top_traits(data)

  expect_equal(
    top_traits$description[top_traits$trait == "c2n_stem"],
    "C:N ratio in stem; C:N ratio in stems"
  )
  expect_true(is.na(top_traits$description[top_traits$trait == "unknown"]))
})

test_that("top species use species IDs and retain missing common names", {
  top_species <- betydata:::homepage_top_species(homepage_fixture())

  expect_named(
    top_species,
    c("species_id", "scientific_name", "common_name", "observations")
  )
  expect_equal(top_species$species_id, c(1, 2, 3))
  expect_equal(
    top_species$scientific_name,
    c("Alpha plant", "Beta plant", "Gamma plant")
  )
  expect_equal(top_species$common_name, c("Alpha common", NA, "Gamma common"))
  expect_equal(top_species$observations, c(2L, 1L, 1L))
})

test_that("top species retain missing scientific names", {
  data <- tibble::tibble(
    species_id = c(1, 1),
    scientificname = c(NA, "  "),
    commonname = c("Unnamed plant", "Unnamed plant")
  )

  top_species <- betydata:::homepage_top_species(data)

  expect_equal(top_species$species_id, 1)
  expect_true(is.na(top_species$scientific_name))
  expect_equal(top_species$common_name, "Unnamed plant")
  expect_equal(top_species$observations, 2L)
})

test_that("top species normalize names and combine common-name aliases", {
  data <- tibble::tibble(
    species_id = c(1, 1, 1),
    scientificname = c("Alpha plant", " Alpha plant ", "Alpha plant"),
    commonname = c("Zulu name", " Alpha name ", "  ")
  )

  top_species <- betydata:::homepage_top_species(data)

  expect_equal(top_species$scientific_name, "Alpha plant")
  expect_equal(top_species$common_name, "Alpha name; Zulu name")
  expect_equal(top_species$observations, 3L)
})

test_that("top species reject conflicting scientific names for one ID", {
  data <- homepage_fixture()
  data$scientificname[2] <- "Different alpha plant"

  expect_error(
    betydata:::homepage_top_species(data),
    "at most one non-blank scientific name"
  )
})

test_that("homepage helpers agree with direct traitsview calculations", {
  data("traitsview", package = "betydata")
  metrics <- betydata:::homepage_metrics(traitsview)
  non_blank <- function(x) !is.na(x) & (!is.character(x) | nzchar(trimws(x)))

  expect_equal(metrics$value, c(
    nrow(traitsview),
    length(unique(traitsview$trait[non_blank(traitsview$trait)])),
    length(unique(traitsview$species_id[!is.na(traitsview$species_id)])),
    length(unique(traitsview$site_id[!is.na(traitsview$site_id)])),
    length(unique(traitsview$citation_id[!is.na(traitsview$citation_id)]))
  ))

  expected_traits <- traitsview |>
    dplyr::filter(non_blank(trait)) |>
    dplyr::count(trait, name = "observations") |>
    dplyr::arrange(dplyr::desc(observations), trait)
  actual_traits <- betydata:::homepage_top_traits(
    traitsview,
    n = nrow(expected_traits)
  )

  expect_equal(
    actual_traits[c("trait", "observations")],
    expected_traits[c("trait", "observations")]
  )

  expected_species <- traitsview |>
    dplyr::filter(!is.na(species_id)) |>
    dplyr::count(species_id, name = "observations") |>
    dplyr::arrange(dplyr::desc(observations), species_id)
  actual_species <- betydata:::homepage_top_species(
    traitsview,
    n = nrow(expected_species)
  )

  expect_equal(
    dplyr::arrange(
      actual_species[c("species_id", "observations")],
      species_id
    ),
    dplyr::arrange(expected_species, species_id)
  )
})
