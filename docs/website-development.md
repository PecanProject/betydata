# Developing the BETYdb website

The public website uses Quarto, R, plain JavaScript, and CSS. No backend, database credentials, or frontend framework is required. The site's browser data search is separate from Quarto's documentation search.

## Build this checkout

Use R and Quarto with the package's development dependencies, plus `readr` and `jsonlite` for website generation. Use Node.js with the committed `package-lock.json` for frontend checks. Run commands from the repository root.

Install **this checkout**, rather than relying on a previously installed package:

```sh
TEST_LIB="$(mktemp -d)"
R CMD INSTALL --library="$TEST_LIB" .
export R_LIBS="$TEST_LIB${R_LIBS:+:$R_LIBS}"
Rscript -e 'testthat::test_local()'
quarto render --execute
```

The website generator loads `.rda` datasets directly from this checkout into isolated environments. The temporary package installation ensures the R examples in the vignettes also use this checkout. Retain the temporary library until all checks are finished.

Quarto's project pre-render hook runs `scripts/build-search-index.R`, including for individual-page renders. To regenerate only the public data assets:

```sh
Rscript scripts/build-search-index.R
```

This creates `site-data/observations.csv`, `site-data/search-index.json`, and `site-data/summary.json`. These outputs are ignored, copied into the rendered website, and **must not be committed**. Do not hand-edit them. Rebuild after packaged data changes. The homepage has `freeze: false` and reads the generated summary, so data changes refresh its metrics without touching `index.qmd`.

## Public-data contract

The generator exports the complete packaged public observation dataset, preserving its columns. It independently validates the packaged observations against the raw-source transformation: retain `access_level == 4`, turn missing QC flags into unchecked (`checked = 0`), then exclude failed QC (`checked < 0`). It rejects data disagreements, invalid values, and duplicate `(result_type, id)` identities. Never bypass a failed validation or publish the raw source CSV as the observation download.

CSV round-trip checks and index identities must agree with the package. Numeric database IDs can exceed signed 32-bit integers; preserve exact numeric identifiers instead of coercing them to R integers. Stable record ordering and source hashes keep generated outputs reproducible.

The compact JSON has a schema version, column names, observation row arrays, and separate variable definitions. All catalog IDs are retained. Observations identify variable **names**, so catalog descriptions enrich searchable text through a lookup without duplicating observation rows. Counts displayed beside definitions are explicitly **name-level counts**; duplicate-name definitions share the same count and cannot be added together.

Keyword tokens match author, species, variable name, observation description, and descriptions associated with that exact variable name. All active filters are combined with AND. Catalog results search their own name/description; species and author filters change their contextual counts but do not hide otherwise matching definitions. The UI fetches the index only after a nonblank submission or a populated query URL.

## Test and inspect

```sh
npm ci
npm test
npx playwright install chromium
npm run test:browser
npm run check:site
Rscript scripts/test-site-freshness.R
python3 scripts/check-reproducibility.py
Rscript -e 'devtools::check(args = "--no-manual")'
```

The browser suite starts `scripts/serve-site.mjs` automatically and exercises the same `_site` output at both `/` and `/betydata/`. For manual inspection:

```sh
node scripts/serve-site.mjs
```

Open <http://127.0.0.1:8765/> and <http://127.0.0.1:8765/betydata/>. Check narrow mobile and desktop layouts, 200% zoom, keyboard focus, screen-reader announcements, pagination, shared search URLs, offline/retry behavior, and downloads. Automated axe results complement, but do not replace, manual keyboard and screen-reader checks.

Repeat clean builds under the same R, Quarto, Node.js, package, and browser versions when comparing output hashes and timings. Record cold first-search and cached-search measurements with their browser/throttling conditions. No observation index should be requested on the homepage or an untouched explorer. The initial budgets are 10 MB for uncompressed search indexes and 100 MB for the entire published site.

A passing local build does not prove that hosted deployment, DNS, or a real mobile device works. Report unavailable checks and environment failures separately from code defects. The read-only pull-request workflow builds and tests the site and provides a downloadable artifact; production publishing remains on `main`.

## Scope, attribution, and follow-up

The observation-based summary approach credits [PR #33](https://github.com/PecanProject/betydata/pull/33). This contribution supersedes its homepage implementation with one shared generator, rather than maintaining two summary paths. Recommend closing #33 only after this implementation is accepted; no automatic PR changes are made.

Original historical sponsor logos and their pinned source revision are documented in [asset attribution](../site-assets/ATTRIBUTION.md). Data licensing, citation, and study-quality guidance live on the public About page.

The exact legacy URL inventory and unresolved service dependencies are recorded in [legacy URL mapping](legacy-url-mapping.md). Domain redirects, authenticated data entry, machine API compatibility, and Rails retirement belong to [issue #16](https://github.com/PecanProject/betydata/issues/16). Reusable legacy documentation migration belongs to [issue #17](https://github.com/PecanProject/betydata/issues/17). This website must not silently replace machine API responses or upload services with static HTML.

The explorer uses the `query` URL parameter for keywords (`variable`, `species`,
and `author` for filters). Quarto reserves `q` for documentation search.
