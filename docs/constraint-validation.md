# Data Constraint Validation

## Overview

The `betydata` package enforces key integrity constraints inherited from
BETYdb’s PostgreSQL schema using a layered validation system plus build-time
filtering during data preparation.

Validation runs automatically in `data-raw/make-data.R` before `.rda` package
data are generated. Constraint violations are either reported, used to halt
validation when appropriate, or quarantined into `data-raw/invalid_data/`.

Detailed audit decisions and rationale for implemented vs deferred constraints
are documented in:

`docs/constraint-decisions.md`

---

# Validation Architecture

Three complementary layers are used.

## Layer 1 — Frictionless Constraints (`datapackage.json`)

Used for constraints natively expressible through schema metadata:

- required fields
- numeric bounds
- enumerated values
- uniqueness
- primary keys
- foreign keys

Validated through:

- `validate_frictionless_fields()`
- `validate_primary_key()`
- `validate_foreign_keys()`

### Current Frictionless Constraint Coverage

| Table | Field | Constraint |
|---|---|---|
| sites | sitename | required |
| sites | mat | -25 to 40 |
| sites | map | 0 to 12000 |
| sites | sand_pct | 0 to 100 |
| sites | clay_pct | 0 to 100 |
| traitsview | mean | required |
| traitsview | lat | -90 to 90 |
| traitsview | lon | -180 to 180 |
| traitsview | checked | enum: 0,1 |
| cultivars | name | required |
| cultivars | specie_id | required + foreign key |
| species | genus | required |
| species | species | required |
| species | scientificname | required + unique |
| citations | author | required |
| citations | year | bounded numeric |
| citations | title | required |
| pfts | definition | required |
| pfts | name | unique |
| priors | distn | enum constraint |
| All tables | id | primary key |

---

## Layer 2 — Custom Constraints (`custom_constraints.yaml`)

Used for rules Frictionless cannot represent:

- cross-field arithmetic
- conditional dependencies
- compound uniqueness
- cross-table lookups

Implemented in:

`R/validate_custom.R`

### Supported Constraint Types

| Type | Example |
|---|---|
| `sum_limit` | sand_pct + clay_pct ≤ 100 |
| `conditional` | stat requires statname |
| `unique_combination` | cultivar name unique per species |
| `conditional_range` | trait mean within variable range |

### Current Custom Constraint Coverage

| Table | Constraint | Type |
|---|---|---|
| sites | sand_pct + clay_pct <= 100 | sum_limit |
| traits | stat -> statname dependency | conditional |
| traits | statname -> stat dependency | conditional |
| traits | mean within variable min/max | conditional_range |
| cultivars | name unique per species | unique_combination |
| citations | author-year-title uniqueness | unique_combination |
| methods | name unique per citation | unique_combination |
| managements | level requires units | conditional |

---

## Cross-Table Range Note

Trait range validation joins:

`traitsview.trait` → `variables.name`

(not `variable_id`, which is absent from `traitsview`).

The validator interprets numeric ranges while handling:

- `Inf`
- `-Inf`
- `NA`

for open-ended limits.

---

## Layer 3 — Build-Time Filtering (`make-data.R`)

Some integrity rules are currently enforced during data preparation via:

- `access_level == 4` filtering (public records only)
- `checked >= 0` filtering (exclude failed QC)
- quarantine of invalid records in:

`data-raw/invalid_data/`

Filtering complements explicit validation and is treated as part of current
build-time enforcement.

---

# Additions from Issue #14 Constraint Coverage Audit

Additional coverage added through the Issue #14 audit included:

## Frictionless Additions
Added constraint groups for:

- species completeness + uniqueness
- citation completeness
- PFT completeness + uniqueness
- priors distribution validation

## Custom Constraint Additions Reviewed

Five candidate custom additions were reviewed.

Implemented:

- citation natural-key uniqueness
- methods uniqueness within citation
- units required when level present

Reviewed and deferred after empirical validation:

- management event uniqueness  
  (global `(date, mgmttype)` produced false positives)

- prior uniqueness keys  
  (candidate uniqueness assumptions violated in shipped data)

---

# Deferred Constraints (Documented, Not Implemented)

The following were reviewed but intentionally deferred:

| Constraint | Reason |
|---|---|
| variables min <= max | requires new validator type |
| statname controlled vocabulary | needs vocabulary review |
| priors parameter dependency | needs additional rule design |
| priors paramb required | current data contains missing values |
| methods description required | current data contains missing values |
| management event uniqueness | false positives in shipped data |
| prior uniqueness key | uniqueness definition unresolved |
| advanced geometry uniqueness | too complex for current scope |

Deferred constraints and rationale are tracked in:

`docs/constraint-decisions.md`

---

# R Implementation

## `validate_all()`
Coordinates:

- Frictionless checks
- custom YAML checks
- stop vs report behavior

---

## `validate_custom()`
Dispatches to:

- `run_sum_limit()`
- `run_conditional()`
- `run_unique_combination()`
- `run_conditional_range()`

Validation is invoked during package build from:

`data-raw/make-data.R`

---

# Running Validation Manually

```r
source("R/validate_custom.R")
source("R/validate.R")

tables <- list(
  sites = sites,
  traitsview = traitsview,
  cultivars = cultivars,
  variables = variables
)

validate_all(tables, stop_on_error = FALSE)
```

---

# Tests

Constraint behavior is covered in:

`tests/testthat/test_constraints.R`

Includes tests for:

- valid data passes
- intentionally invalid mock data fails
- composite constraints
- conditional constraints
- cross-table range validation
- added uniqueness constraints

Note:

A legacy row-count expectation in `test-data.R`

```r
expect_gt(nrow(traitsview), 40000)
```

may fail on filtered/public packaged data (~18010 rows) and is unrelated to
constraint logic.

---

# Adding New Constraints

If Frictionless can express the rule:

- add it to `datapackage.json`
- add valid + invalid tests

If it is cross-field or cross-table:

- add to `custom_constraints.yaml`
- add corresponding tests in `test_constraints.R`

If a new constraint type is needed:

- implement runner in `validate_custom.R`
- register it in the constraint dispatcher

---

## Scope Note

This documentation describes constraints relevant to tables shipped in this
repository. Constraints from non-shipped BETYdb tables or high-complexity
business logic may be documented but intentionally not migrated.