# Issue #15 implementation and local verification

Verified on 2026-10-17 in `/home/linux/betydata`, on
`feat/15-betydb-website-search`. Comparison baseline:
`0a81116a45f18fde2e53b2e5a698338474854fce` from PecanProject/betydata.
Changes are left unstaged. No Git staging, commit, push, PR modification,
deployment, DNS change, or service retirement was performed.

## Implemented behavior

- BETYdb homepage with all six requested actions, prominent data search,
  observation-based summary cards, and original historically attributed sponsor
  graphics. Public access, contribution, citation, licensing, and terms guidance
  are separate from the preserved R guides and vignette URLs.
- Static explorer with literal token matching across author, species, variable,
  observation description, and associated catalog descriptions; combined filters;
  25-observation and 10-definition pagination; shareable URLs and browser history.
  Separate catalog IDs remain visible, including definitions with no matching
  observations. Duplicate variable names share explicitly labelled name-level
  counts and never multiply observations.
- No observation index or CSV request before submission. Successful index loads
  are cached; missing, corrupt, and failed requests offer retry. Older requests
  cannot replace newer submissions. Data is inserted as text, with accessible
  status messages and a complete CSV link that works without JavaScript.
- Strict source-policy validation, complete packaged-data CSV export, round-trip
  verification, composite-key checks, and one shared summary implementation.
  Generated resources are ignored and excluded from the R package.
- Actual legacy path inventory and unresolved ownership/service dependencies in
  [legacy URL mapping](legacy-url-mapping.md). Read-only PR verification uploads
  a review artifact; production publication is restricted to `main`.

