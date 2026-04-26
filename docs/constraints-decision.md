# Constraint Coverage Decisions for Issue #14

## Purpose

This document records constraint coverage decisions made while reviewing
constraints relevant to shipped tables in `betydata`.

It is a decision audit, not a full reproduction of the legacy constraints
spreadsheet. For each reviewed constraint, this documents whether it is:

- implemented
- already covered
- deferred with rationale
- intentionally not migrated

Constraints are not silently omitted; reviewed constraints are explicitly
classified.

---

# Sources Reviewed

Constraint coverage decisions were derived from three sources of truth:

1. BETYdb constraint documentation (Overleaf PDF)

2. Constraints Spreadsheet  
   (legacy constraint inventory)

3. `db/structure.sql` and associated PostgreSQL triggers / migrations in
   the BETY repository

Only constraints relevant to tables shipped in this repository were considered.

---

# Status Codes

| Status | Meaning |
|---|---|
| Implemented | Added or enforced in this PR |
| Covered | Already enforced elsewhere in package |
| Deferred | Reviewed but intentionally not implemented |
| Excluded | Outside package scope |

---

# Coverage Matrix

## Existing Constraints Reviewed and Retained

| Constraint | Source | Status | Enforcement |
|---|---|---|---|
| Required fields / primary keys | SQL + datapackage | Covered | datapackage.json |
| Foreign key coverage | SQL | Covered | validation layer |
| Soil fraction sum | site.rb | Covered | custom YAML |
| stat/statname dependency | trait.rb | Covered | custom YAML |
| Trait mean variable range | SQL trigger | Covered | custom YAML |
| Cultivar uniqueness | SQL / model | Covered | custom YAML |

---

## Added in this PR — Frictionless Constraints

| Constraint Group | Status | Location |
|---|---|---|
| Species completeness + uniqueness | Implemented | datapackage.json |
| Citation completeness constraints | Implemented | datapackage.json |
| PFT completeness + uniqueness | Implemented | datapackage.json |
| Priors distribution enum | Implemented | datapackage.json |

---

## Candidate Custom Constraints Reviewed

Five candidate additions were reviewed.

### Implemented

| Constraint | Status | Location |
|---|---|---|
| Citation author-year-title uniqueness | Implemented | custom YAML |
| Method uniqueness within citation | Implemented | custom YAML |
| Units required when level present | Implemented | custom YAML |

---

### Reviewed and Deferred After Validation

These were investigated but deferred because empirical checks showed proposed
uniqueness assumptions were too broad.

| Constraint | Reason |
|---|---|
| Management event uniqueness | `(date, mgmttype)` produced false positives in shipped data |
| Prior uniqueness key | Candidate uniqueness keys violated in current data |

---

# Additional Deferred Constraints

Reviewed but intentionally deferred:

| Constraint | Reason |
|---|---|
| variables min <= max | requires new validator type |
| statname controlled vocabulary | requires vocabulary review |
| priors parameter dependency | requires additional rule design |
| priors paramb required | current data contains missing values |
| methods description required | current data contains missing values |
| advanced geometry uniqueness | too complex for current scope |

---

# Explicitly Excluded

Not migrated intentionally:

- constraints involving non-shipped tables
- high-complexity multi-table business logic
- constraints redundant with package structure or foreign keys
- legacy business rules with poor CSV-era fit

Examples:

- `ensure_correct_cultivar_for_site`
- deep multi-table trigger logic
- geometry co-dependence beyond documented checks

---

# Build-Time Filtering as Enforcement

Some integrity rules are currently enforced during package build through:

- access-level filtering
- QC filtering (`checked >= 0`)
- quarantine of invalid rows into `data-raw/invalid_data/`

These are treated as build-time enforcement complementary to runtime validation.

Filtering logic was reviewed but intentionally not redesigned in this work.

---

# Coverage Summary

## Reviewed in this PR

### Already covered and retained
- structural schema constraints
- foreign key integrity
- numeric range constraints
- existing custom constraints

### New Frictionless additions
4 constraint groups implemented

### Candidate custom additions reviewed
5 reviewed

Implemented:
- 3

Deferred after empirical validation:
- 2

### Additional deferred constraints documented
6

---

## Scope Decision

This work prioritizes constraints that:

- prevent real data corruption
- are maintainable in CSV-based validation
- fit shipped package tables
- provide high value relative to implementation complexity

The goal is selective, documented migration — not exhaustive reproduction of
all historical BETYdb constraints.

---

## Result

This contributes:

- additional machine-readable constraints
- expanded custom validation coverage
- explicit documentation of omissions
- empirical review of candidate constraints
- documented distinction between implemented vs deferred rules