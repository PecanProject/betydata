[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: BSD-3-Clause](https://img.shields.io/badge/code%20license-BSD--3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![License: ODC-By-1.0](https://img.shields.io/badge/data%20license-ODC--By--1.0-green.svg)](https://opendatacommons.org/licenses/by/1-0/)
[![DOI](https://img.shields.io/badge/Paper-10.1111%2Fgcbb.12420-blue.svg)](https://doi.org/10.1111/gcbb.12420)

**betydata** provides offline access to public data from the [BETYdb: Biofuel Ecophysiological Traits and Yields Database](https://betydb.org). This R data package enables reproducible analyses of plant traits, crop yields, and ecosystem service data without requiring database connectivity.

---

## Overview

|                           |                                                                        |
|---------------------------|------------------------------------------------------------------------|
| **Primary Table**         | `traitsview` - 43,532 trait and yield observations                     |
| **Support Tables**        | 15 reference tables (species, sites, variables, citations, pfts, etc.) |
| **Species Coverage**      | ~9,000 plant species with emphasis on bioenergy crops                  |
| **Geographic Scope**      | Global, with concentration in North America and Europe                 |
| **Temporal Range**        | 1900 -- present                                                        |
| **Top Genera**            | *Miscanthus*, *Panicum*, *Populus*, *Salix*, *Saccharum*               |
| **Frictionless Metadata** | [`inst/metadata/datapackage.json`](inst/metadata/datapackage.json)     |

---

## Tables

This package provides a dataset with 16 tables exported from BETYdb.

### Primary Table

| Table         | Rows   | Columns | Description                                  |
|---------------|--------|---------|----------------------------------------------|
| `traitsview`  | 43,532 | 35      | Denormalized view of plant traits and yields |

The `traitsview` table is a union of `traits` and `yields` tables in BETYdb. The unique row identifier is composite key `(result_type, id)`, not `id` alone; a given `id` can appear under both `result_type = "traits"` and `result_type = "yields"`.

### Metadata Tables

These tables provide reference data for species, sites, variables, and other entities linked to the trait observations.

| Table         | Description                                                   |
|---------------|---------------------------------------------------------------|
| `species`     | Plant taxonomy (genus, species, common names)                 |
| `sites`       | Research site locations with coordinates and climate data     |
| `variables`   | Trait/variable definitions, units, and valid ranges           |
| `citations`   | Literature references (author, year, title, DOI)              |
| `cultivars`   | Plant cultivar and variety information                        |
| `treatments`  | Experimental treatment definitions                            |
| `managements` | Management events (planting, harvest, fertilization)          |
| `methods`     | Measurement method descriptions                               |
| `pfts`        | Plant Functional Type definitions for ecological modeling     |
| `priors`      | Prior probability distributions for Bayesian analysis         |
| `entities`    | Entity identifiers for repeated measures                      |

### Relationship Tables

These junction tables connect entities in many-to-many relationships. Use `pfts_species` to find which species belong to a Plant Functional Type, or `managements_treatments` to link management practices to experimental treatments.

| Table                      | Description                    |
|----------------------------|--------------------------------|
| `pfts_species`             | PFT <-> species mapping          |
| `pfts_priors`              | PFT <-> prior mapping            |
| `cultivars_pfts`           | Cultivar <-> PFT mapping         |
| `managements_treatments`   | Management <-> treatment mapping |

---

## Installation

### From GitHub (recommended)
```r
# install.packages("remotes")
remotes::install_github("PecanProject/betydata")
```

### From source
```bash
git clone https://github.com/PecanProject/betydata.git
R CMD INSTALL betydata
```

## Quick Start
```r
library(betydata)
library(dplyr)

# Preview the primary table (columns are ordered for readability)
traitsview

# Count observations by trait
traitsview |>
  count(trait, sort = TRUE)

# Bioenergy crop yields
bioenergy_genera <- c("Miscanthus", "Panicum", "Populus", "Salix", "Saccharum")
traitsview |>
  filter(genus %in% bioenergy_genera) |>
  count(genus, sort = TRUE)
```

---

## Data Quality

### The `checked` Column

All trait and yield data include a quality control flag:

| Value | Meaning   | Status                                                    |
|-------|-----------|-----------------------------------------------------------|
| `1`   | Verified  | Independently reviewed and confirmed                      |
| `0`   | Unchecked | Not yet reviewed                                          |
| `-1`  | Flagged   | Identified as incorrect (excluded from this package)      |

This package exports only `checked >= 0` data. Flagged records (`checked = -1`) are excluded during data preparation. Records with `checked = NA` are converted to `checked = 0` (unchecked) during the build. All data in this package is public (from BETYdb records with `access_level = 4`). For restricted or flagged data, access the BETYdb PostgreSQL database directly.

---

## Reporting Data Issues

If you find errors in the data or want to report verified records:

- **Data corrections:** [File a data correction issue](https://github.com/PecanProject/betydata/issues/new?template=data_correction.md)
- **Verified records:** [Report a verified record](https://github.com/PecanProject/betydata/issues/new?template=verified_record.md)

To submit corrections via pull request, edit the relevant CSV file in `data-raw/csv/`, rebuild with `source("data-raw/make-data.R")`, and submit a PR using the data correction template.

---

## Key Traits and Yields

The `traitsview` table contains measurements of ecophysiological traits and crop yields:

### Common Traits

* **SLA** -- Specific Leaf Area (m2/kg)
* **Vcmax** -- Maximum carboxylation rate (umol/m2/s)
* **leafN** -- Leaf nitrogen content (%)
* **height** -- Plant height (m)
* **LAI** -- Leaf Area Index (m2/m2)

### Yield Variables

* **Ayield** -- Above-ground yield (Mg/ha)
* **AGBiomass** -- Above-ground biomass (Mg/ha)

Use the `variables` table for complete definitions and units:
```r
variables |>
  filter(name %in% c("SLA", "Vcmax", "Ayield")) |>
  select(name, description, units)
```

---

## Data Formats

### .rda (Default)

Lazy-loaded R data objects, available after `library(betydata)`:
```r
traitsview
```

### Frictionless Data Package

Machine-readable metadata following the Frictionless data standard:
```json
// inst/metadata/datapackage.json
{
  "name": "betydata",
  "title": "BETYdb Plant Traits and Yields Data Package",
  "licenses": [{"name": "ODC-By-1.0", ...}],
  "resources": [...]
}
```

---

## Vignettes

Detailed tutorials are available as package vignettes:

| Vignette            | Description                                              |
|---------------------|----------------------------------------------------------|
| `getting_started`   | Overview of package structure and data relationships     |
| `common_analyses`   | Common analysis patterns with dplyr                      |
| `pfts-priors`       | Working with PFTs and prior distributions                |
| `manuscript`        | Reproduce analyses from LeBauer et al. (2018)            |
```r
browseVignettes("betydata")
```
