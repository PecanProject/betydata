[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: BSD-3-Clause](https://img.shields.io/badge/code%20license-BSD--3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![License: ODC-By-1.0](https://img.shields.io/badge/data%20license-ODC--By--1.0-green.svg)](https://opendatacommons.org/licenses/by/1-0/)
[![DOI](https://img.shields.io/badge/Paper-10.1111%2Fgcbb.12420-blue.svg)](https://doi.org/10.1111/gcbb.12420)

**betydata** provides offline access to public data from the [BETYdb: Biofuel Ecophysiological Traits and Yields Database](https://betydb.org). This R data package enables reproducible analyses of plant traits, crop yields, and ecosystem service data without requiring database connectivity.

---

## Overview

|                           |                                                                        |
|---------------------------|------------------------------------------------------------------------|
| **Primary Dataset**       | `traitsview` - 43,532 trait and yield observations                     |
| **Support Tables**        | 15 reference tables (species, sites, variables, citations, pfts, etc.) |
| **Species Coverage**      | ~9,000 plant species with emphasis on bioenergy crops                  |
| **Geographic Scope**      | Global, with concentration in North America and Europe                 |
| **Temporal Range**        | 1900 – present                                                         |
| **Top Genera**            | *Miscanthus*, *Panicum*, *Populus*, *Salix*, *Saccharum*               |
| **Data License**          | [ODC-By-1.0](https://opendatacommons.org/licenses/by/1-0/)             |
| **Frictionless Metadata** | [`inst/metadata/datapackage.json`](inst/metadata/datapackage.json)     |

---

## Datasets

This package provides 16 datasets exported from BETYdb:

### Primary Dataset

| Dataset       | Rows   | Columns | Description                                  |
|---------------|--------|---------|----------------------------------------------|
| `traitsview`  | 43,532 | 36      | Denormalized view of plant traits and yields |
| Dataset       | Description                                                   |
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

| Dataset                    | Description                    |
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

# Load the primary dataset
data(traitsview)

# Explore structure
str(traitsview)
head(traitsview)

# Count observations by trait
library(dplyr)
traitsview |> count(trait, sort = TRUE)

# Count by genus (top bioenergy crops)
traitsview |> count(genus, sort = TRUE) |> head(10)
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

**Note:** This package exports only `checked >= 0` data. Flagged records (`checked = -1`) are excluded during data preparation. For research requiring unchecked data, access the BETYdb PostgreSQL database directly.

### Access Levels

All data in this package is publicly available (`access_level = 4`). Restricted data (`access_level` 1–3) requires database access with appropriate permissions.

---

## Key Traits and Yields

The `traitsview` dataset contains measurements of ecophysiological traits and crop yields:

### Common Traits

* **SLA** - Specific Leaf Area (m2/kg)
* **Vcmax** - Maximum carboxylation rate (umol/m2/s)
* **leafN** - Leaf nitrogen content (%)
* **height** - Plant height (m)
* **LAI** - Leaf Area Index (m2/m2)

### Yield Variables

* **Ayield** - Above-ground yield (Mg/ha)
* **AGBiomass** - Above-ground biomass (Mg/ha)

Use the `variables` table for complete definitions and units:
```r
data(variables)
variables |> 
  filter(name %in% c("SLA", "Vcmax", "Ayield")) |>
  select(name, description, units)
```

---

## Data Formats

### .rda (Default)

Lazy-loaded R data objects, optimized for R workflows:
```r
data(traitsview)
```

### Parquet (Alternative)

For use with Arrow/DuckDB or cross-platform workflows:
```r
library(arrow)
traitsview <- read_parquet(
  system.file("extdata/parquet/traitsview.parquet", package = "betydata")
)
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

| Vignette       | Description                                              |
|----------------|----------------------------------------------------------|
| `orientation`  | Overview of package structure and data relationships     |
| `sql-analogs`  | Migrate BETYdb SQL queries to R with dplyr               |
| `pfts-priors`  | Working with PFTs and prior distributions                |
| `manuscript`   | Reproduce analyses from LeBauer et al. (2018)            |
```r
browseVignettes("betydata")
```