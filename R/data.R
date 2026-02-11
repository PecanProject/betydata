# Dataset documentation for betydata package

#' Traits and yields from BETYdb
#'
#' A denormalized view combining plant trait measurements and crop yield data
#' from the BETYdb database. This is the primary dataset for offline analysis.
#'
#' @format A data frame with trait and yield observations. 
#'   Use `names(traitsview)` to see all columns. Key columns include
#'   checked (quality flag), result_type, id, mean, units, trait, and scientificname.
#' @source <https://betydb.org>, exported from traits_and_yields_view
#' @seealso [species], [sites], [variables], [citations]
#' @examples
#' head(traitsview)
#' names(traitsview)
"traitsview"

#' Species taxonomy from BETYdb
#'
#' Taxonomic information for plant species in BETYdb including USDA PLANTS
#' database attributes.
#'
#' @format A data frame. Key columns include id, genus, species, scientificname,
#'   commonname. See `names(species)` for all columns.
#' @source <https://betydb.org>
"species"

#' Research sites from BETYdb
#'
#' Geographic and metadata for research sites.
#'
#' @format A data frame. Key columns include id, sitename, city, state, country.
#'   See `names(sites)` for all columns.
#' @source <https://betydb.org>
"sites"

#' Variable definitions from BETYdb
#'
#' Definitions and metadata for measured variables/traits.
#'
#' @format A data frame. Key columns include id, name, description, units.
#'   See `names(variables)` for all columns.
#' @source <https://betydb.org>
"variables"

#' Literature citations from BETYdb
#'
#' Bibliographic references for data sources.
#'
#' @format A data frame. Key columns include id, author, year, title, journal, doi.
#'   See `names(citations)` for all columns.
#' @source <https://betydb.org>
"citations"

#' Plant cultivars from BETYdb
#'
#' @format A data frame with cultivar information.
#'   See `names(cultivars)` for all columns.
#' @source <https://betydb.org>
"cultivars"

#' Measurement methods from BETYdb
#'
#' @format A data frame with method descriptions.
#'   See `names(methods)` for all columns.
#' @source <https://betydb.org>
"methods"

#' Experimental treatments from BETYdb
#'
#' @format A data frame with treatment definitions.
#'   See `names(treatments)` for all columns.
#' @source <https://betydb.org>
"treatments"

#' Plant Functional Types (PFTs) from BETYdb
#'
#' PFT definitions used for grouping species for modeling.
#'
#' @format A data frame. Key columns include id, name, definition.
#'   See `names(pfts)` for all columns.
#' @source <https://betydb.org>
#' @seealso [pfts_species], [pfts_priors]
"pfts"

#' Prior distributions from BETYdb
#'
#' Prior probability distributions for Bayesian analysis.
#'
#' @format A data frame. Key columns include id, variable_id, distn, parama, paramb.
#'   See `names(priors)` for all columns.
#' @source <https://betydb.org>
#' @seealso [pfts_priors], [variables]
"priors"

#' Management practices from BETYdb
#'
#' @format A data frame with management event data.
#'   See `names(managements)` for all columns.
#' @source <https://betydb.org>
"managements"

#' Entities from BETYdb
#'
#' @format A data frame with entity (individual/plot) information.
#'   See `names(entities)` for all columns.
#' @source <https://betydb.org>
"entities"

#' PFT-Species mapping from BETYdb
#'
#' Many-to-many relationship linking PFTs to species.
#'
#' @format A data frame with columns pft_id and specie_id (plus metadata).
#'   See `names(pfts_species)` for all columns.
#' @source <https://betydb.org>
"pfts_species"

#' PFT-Prior mapping from BETYdb
#'
#' Many-to-many relationship linking PFTs to priors.
#'
#' @format A data frame with columns pft_id and prior_id (plus metadata).
#'   See `names(pfts_priors)` for all columns.
#' @source <https://betydb.org>
"pfts_priors"

#' Management-Treatment mapping from BETYdb
#'
#' Many-to-many relationship linking managements to treatments.
#'
#' @format A data frame with columns management_id and treatment_id (plus metadata).
#'   See `names(managements_treatments)` for all columns.
#' @source <https://betydb.org>
"managements_treatments"

#' Cultivar-PFT mapping from BETYdb
#'
#' Many-to-many relationship linking cultivars to PFTs.
#'
#' @format A data frame with columns cultivar_id and pft_id (plus metadata).
#'   See `names(cultivars_pfts)` for all columns.
#' @source <https://betydb.org>
"cultivars_pfts"