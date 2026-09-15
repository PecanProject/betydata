# Homepage summary helpers used by the Quarto site.

homepage_non_blank <- function(x) {
  !is.na(x) & (!is.character(x) | nzchar(trimws(x)))
}

homepage_labels <- function(x) {
  values <- trimws(as.character(x))
  sort(unique(values[homepage_non_blank(values)]))
}

homepage_collapse_labels <- function(x) {
  values <- homepage_labels(x)

  if (length(values) == 0L) {
    return(NA_character_)
  }

  paste(values, collapse = "; ")
}

homepage_metrics <- function(data) {
  tibble::tibble(
    metric = c(
      "Observations",
      "Measured variables",
      "Represented species",
      "Contributing sites",
      "Data sources"
    ),
    value = c(
      nrow(data),
      length(unique(data$trait[homepage_non_blank(data$trait)])),
      length(unique(data$species_id[!is.na(data$species_id)])),
      length(unique(data$site_id[!is.na(data$site_id)])),
      length(unique(data$citation_id[!is.na(data$citation_id)]))
    ),
    definition = c(
      "Trait and yield records in the primary dataset",
      "Distinct variables with recorded observations",
      "Distinct species linked to observation records",
      "Distinct research sites linked to observation records",
      "Distinct cited sources linked to observation records"
    )
  )
}

homepage_top_traits <- function(data, n = 10L) {
  data <- dplyr::filter(data, homepage_non_blank(data[["trait"]]))

  summary <- dplyr::summarise(
    data,
    description = homepage_collapse_labels(
      dplyr::pick("trait_description")[[1L]]
    ),
    observations = dplyr::n(),
    .by = "trait"
  )

  summary <- dplyr::arrange(
    summary,
    dplyr::desc(summary[["observations"]]),
    summary[["trait"]]
  )

  dplyr::slice_head(summary, n = n)
}

homepage_top_species <- function(data, n = 10L) {
  data <- dplyr::filter(data, !is.na(data[["species_id"]]))

  summary <- dplyr::summarise(
    data,
    scientific_name = {
      names <- homepage_labels(dplyr::pick("scientificname")[[1L]])

      if (length(names) > 1L) {
        stop(
          "Each species_id must have at most one non-blank scientific name.",
          call. = FALSE
        )
      }

      if (length(names) == 0L) NA_character_ else names
    },
    common_name = homepage_collapse_labels(
      dplyr::pick("commonname")[[1L]]
    ),
    observations = dplyr::n(),
    .by = "species_id"
  )

  summary <- dplyr::arrange(
    summary,
    dplyr::desc(summary[["observations"]]),
    summary[["scientific_name"]],
    summary[["species_id"]]
  )

  dplyr::slice_head(summary, n = n)
}
