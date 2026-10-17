# BETYdb legacy URL and service handoff

This is a migration inventory for [issue #16](https://github.com/PecanProject/betydata/issues/16), not deployed redirects. Reusable documentation migration belongs to [issue #17](https://github.com/PecanProject/betydata/issues/17). Do not change DNS, retire the Rails application, or claim API compatibility from this website contribution.

## Verification and destination rules

Availability was probed with unauthenticated HTTPS GET requests on **2026-10-17**, with a 12-second timeout. A timeout is inconclusive, not proof that a service is unavailable. A successful login-page response does not verify authentication or data entry. Record-level and wildcard routes were not exercised against invented IDs or credentials.

Destinations below are relative to the new site's root. For the GitHub project deployment, prefix them with `/betydata/` (for example `/betydata/search.html`); after an approved custom-domain cutover, use `/search.html`. Destination pages are supplied by this contribution and require a successful build, browser checks, and deployment before redirects can be enabled. None is claimed to be deployed by this document.

The named owners below identify responsible **projects/workstreams**, not an assignment to a particular person. #16 must establish the operational owner and approve each disposition before cutover.

| Existing URL or path | Current availability | Destination / disposition | Owner and unresolved dependencies | Query and fragment handling |
| --- | --- | --- | --- | --- |
| `https://betydb.org/` | HTTP 200 | `index.html` | BETYdb website / #16: confirm deployment and hostname before redirect | Preserve supported fragments only after checking targets; do not forward unknown query parameters blindly |
| `https://betydb.org/search` | GET timed out | `search.html` | Rails search / #16: inventory current query parameters and prove translations; new search is a snapshot | New interface uses `query`,  `variable`, `species`, `author`; translate legacy parameters only after fixture tests |
| `https://betydb.org/traits` | GET timed out | `search.html` | Rails data browsing / #16: new observation results combine traits and yields; decide whether a source-type filter is necessary before redirect | Inventory legacy filters, paging, and formats; no automatic compatibility claimed |
| `https://betydb.org/yields` | GET timed out | `search.html` | Rails data browsing / #16: preserve source-table meaning | Inventory legacy filters, paging, and formats |
| `https://betydb.org/variables` | GET timed out | `search.html` | Catalog documentation / #16 and #17: catalog IDs remain distinct; observation counts are by variable name | Preserve definition IDs through a documented mapping; new search does not expose legacy catalog record routes |
| `https://betydb.org/species` | GET timed out | `search.html` | Taxonomy browsing / #16: explorer searches represented observations; it is not a complete taxonomy replacement | Inventory scientific/common-name parameters and record links |
| `https://betydb.org/traits/:id`, `/yields/:id`, and other record URLs | Templates not probed | Retain until identity-preserving destinations or explicit retirement notices exist | Rails record services / #16: preserve `(result_type, id)`; verify citations and external links | Record IDs, formats, and fragments must not be discarded; numeric IDs are not globally unique |
| `https://betydb.org/login` | HTTP 200; authentication not tested | Retain operational service | Rails authentication / #16: account-based entry continuity; `contribute.html` offers guidance only | Preserve intended post-login destination securely; no credential or session migration in this change |
| `https://betydb.org/signup` | HTTP 200; registration not tested | Retain until account lifecycle decision | Rails authentication / #16: registration, existing accounts, and support owner | Review existing return-path parameters before any routing changes |
| `https://betydb.org/bulk_upload/*` | `/bulk_upload` timed out; upload routes not exercised | Retain operational service | Data entry / #16: uploads, validation, review queues, and permissions need replacements before shutdown | Preserve workflows and job/status identifiers; never redirect upload POSTs to static HTML |
| `https://betydb.org/api` | GET timed out | `vignettes/getting_started.html` for the human documentation entry point only | Data access / #16: determine which clients request this exact path | Confirm HTML-only usage before redirect; format requests must be reviewed separately |
| `https://betydb.org/api/v1/*` | Base `/api/v1` timed out; wildcard routes not exercised | Retain machine service until clients migrate | API maintainers / #16: inventory `ropensci/traits`, PEcAn, scripts, keys, formats, and compatibility requirements | Do not redirect JSON/CSV API requests to HTML; preserve query semantics, status codes, and content types until migration |
| `https://betydb.org/api/beta/*` | Base `/api/beta` timed out; wildcard routes not exercised | Retain machine service until clients migrate | API maintainers / #16: version support and downstream usage are unresolved | Same machine-client constraints as `/api/v1/*` |
| `https://pecanproject.github.io/bety-documentation/dataentry/` | HTTP 200 after redirect to `https://pecanproject.org/bety-documentation/dataentry/` | `contribute.html` links to retained detailed guide | Documentation / #17: migrate reusable procedures before replacing detailed legacy pages | Inventory chapter URLs and fragments; retain existing deep links until explicit mappings exist |
| `https://pecan.gitbook.io/betydb-data-access/` | HTTP 403 from this environment | `access.html` | Data-access documentation / #17: inspect content through an authorized browser; reconcile download and API guidance | Inventory child paths and fragments before retiring GitBook pages |
| `https://pecanproject.github.io/bety-documentation/technical/` | HTTP 200 after redirect to `https://pecanproject.org/bety-documentation/technical/` | Retain current destination pending #17 | Technical documentation / #17: distinguish reusable data documentation from Rails operations | Preserve chapter/section links; verify any replacement fragment mapping |
| `https://betydb.org/schemas` | GET timed out | Block retirement until a working schema destination exists | Schema documentation / #17, service owner / #16: versioned schema, relationship diagrams, and deep links | Inventory schema/table/column fragments before choosing a destination |

## Cutover gate

Before each redirect, repeat availability checks, test the actual destination at the intended deployment prefix, inventory queries/fragments and downstream clients, and record a named operational owner. Verify desktop/mobile navigation, accessibility, download equivalence, and representative search behavior. The static CSV is a public snapshot; it does not reproduce authenticated data entry or a live database/query API.

Recommend closing [PR #33](https://github.com/PecanProject/betydata/pull/33) as superseded **after this consolidated homepage implementation is accepted**. This contribution does not close or modify that PR automatically.
