# betydata (development version)

# betydata 0.1.0

## Initial Release

* First public release of betydata
* Exported datasets from BETYdb snapshot (2026-02-10):
  - `traitsview`: 43,532 records (traits + yields view)
  - 15 support tables: species, sites, variables, citations, pfts, priors, etc.
* Data quality:
  - Excludes [checked = -1] records (failed QA/QC)
  - Public data only (`access_level >= 4`)
* Formats:

  - Primary: `.rda` files with xz compression
  - Alternative: Parquet files in `inst/extdata/parquet/`
* Metadata:
  - Frictionless `datapackage.json` in `inst/metadata/`
  - Full roxygen2 documentation for all datasets
* Vignettes:
  - `orientation`: Getting started guide
  - `manuscript`: Reproduction of key GCB Bioenergy figures
  - `sql-analogs`: Common SQL queries as dplyr equivalents
  - `pfts-priors`: Working with PFTs and Bayesian priors
* GitHub issue templates for data corrections and verification
