# betydata (development version)

# betydata 0.1.0

## Initial Release

* First public release of betydata
* Exported datasets from BETYdb snapshot (2026-02-10):
  - `traitsview`: 43,532 records (traits + yields view)
  - 15 support tables: species, sites, variables, citations, pfts, priors, etc.
* Data quality:
  - Excludes `checked = -1` records (failed QA/QC)
  - Converts `checked = NA` to `checked = 0` (unchecked)
  - Public data only (`access_level == 4`); build enforces this with a hard filter
* Format: `.rda` files with xz compression (lazy-loaded)
* Metadata:
  - Frictionless `datapackage.json` at repo root (following Frictionless spec)
  - Full roxygen2 documentation for all datasets
* Vignettes:
  - `getting_started`: Package overview, data model, and key concepts
  - `manuscript`: Reproduction of key GCB bioenergy figures
  - `common_analyses`: Common SQL queries as dplyr equivalents
  - `pfts-priors`: Working with PFTs and Bayesian priors
* Source CSVs in `data-raw/csv/` under version control for community corrections
* `inst/CITATION` for `citation("betydata")` support
* `inst/STYLE_GUIDE.md` documenting package conventions
* Data correction workflow: issue templates and PR template for corrections
* Github actions for R CMD check and quarto site deployment
