# Dataset documentation for betydata package

#' Traits and Yields from BETYdb
#'
#' A denormalized view combining plant trait measurements and crop yield data
#' from the BETYdb database. This is the primary dataset for offline analysis.
#'
#' @format A data frame with 43,532 rows and 36 columns:
#' \describe{
#'   \item{checked}{Data quality flag: 0 = unchecked, 1 = verified, -1 = flagged (excluded)}
#'   \item{result_type}{Type of measurement: "traits" or "yields"}
#'   \item{id}{Unique identifier for the trait or yield record}
#'   \item{citation_id}{Foreign key to citations table}
#'   \item{site_id}{Foreign key to sites table}
#'   \item{treatment_id}{Foreign key to treatments table}
#'   \item{sitename}{Name of the research site}
#'   \item{city}{City or region where site is located}
#'   \item{lat, lon}{Site coordinates (decimal degrees)}
#'   \item{scientificname}{Species scientific name (Genus species)}
#'   \item{commonname}{Species common name}
#'   \item{genus}{Taxonomic genus}
#'   \item{species_id}{Foreign key to species table}
#'   \item{cultivar_id}{Foreign key to cultivars table (may be NA)}
#'   \item{author}{Citation author(s)}
#'   \item{citation_year}{Year of publication}
#'   \item{treatment}{Experimental treatment name}
#'   \item{date}{Formatted measurement date (human-readable)}
#'   \item{time}{Time of measurement or confidence indicator}
#'   \item{raw_date}{Raw timestamp from database}
#'   \item{month, year}{Extracted month and year}
#'   \item{dateloc}{Date location confidence (1-9 scale)}
#'   \item{trait}{Variable/trait name (e.g. "SLA", "Vcmax", "Ayield")}
#'   \item{trait_description}{Description of the trait/variable}
#'   \item{mean}{Mean value of the measurement}
#'   \item{units}{Units of measurement}
#'   \item{n}{Sample size}
#'   \item{statname}{Type of uncertainty statistic (SE, SD, etc.)}
#'   \item{stat}{Value of the uncertainty statistic}
#'   \item{notes}{Additional notes}
#'   \item{access_level}{Data access level (4 = public)}
#'   \item{cultivar}{Cultivar name if applicable}
#'   \item{entity}{Entity name (for repeated measures)}
#'   \item{method_name}{Measurement method name}
#' }
#' @source \url{https://betydb.org}, exported from traits_and_yields_view
#' @seealso [species], [sites], [variables], [citations]
#' @examples
#' head(traitsview)
#' 
#' # Count by trait
#' if (requireNamespace("dplyr", quietly = TRUE)) {
#'   dplyr::count(traitsview, trait, sort = TRUE)
#' }
"traitsview"

#' Species taxonomy from BETYdb
#'
#' Taxonomic information for plant species in BETYdb.
#'
#' @format A data frame with columns including:
#' \describe{
#'   \item{id}{Species identifier}
#'   \item{spcd}{Species code}
#'   \item{genus}{Taxonomic genus}
#'   \item{species}{Specific epithet}
#'   \item{scientificname}{Full scientific name}
#'   \item{commonname}{Common name(s)}
#' }
#' @source \url{https://betydb.org}
"species"

#' Research sites from BETYdb
#'
#' Geographic and metadata for research sites.
#'
#' @format A data frame with columns including:
#' \describe{
#'   \item{id}{Site identifier}
#'   \item{sitename}{Site name}
#'   \item{city, state, country}{Location}
#'   \item{lat, lon}{Coordinates (decimal degrees)}
#'   \item{mat, map}{Mean annual temperature and precipitation}
#' }
#' @source \url{https://betydb.org}
"sites"

#' Variable definitions from BETYdb
#'
#' Definitions and metadata for measured variables/traits.
#'
#' @format A data frame with columns including:
#' \describe{
#'   \item{id}{Variable identifier}
#'   \item{name}{Variable name (e.g., "SLA", "Vcmax")}
#'   \item{description}{Full description}
#'   \item{units}{Standard units}
#'   \item{min, max}{Valid range}
#' }
#' @source \url{https://betydb.org}
"variables"

#' Literature citations from BETYdb
#'
#' Bibliographic references for data sources.
#'
#' @format A data frame with columns including:
#' \describe{
#'   \item{id}{Citation identifier}
#'   \item{author}{Author(s)}
#'   \item{year}{Publication year}
#'   \item{title}{Article/book title}
#'   \item{journal}{Journal name}
#'   \item{doi}{Digital Object Identifier}
#' }
#' @source \url{https://betydb.org}
"citations"

#' Plant cultivars from BETYdb
#' @format A data frame with cultivar information.
#' @source \url{https://betydb.org}
"cultivars"

#' Measurement methods from BETYdb
#' @format A data frame with method descriptions.
#' @source \url{https://betydb.org}
"methods"

#' Experimental treatments from BETYdb
#' @format A data frame with treatment definitions.
#' @source \url{https://betydb.org}
"treatments"

#' Plant Functional Types (PFTs) from BETYdb
#'
#' PFT definitions used for grouping species for modeling.
#'
#' @format A data frame with columns including:
#' \describe{
#'   \item{id}{PFT identifier}
#'   \item{name}{PFT name (e.g. "temperate.deciduous")}
#'   \item{definition}{Full definition}
#' }
#' @source \url{https://betydb.org}
#' @seealso [pfts_species], [pfts_priors]
"pfts"

#' Prior distributions from BETYdb
#'
#' Prior probability distributions for Bayesian analysis.
#'
#' @format A data frame with columns including:
#' \describe{
#'   \item{id}{Prior identifier}
#'   \item{variable_id}{Associated variable}
#'   \item{distn}{Distribution type (e.g. "norm", "gamma")}
#'   \item{parama, paramb, paramc}{Distribution parameters}
#' }
#' @source \url{https://betydb.org}
#' @seealso [pfts_priors], [variables]
"priors"

#' Management practices from BETYdb
#' @format A data frame with management event data.
#' @source \url{https://betydb.org}
"managements"

#' Entities from BETYdb
#' @format A data frame with entity (individual/plot) information.
#' @source \url{https://betydb.org}
"entities"

#' PFT-Species mapping from BETYdb
#'
#' Many-to-many relationship linking PFTs to species.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{pft_id}{Foreign key to pfts}
#'   \item{specie_id}{Foreign key to species}
#' }
#' @source \url{https://betydb.org}
"pfts_species"

#' PFT-Prior mapping from BETYdb
#'
#' Many-to-many relationship linking PFTs to priors.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{pft_id}{Foreign key to pfts}
#'   \item{prior_id}{Foreign key to priors}
#' }
#' @source \url{https://betydb.org}
"pfts_priors"

#' Management-Treatment mapping from BETYdb
#'
#' Many-to-many relationship linking managements to treatments.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{management_id}{Foreign key to managements}
#'   \item{treatment_id}{Foreign key to treatments}
#' }
#' @source \url{https://betydb.org}
"managements_treatments"

#' Cultivar-PFT mapping from BETYdb
#'
#' Many-to-many relationship linking cultivars to PFTs.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{cultivar_id}{Foreign key to cultivars}
#'   \item{pft_id}{Foreign key to pfts}
#' }
#' @source \url{https://betydb.org}
"cultivars_pfts"