The explorer uses `query` instead of Quarto's reserved `q` parameter. The homepage
uses `freeze: false`, and the pre-render generator runs for incremental renders.
Quarto's automatic freeze invalidation depends on document source changes;
underlying data changes need explicit handling. See
[Quarto execution documentation](https://quarto.org/docs/projects/code-execution.html).

The existing `system.time()` example remains runnable in the Common Analyses
guide but no longer executes during publication: machine-specific timings made
otherwise identical clean renders differ.

## Approved ID repair

The existing source builder parsed six database-ID columns as signed 32-bit
integers. Values above that range had become missing in three packaged
observations. With explicit user approval, these parsers now use numeric values,
and only `data/traitsview.rda` was regenerated.

This restores 12 missing values across three rows, including observation IDs
`5000000006`, `5000000007`, and `5000000008`. Observation count, column order,
non-ID values, and previously nonmissing IDs are unchanged. Raw CSVs and all
other packaged datasets are byte-identical to the comparison baseline. The
generator rejects missing, duplicate, or inexact observation identities.

## Results

| Check | Local result |
| --- | --- |
| Install checkout into an isolated R library | Passed |
| Existing and new R tests | 56 assertions passed; 0 failures, warnings, or skips |
| Search unit tests | 6 passed |
| Locked npm install | Passed; no reported vulnerabilities |
| Complete executed Quarto render | Passed |
| Browser suite on `/` and `/betydata/` | 20 passed in 42.1 seconds on final clean output |
| axe WCAG A/AA checks | No violations in the six public page states tested, at both prefixes |
| Keyboard interaction | Tab sequence, Enter submission, and pagination exercised successfully through browser automation |
| Responsive layout | Desktop, 375-pixel and 720-pixel viewports, and CSS zoom at 200% passed overflow checks |
| Data-only freshness regression | Counts changed from 3 to 2 after fixture-data edit and normal render, without editing homepage source |
| Reproducibility | Two clean renders with fresh R execution produced identical hashes for all 46 site files and 3 generated data files |
| Rendered links/resources and size budgets | Passed |
| Workflow syntax, actionlint 1.7.7 | Passed |
| R package check, `--no-manual` | 0 errors, 0 warnings, 1 pre-existing NOTE |

The package NOTE is `License stub records with missing/empty fields: Record: 1
Field(s): ORGANIZATION`. The unchanged upstream baseline produced the same NOTE
with zero errors and warnings. This is not a clean zero-NOTE package check.

The browser suite covers initial network silence, homepage submission, direct
URLs, history, combined filters, pagination, no-result states, shared counts,
HTML-like data, missing/corrupt/offline request failures and retry, stale responses,
downloads, and JavaScript-disabled download guidance. Desktop and mobile
screenshots were visually inspected. Automated keyboard and axe checks do not
replace human assistive-technology testing.

## Data snapshot and performance

The homepage reports 43,532 observations, 297 measured variable names, 1,337
represented species, 857 sites, and 667 sources. The catalog separately contains
967 definitions. Snapshot examples under the final matching contract:

| Submitted filters | Observations | Definitions |
| --- | ---: | ---: |
| Keyword `photosynthesis` | 12 | 12 |
| Keyword `photosynthesis`, species `Panicum` | 0 | 12 |
| Variable `yield`, species `Panicum` | 2,087 | 15 |
| Species `switchgrass` | 2,703 | 967 |
| Author `Heaton` | 61 | 967 |

These are snapshot measurements, not universal assertions. Species/author-only
filters retain the complete catalog and change its contextual observation counts.

| Measurement | Final local result |
| --- | ---: |
| Published site, 46 files | 29,711,327 bytes |
| Minified observation/catalog index | 7,123,242 bytes |
| Index compressed with Node's default gzip settings | 467,652 bytes |
| Complete public observation CSV, all 35 columns | 13,942,120 bytes |
| First search, root / project prefix | 1,800 / 1,943 ms |
| Cached filtering, root / project prefix | 12.2–19.5 / 10.3–18.3 ms |

Browser measurements used Chromium 156.0.8078.4, a single Playwright worker,
4× CPU throttling, and local uncompressed HTTP without network throttling.
First-search time includes navigation, download, preparation, and displayed
results. Cached measurements time the filtering function over five queries,
excluding DOM rendering. The gzip size is a local compression estimate, not a
claim about GitHub's transfer encoding. Both the 10 MB index and 100 MB site
budgets pass; no index optimization beyond compact row arrays was needed.

GitHub documents a 1 GB published-site limit and a 10-minute deployment timeout.
The measured artifact is below the size limit. No hosted deployment was run,
so the deployment-time requirement remains unverified. See
[GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).

## Commands and toolchain

Recorded versions: R 4.6.1, Quarto 1.10.19, Node.js 24.18.0, Playwright 1.64.1,
axe 4.14.0, readr 2.2.0, jsonlite 2.0.0, testthat 3.3.2, and devtools 2.5.2.
The local temporary package library was `/tmp/betydata-issue15-lib`.
Equivalent reproduction commands from the repository root:

```sh
TEST_LIB="$(mktemp -d)"
R CMD INSTALL --library="$TEST_LIB" .
export R_LIBS="$TEST_LIB${R_LIBS:+:$R_LIBS}"
Rscript -e 'testthat::test_local()'
npm ci
npm test
npx playwright install chromium
quarto render --execute
npm run check:site
Rscript scripts/test-site-freshness.R
python3 scripts/check-reproducibility.py
npx playwright test
Rscript -e 'devtools::check(args = "--no-manual", error_on = "never")'
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 \
  .github/workflows/website-check.yml .github/workflows/quarto-publish.yml
```

Inspect the package-check summary even when its process exits successfully:
`error_on = "never"` preserves diagnostics for baseline comparison. Browser
tests start the local server automatically. For manual inspection, run
`node scripts/serve-site.mjs` and open `http://127.0.0.1:8765/` and
`http://127.0.0.1:8765/betydata/`.

Local, ignored evidence:

- `playwright-report/index.html`: browser results and performance attachments.
- `test-results/search-accessibility-keyboard-mobile-and-zoomed-layouts-root/`:
  `homepage-desktop.png`, `homepage-mobile.png`, and `search-mobile.png`.
- Equivalent screenshots under the `-project-path/` test-results directory.
- Session logs under `/tmp/betydata-issue15-`: `tests.log`, `render.log`,
  `check.log`, `freshness.log`, `repro.log`, `browser-final.log`, and
  `workflow-check.log`. These temporary logs are not repository deliverables.

## Remaining acceptance work

Hosted GitHub Actions, artifact download, production deployment timing, real
mobile hardware, native browser 200% zoom, and human screen-reader operation
have not been verified. The 200% automated check uses CSS zoom. Maintainers
should complete these checks before approving a domain cutover. Legacy query
translation, machine API clients, data-entry continuity, schema hosting, and
service retirement remain assigned to issues #16 and #17.

This implementation credits and supersedes PR #33's homepage summary approach.
Recommend closing #33 only after acceptance; it has not been modified. Issue #15
is not represented as resolved: the implementation and local automated checks
are complete, while hosted/manual acceptance and maintainer review remain.
