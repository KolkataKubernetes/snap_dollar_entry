# Build retail-access descriptives aligned to the county event-study convention

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

## ExecPlan Status

Status: Complete  
Owner: Inder Majumdar + Codex  
Created: 2026-05-27  
Last Updated: 2026-05-27  
Related Project: `snap_dollar_entry` retail-access descriptives for SNAP retailer proximity and county waiver timing

Optional Metadata:  
Priority: High  
Estimated Effort: 1-2 implementation passes plus one review pass on outputs  
Dependencies: `agent-docs/agent_context/2026_05_27_access.md`, `2_9_analysis/2_9_0_us_analysis_panel.rds`, `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`, `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds`

## Revision History

| Date | Change | Author |
| --- | --- | --- |
| 2026-05-27 | Initial planning draft created after auditing the access-analysis context, the tract ingest pipeline, the county descriptive helpers, and the currently available tract ACS weights | Codex |
| 2026-05-27 | Executed the study-period access-weight pull, tract nearest-distance build, county summary build, and descriptive rendering scripts; then validated the new processed artifacts and output file counts | Codex |
| 2026-05-27 | Added Output `3_1_2_4` and Output `3_1_2_5` as retailer-format-over-time comparisons for the SNAP-recipient-household and below-`1.25x`-FPL weighting regimes | Codex |

## Quick Summary

### Goal

Build a tract-to-retailer access pipeline and a first set of descriptive outputs that show how nearest-retailer distance varies across county treatment status, rural versus urban counties, and three tract weighting regimes. The purpose is descriptive only: produce transparent access summaries that line up with the existing county event-study convention before any causal analysis is attempted.

### Deliverable

The deliverable is a new processed retail-access dataset plus three descriptive output families under `3_outputs/3_1_descriptives/3_1_2_retail_access`. When the plan is complete, a contributor will be able to rerun scripted distance construction, county aggregation, and figure/table generation without manual data work.

### Success Criteria

- A new tract access-weight artifact exists for `2014:2019` and contains the exact requested weighting variables `B01003_001E`, `C17002_002E`, `C17002_003E`, `C17002_004E`, and `B22010_002E`.
- A new tract-year-format access artifact exists with one row per retained tract, year, and benchmark retailer format, and with a non-missing nearest-distance measure whenever that format has at least one in-scope retailer in that year.
- Output 1 writes a table-ready CSV and a rendered JPEG using `2014` and `2019` snapshots, split by urban versus rural counties and by the three agreed weighting regimes.
- Output 2 writes yearly trend CSVs and one line-chart JPEG per benchmark retailer format, with three weight-series lines and urban/rural facets.
- Output 3 writes weighted ECDF source CSVs and weighted ECDF JPEGs using the agreed `2 x 2` facet grid: rows are urban/rural, columns are `2014`/`2019`, and line color distinguishes ever-treated versus never-treated counties.

### Key Files

- `1_code/1_0_ingest/1_0_3_retail_access_data/`
- `1_code/1_1_descriptives/1_1_2_retail_household_access/`
- `3_outputs/3_1_descriptives/3_1_2_retail_access/`
- `agent-docs/execplans/2026-05-27-retail-access-descriptives-execplan.md`

## Purpose / Big Picture

After this change, the repository will be able to answer a simple descriptive question that it cannot answer today: how far the average tract resident, low-income resident, or SNAP-recipient household is from the nearest retailer of a given format, and how that distance distribution differs between counties that ever receive a county-level waiver and counties that never do.

The work is intentionally descriptive and transparent. It does not estimate treatment effects, redefine treatment, or change the benchmark retailer-format groups already used elsewhere in the repository. It adds only the study-period-specific data needed to compute the requested access measures exactly as specified, then turns those measures into auditable tables and figures.

The phrase “nearest-retailer distance” in this plan means the straight-line distance from a retained 2010 Census tract centroid to the nearest active SNAP retailer in the relevant benchmark retailer format and year. The phrase “weighting regime” means the tract-level quantity used when averaging tract distances up to the county level or when weighting tract observations in distribution plots. The three weighting regimes in this plan are exactly the user-specified ACS measures, not approximations.

## Progress

- [x] (2026-05-27 21:04Z) Audited `agent-docs/agent_context/2026_05_27_access.md` and extracted the requested metrics, outputs, and open ambiguities.
- [x] (2026-05-27 21:04Z) Audited `agent-docs/PLANS.md`, `agent-docs/ExecPlan_TEMPLATE.md`, and one completed ExecPlan to match the required structure and level of detail.
- [x] (2026-05-27 21:04Z) Audited the tract retailer ingest, tract ACS ingest, tract panel builder, county descriptive helpers, and current output directories.
- [x] (2026-05-27 21:04Z) Confirmed user review decisions: snapshot years are `2014` and `2019`; ever-treated counties use the existing county descriptive rule; exact requested weights are required; Output 3 will use weighted ECDFs with a `2 x 2` urban/rural by year facet grid.
- [x] (2026-05-27 21:04Z) Revised the planning scope so the exact ACS weights are pulled only for the `2014:2019` study period inside the new retail-access branch, rather than being backfilled into the broader tract ACS pipeline.
- [x] (2026-05-27 21:04Z) Draft this ExecPlan was reviewed live by the user and revised to narrow the weight pull to the `2014:2019` study period only.
- [x] (2026-05-27 21:54Z) Implemented the new retail-access weight, distance, aggregate, and descriptive scripts under `1_code/1_0_ingest/1_0_3_retail_access_data` and `1_code/1_1_descriptives/1_1_2_retail_household_access`.
- [x] (2026-05-27 21:54Z) Ran the new study-period ACS weight pull and wrote `2_10_0_tract_access_weights_2014_2019.rds`.
- [x] (2026-05-27 21:54Z) Ran the tract nearest-distance build and wrote `2_10_1_tract_retail_access_nearest_distance.rds`.
- [x] (2026-05-27 21:54Z) Ran the county summary and ECDF-source build and wrote `2_10_2_county_retail_access_weighted_summary.rds` and `2_10_3_retail_access_ecdf_source.rds`.
- [x] (2026-05-27 21:54Z) Rendered Output 1, Output 2, and Output 3 into `3_outputs/3_1_descriptives/3_1_2_retail_access`.
- [x] (2026-05-27 21:54Z) Validated the processed artifacts and confirmed the expected final output counts: `17` CSV files and `17` JPEG files in the planned output folder.

## Surprises & Discoveries

- Observation: The two target script folders named in the agent context already exist but are empty, so this work is net-new within those directories rather than a patch to existing retail-access scripts.  
  Evidence: `find 1_code/1_0_ingest/1_0_3_retail_access_data -maxdepth 2 -type f` and `find 1_code/1_1_descriptives/1_1_2_retail_household_access -maxdepth 2 -type f` both returned no files during planning.

- Observation: The current tract panel does not contain the requested weight columns for total population, population below `1.25x` poverty, or SNAP-recipient households.  
  Evidence: `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` currently lacks `B01003_001E`, `C17002_*`, and `B22010_002E`.

- Observation: The current tract ACS script labels `B11001_001E` as `population`, even though the requested total-population weight is `B01003_001E`.  
  Evidence: `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R` currently writes `B11001_001E` and maps it to `population`.

- Observation: Pulling or backfilling pre-`2014` ACS weights would add runtime without helping the user’s stated study period for this task.  
  Evidence: The user explicitly narrowed the analytical window for this task to `2014:2019` during plan review.

- Observation: The benchmark retailer-format grouping used in the main county and tract analysis panels is broader than the grouping implied by the generic descriptive helper’s raw `store_count` summary.  
  Evidence: `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` and `1_0_2_1_build_analysis_panel_tract_pre_covariates.R` explicitly collapse named supermarket, convenience, and multi-category chains into grouped benchmark outcomes before analysis.

- Observation: The first descriptive render pass wrote correct artifacts into `3_outputs/3_1_descriptives/3_1_2_retail_household_access` because the shared descriptive helper mapped the literal script directory into the output path.  
  Evidence: The initial render produced `34` files in `3_outputs/3_1_descriptives/3_1_2_retail_household_access`, after which the access-specific helper was patched to force the agreed `3_1_2_retail_access` output directory and the scripts were rerun successfully.

- Observation: The exact study-period weight pull succeeded with complete total-population and SNAP-household coverage, but there are nine retained tract-year rows with missing poverty-component estimates.  
  Evidence: `2_10_0_tract_access_weights_2014_2019.rds` has `435,084` rows with `0` missing `B01003_001E`, `0` missing `B22010_002E`, and `9` missing rows each for `C17002_002E`, `C17002_003E`, and `C17002_004E`.

- Observation: The tract retailer-clean file already preserves validated point coordinates and tract assignments, so new distance work can build from existing cleaned inputs rather than returning to raw CSV ingest.  
  Evidence: `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds` includes `Latitude`, `Longitude`, `chain`, `tract_fips`, `county_fips`, `authorization_year`, and `end_year`.

- Observation: The repository already has the output directory requested in spirit, `3_outputs/3_1_descriptives/3_1_2_retail_access`, but it is empty.  
  Evidence: `ls -1 3_outputs/3_1_descriptives/3_1_2_retail_access` returned no files during planning.

## Decision Log

- Decision: Use `2014` and `2019` as the snapshot years for Outputs 1 and 3.  
  Rationale: The user explicitly chose these years so the descriptives align with the existing county event-study convention rather than the literal first and last years of the full panel.  
  Date/Author: 2026-05-27 / User + Codex

- Decision: Define ever-treated counties using the existing county descriptive rule already used in the repository.  
  Rationale: This preserves consistency with existing descriptive work and avoids silently introducing a new treatment universe. Operationally, the implementation should reuse the county descriptive helper logic rather than restating treatment from scratch.  
  Date/Author: 2026-05-27 / User + Codex

- Decision: Use the exact requested ACS weighting variables, but pull them only for the `2014:2019` study period inside a new retail-access-specific weight artifact.  
  Rationale: The user explicitly chose exact ACS weights, but also explicitly rejected spending time on pre-study-period pulls and backfills for this task. A task-local weight artifact preserves the exact definitions without changing the broader tract ACS contract.  
  Date/Author: 2026-05-27 / User + Codex

- Decision: Use weighted ECDFs, not kernel densities, for Output 3.  
  Rationale: ECDFs make the distribution comparison easier to audit visually, do not depend on a bandwidth choice, and align with the user’s approval of the recommended Output 3 rendering contract.  
  Date/Author: 2026-05-27 / User + Codex

- Decision: Keep the benchmark retailer-format groups already defined in `1_code/1_1_descriptives/shared_us_analysis_helpers.R`: `Dollar stores`, `Convenience stores`, `Supermarkets`, and `Multi-category`.  
  Rationale: The agent context explicitly asked to preserve the existing retailer-format groupings rather than inventing new categories.  
  Date/Author: 2026-05-27 / Codex

- Decision: Treat Output 1 as two artifacts, not one: a tidy CSV that is the canonical data output and a table-like JPEG rendered from that CSV using `ggplot2`.  
  Rationale: This preserves a machine-readable table while avoiding a new rendering dependency just to obtain the requested visual facet layout.  
  Date/Author: 2026-05-27 / Codex

- Decision: Add the exact ACS component columns to the tract ACS artifact and tract panel, and compute the poverty-line weight as `C17002_002E + C17002_003E + C17002_004E` at the retail-access aggregation stage.  
  Rationale: This preserves the original ACS ingredients in processed data, keeps the weighting rule transparent, and avoids hard-coding an irreversible derived field too early in the pipeline.  
  Date/Author: 2026-05-27 / Codex

- Decision: Store new intermediate access artifacts under a new processed-data folder `2_10_retail_access`.  
  Rationale: The county and tract analysis panels already occupy `2_9_analysis`; the access pipeline is related but distinct. A separate folder keeps the processed outputs explicit and easier to audit.  
  Date/Author: 2026-05-27 / Codex

- Decision: Do not modify the shared tract ACS backfill regime or the shared tract panel schema for this task.  
  Rationale: The user’s stated scope is the `2014:2019` study period only. A task-specific access-weight artifact is narrower, faster, and less likely to create unintended regressions in the broader tract-analysis branch.  
  Date/Author: 2026-05-27 / User + Codex

- Decision: Mirror the benchmark retailer-format grouping logic from the analysis-panel builders, not the narrower raw `store_count` grouping implicit in the generic descriptive helper.  
  Rationale: The user asked to preserve the existing benchmark format groups used in analysis. The panel-builder regrouping is the operative benchmark definition in this repository.  
  Date/Author: 2026-05-27 / Codex

- Decision: Override the descriptive output path for this branch so files write into `3_outputs/3_1_descriptives/3_1_2_retail_access` exactly, even though the script directory is named `1_1_2_retail_household_access`.  
  Rationale: The output folder named in the specification and user context is `3_1_2_retail_access`. Preserving that destination is more important than blindly following the generic folder-mapping helper.  
  Date/Author: 2026-05-27 / Codex

## Outcomes & Retrospective

**Summary of Outcome**

The implementation succeeded. The repository now has a study-period-only tract access-weight artifact, a tract nearest-distance artifact, a county weighted-summary artifact, and a tract-level ECDF source artifact, all under `2_10_retail_access`. It also now has the full requested descriptive output family under `3_outputs/3_1_descriptives/3_1_2_retail_access`.

**Expected vs. Actual Result**

- Expected outcome: a self-contained ExecPlan that resolves the main design ambiguities before code execution starts.
- Actual outcome: exceeded the planning-only milestone. The plan was executed end to end in the same branch, and the processed artifacts plus the requested descriptive outputs were produced successfully.
- Difference (if any): the first descriptive render pass used the wrong output directory because of the generic helper mapping, but the helper was patched and the renderers were rerun into the correct folder.

**Key Challenges Encountered**

- Challenge: the requested weights did not exist in the tract analysis inputs for this task.  
  Resolution: created a study-period-only weight artifact in Milestone 1 instead of extending the shared ACS backfill branch.

- Challenge: the first distance-build run failed before any geometry work because the year-format iterator used an invalid inline placeholder.  
  Resolution: patched the iterator to materialize the year-format grid first, then reran the distance build successfully.

- Challenge: the first snapshot-table render failed because repeated visible subrow labels are not valid as factor levels for a pseudo-table y-axis.  
  Resolution: switched the renderer to a hidden row key plus a display-label mapping, then reran the snapshot renderer successfully.

**Lessons Learned**

- Lesson: the access-analysis specification depends heavily on upstream weight definitions, so the ExecPlan needs to treat those data contracts as first-class scope, not just plotting details.

- Lesson: when a script directory name differs from the agreed output folder name, the generic descriptive output helper should not be trusted blindly; the branch-specific output path should be asserted explicitly.

**Follow-up Work**

- Follow-up task: if the user wants a clean output tree, remove the `34` duplicate first-pass artifacts in `3_outputs/3_1_descriptives/3_1_2_retail_household_access`.

## Context and Orientation

The current repository already has a county analysis panel, a tract analysis panel, and a tract-assigned SNAP retailer file, but it does not yet have a tract-to-retailer distance artifact. The relevant upstream tract panel is `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`, built by `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R`. That tract panel already carries tract-year retailer counts, county treatment timing, and several ACS covariates, but not the exact weights requested in the agent context.

The cleaned retailer point file is `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds`, built by `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R`. It already includes tract assignments, retailer chain labels, and authorization windows. This makes it the correct input for access construction because it is the earliest processed file that still preserves retailer coordinates and tract assignments together.

The existing descriptive helper pattern lives in `1_code/1_1_descriptives/shared_us_analysis_helpers.R` and its stage-specific copies. Those helpers already define the benchmark retailer-format groups, the standard descriptive output path logic, and the county ever-treated convention used elsewhere in the repository. This plan reuses that design rather than replacing it.

This plan intentionally does not widen the shared tract ACS branch. Instead, it creates a task-local retail-access weight artifact for `2014:2019` only. That choice keeps the study-period scope aligned to the user’s request and avoids reprocessing historical years that will not appear in any output for this task.

The term “retained tract” in this plan means a tract inside the tract-analysis scope already defined by `load_scope_tracts()` in `1_code/1_0_ingest/tract_ingest_helpers.R`, after the explicit ACS exclusion rows are removed by the tract panel builder. The term “active retailer in year `t`” means a SNAP retailer whose `authorization_year <= t <= end_year` in the cleaned retailer panel.

The term “urban county” in this plan means a county with RUCC code `1`, `2`, or `3`, and “rural county” means RUCC code `4` through `9`. For consistency with existing descriptive scripts, the RUCC lookup should come from `0_7_Ruralurbancontinuumcodes2023.xlsx` unless execution reveals that another file is already hard-wired into the relevant shared helper and the user asks to change that convention.

## Data Artifact Flow

Raw Inputs

- `0_inputs/input_root.txt`
- `2_processed_data/processed_root.txt`
- `0_5_SNAP/0_5_2_Historical SNAP Retailer Locator Data-20231231.csv` only through already-processed downstream artifacts
- local tract shapefiles under `0_8_geographies/census_tracts/`
- `0_7_Ruralurbancontinuumcodes2023.xlsx`

Intermediate Artifacts

- `2_10_retail_access/2_10_0_tract_access_weights_2014_2019.rds` with exact tract weights for `2014:2019`
- `2_10_retail_access/2_10_1_tract_retail_access_nearest_distance.rds` with one row per tract-year-format
- `2_10_retail_access/2_10_2_county_retail_access_weighted_summary.rds` with county-year-format weighted summaries and treatment/rural flags
- `2_10_retail_access/2_10_3_retail_access_ecdf_source.rds` with tract-level ECDF plotting inputs after treatment/rural/year filtering and weight assignment

Final Outputs

- `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_1_weighted_distance_snapshot_table.csv`
- `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_1_weighted_distance_snapshot_table.jpeg`
- `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_2_weighted_distance_trend_<format_slug>.csv`
- `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_2_weighted_distance_trend_<format_slug>.jpeg`
- `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_3_weighted_ecdf_<format_slug>_<weight_slug>.csv`
- `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_3_weighted_ecdf_<format_slug>_<weight_slug>.jpeg`

## Milestones

### Milestone 1: build a study-period access-weight artifact

This milestone adds the exact weight variables needed for the access analysis, but only for `2014:2019`. At the end of this milestone, the repository will be able to read a task-local tract weight file and find the precise ACS columns required to build total-population, below-`1.25x`-poverty, and SNAP-household weights for the study period actually used in the outputs.

The visible proof is a new `2_10_retail_access/2_10_0_tract_access_weights_2014_2019.rds` containing `B01003_001E`, `C17002_002E`, `C17002_003E`, `C17002_004E`, and `B22010_002E` for years `2014:2019` only. Before the change, a column-check command should fail because that file does not exist. After the change, it should pass.

### Milestone 2: construct tract nearest-distance and county weighted-summary artifacts

This milestone creates the new access data layer. The implementation should derive tract centroids from the existing tract scope, classify active retailers into the four benchmark format groups, and compute the nearest straight-line distance from each tract centroid to the nearest active retailer in each format-year combination.

The visible proof is a new tract-year-format nearest-distance artifact and a new county-year-format weighted-summary artifact under `2_10_retail_access`. The tract artifact should be auditable at the row level, should only cover `2014:2019`, and the county summary artifact should already contain the three weight regimes, treatment status, RUCC split, and snapshot-year flags that the descriptive scripts need.

### Milestone 3: render Outputs 1 through 3 from the new access artifacts

This milestone converts the access data into the requested descriptive outputs. At the end of the milestone, the repository will produce a snapshot table, trend figures, and weighted ECDF figure sets in the new retail-access descriptive folder.

The visible proof is the creation of the agreed CSV and JPEG files under `3_outputs/3_1_descriptives/3_1_2_retail_access`, plus quick validation extracts that show the underlying rows match the requested years, treatment groups, RUCC split, and weight definitions.

## Plan of Work

First, create `1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_0_build_retail_access_weight_inputs.R`. This script should follow the same repo-relative pathing pattern as the existing ingest scripts, load the retained tract scope, and pull the exact requested ACS variables only for `2014:2019`. It should save a new task-local artifact at `2_10_retail_access/2_10_0_tract_access_weights_2014_2019.rds`. The change should not modify `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R` or `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`.

Second, create a new ingest-stage helper file at `1_code/1_0_ingest/1_0_3_retail_access_data/shared_retail_access_helpers.R`. This helper should follow the repository’s existing pathing pattern and provide four reusable functions: one to load the repo root and processed roots; one to load retained tract geometry and create tract centroids; one to classify cleaned retailer chains into the four benchmark format groups already used elsewhere in the repository; and one to attach county treatment and RUCC metadata consistently using existing county descriptive conventions.

Third, create `1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_1_build_retail_access_distance_panel.R`. This script should read the task-local tract weight artifact, the existing tract panel for identifiers and county linkages, the tract geometry scope, and the cleaned retailer point file; filter retailers to in-scope observations with coordinates; expand active retailers by year across `2014:2019`; collapse chains into the benchmark format groups; and compute the nearest retailer distance from each retained tract centroid to the nearest active retailer in each year-format combination. Distances should be computed as straight-line distances in miles using `sf` geometry only, with an explicit projected CRS chosen once and documented in the script. The output should be a tract-year-format file that carries tract identifiers, county identifiers, year, format, nearest distance, and the exact tract ACS weight columns needed downstream.

Fourth, create `1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_2_build_retail_access_county_aggregates.R`. This script should read the tract nearest-distance artifact, compute three tract weight fields, and aggregate those distances to the county-year-format level using weighted averages. The weight fields should be `B01003_001E`, `C17002_002E + C17002_003E + C17002_004E`, and `B22010_002E`. This same script should also prepare a tract-level ECDF source artifact by attaching county ever-treated status, RUCC urban/rural status, and the `2014` and `2019` snapshot flags to each tract-year-format row.

Sixth, create a descriptive-stage helper file at `1_code/1_1_descriptives/1_1_2_retail_household_access/shared_retail_access_descriptive_helpers.R`. It should mirror the repository’s descriptive helper style: use repo-relative pathing, create the correct output directory automatically, reuse the benchmark format colors, and expose helper functions to slugify format/weight names and to load the access summary artifacts.

Seventh, create `1_code/1_1_descriptives/1_1_2_retail_household_access/1_1_2_1_weighted_distance_snapshot_table.R`. This script should read the county weighted-summary artifact, filter to `2014` and `2019`, split urban/rural into separate facets with urban on top, and render a table-like figure where each retailer format forms a header block and the three rows within that block correspond to the agreed weight regimes. The same script should also write the tidy source CSV that powers the rendered table.

Eighth, create `1_code/1_1_descriptives/1_1_2_retail_household_access/1_1_2_2_weighted_distance_trends.R`. This script should read the county weighted-summary artifact and emit one trend CSV and one JPEG per benchmark retailer format. Each figure should have year on the x-axis, weighted nearest distance on the y-axis, separate lines for the three weighting regimes, and urban/rural facets to preserve comparability with Output 1.

Ninth, create `1_code/1_1_descriptives/1_1_2_retail_household_access/1_1_2_3_access_ecdf_ever_vs_never.R`. This script should read the tract ECDF source artifact and produce one CSV plus one JPEG for each `format x weight` combination. Each figure should use the agreed `2 x 2` facet grid, with rows for urban/rural counties and columns for `2014` and `2019`. The lines in each facet should compare ever-treated versus never-treated counties using tract weights, not unweighted tract counts.

The implementation must not change the underlying county treatment definition, the benchmark retailer-format grouping logic, or the existing reduced-form samples. This plan creates a new descriptive branch that reads the existing county and tract analysis outputs rather than redefining them.

## Concrete Steps

All commands below should be run from `/Users/indermajumdar/Research/snap_dollar_entry`.

Implementation order:

1. Build the study-period access-weight input.
2. Add the two access-data construction scripts and run them.
3. Add the three descriptive scripts and run them.
4. Validate the new processed artifacts and output files.

Expected execution commands:

    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_0_build_retail_access_weight_inputs.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_1_build_retail_access_distance_panel.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_2_build_retail_access_county_aggregates.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_2_retail_household_access/1_1_2_1_weighted_distance_snapshot_table.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_2_retail_household_access/1_1_2_2_weighted_distance_trends.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_2_retail_household_access/1_1_2_3_access_ecdf_ever_vs_never.R

Expected validation commands after implementation:

    /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]); processed_root <- sub("^[\"\\047]", "", sub("[\"\\047]$", "", processed_root)); weights <- readRDS(file.path(processed_root, "2_10_retail_access", "2_10_0_tract_access_weights_2014_2019.rds")); req <- c("B01003_001E", "C17002_002E", "C17002_003E", "C17002_004E", "B22010_002E"); missing <- setdiff(req, names(weights)); if (length(missing)) stop(paste("missing columns:", paste(missing, collapse = ", "))); years <- sort(unique(weights$year)); if (!identical(years, 2014:2019)) stop("weight artifact years do not equal 2014:2019"); cat("all requested access weights present for 2014:2019\n")'

    /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]); processed_root <- sub("^[\"\\047]", "", sub("[\"\\047]$", "", processed_root)); access <- readRDS(file.path(processed_root, "2_10_retail_access", "2_10_1_tract_retail_access_nearest_distance.rds")); cat("rows:", nrow(access), "\n"); cat("formats:", paste(sort(unique(access$format)), collapse = ", "), "\n"); cat("years:", paste(range(access$year, na.rm = TRUE), collapse = " to "), "\n"); cat("negative distances:", sum(access$nearest_distance_miles < 0, na.rm = TRUE), "\n")'

    /usr/local/bin/Rscript -e 'out_dir <- file.path("3_outputs", "3_1_descriptives", "3_1_2_retail_access"); print(sort(list.files(out_dir)))'

Before the access-weight script exists, the first validation command should fail because the required file is absent. After implementation, it should print `all requested access weights present for 2014:2019`.

## Validation and Acceptance

Validation must cover the upstream data contract, the new access artifact, and the final descriptive outputs.

First, validate the study-period weight contract. Run the exact one-line R command in `Concrete Steps` that asserts the presence of `B01003_001E`, `C17002_002E`, `C17002_003E`, `C17002_004E`, and `B22010_002E` in `2_10_0_tract_access_weights_2014_2019.rds`, and also asserts that the year set is exactly `2014:2019`. This check passed after implementation and printed `all requested access weights present for 2014:2019`.

Second, validate the tract nearest-distance artifact. Confirm that the new file exists at `2_10_retail_access/2_10_1_tract_retail_access_nearest_distance.rds`, that it contains the four benchmark formats only, that its year range spans `2014:2019`, and that there are no negative distances. This check passed after implementation with `1,740,336` rows, `72,514` retained tracts, years `2014` through `2019`, and `0` negative distances.

Third, validate the county summary and ECDF source contracts. Confirm that the county summary file contains exactly three weight labels, the rural/urban split, the ever-treated/never-treated labels, and the snapshot-year flags for `2014` and `2019`. Confirm that the ECDF source file can be filtered to all `format x weight x rural_status x year x treatment_group` cells without empty level labels. This check passed after implementation: the county summary has `223,704` rows, `3,107` counties, and years `2014:2019`; the ECDF source CSV spot-check showed the expected year, rural, and treatment labels.

Fourth, validate the rendered outputs. Confirm that Output 1 writes both the snapshot CSV and JPEG, that Output 2 writes four format-specific CSV/JPEG pairs, and that Output 3 writes twelve `format x weight` CSV/JPEG pairs. This check passed after implementation: the planned output folder contains `17` CSV files and `17` JPEG files, which matches `1 + 4 + 12` artifacts in each format.

Acceptance is met only when all four validation layers pass and the user reviews the resulting outputs without requesting a spec correction. The four validation layers passed at execution time.

## Idempotence and Recovery

This plan is designed to be rerunnable. The refreshed ACS and tract-panel scripts overwrite their existing processed `.rds` outputs with the same filenames, and the new access scripts should do the same in `2_10_retail_access`. The descriptive scripts should overwrite their own CSV and JPEG outputs in `3_outputs/3_1_descriptives/3_1_2_retail_access`.

If Milestone 1 fails, the safe recovery path is to fix the tract ACS script first and rerun the tract ACS and tract panel scripts before touching the access pipeline. If Milestone 2 fails, inspect the tract nearest-distance artifact before the county summary artifact; the county summary depends entirely on the tract-level access file. If Milestone 3 fails, inspect the source CSVs before debugging figure rendering, because the CSVs are the canonical descriptive artifacts.

No destructive cleanup is required. If a code rollback becomes necessary, revert only the files touched by this plan and rerun the same scripts to restore the prior upstream artifacts.

## Artifacts and Notes

Key planning evidence that shaped this plan:

    `2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` currently contains
    tract-year ACS fields such as `B20002_001E`, `B11001_001E`, `B25064_001E`,
    and `population`, but does not contain `B01003_001E`, `C17002_*`, or
    `B22010_002E`.

    `2_5_2_snap_clean_with_tracts.rds` already contains:
      `Latitude`
      `Longitude`
      `chain`
      `tract_fips`
      `county_fips`
      `authorization_year`
      `end_year`

    `1_code/1_1_descriptives/shared_us_analysis_helpers.R` already defines the
    benchmark format groups:
      `Dollar stores`
      `Convenience stores`
      `Supermarkets`
      `Multi-category`

The implementation should preserve those contracts and extend them additively.

## Data Contracts, Inputs, and Dependencies

The implementation should rely only on packages that are already common in this repository unless execution proves a missing capability. The required libraries are expected to be `dplyr`, `tidyr`, `readr`, `readxl`, `ggplot2`, `sf`, `stringr`, `tibble`, and the repository’s own helper scripts. No new language should be introduced. The only network-dependent step permitted by this plan is the new study-period ACS pull for exact access weights, and it should mirror the repository’s existing Census API workflow rather than introducing a new external dependency.

`1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_0_build_retail_access_weight_inputs.R` consumes the tract scope, the Census API key, and the ACS variable definitions for the exact requested weight fields. Its output contract is `2_10_0_tract_access_weights_2014_2019.rds`, which must contain one row per retained tract-year for years `2014:2019` only and the numeric estimate columns `B01003_001E`, `C17002_002E`, `C17002_003E`, `C17002_004E`, and `B22010_002E`.

`1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_1_build_retail_access_distance_panel.R` should consume `2_10_0_tract_access_weights_2014_2019.rds`, the existing tract panel for identifiers, `2_5_2_snap_clean_with_tracts.rds`, and tract geometry loaded through `tract_ingest_helpers.R`. Its output contract is a tract-year-format file with identifiers `{tract_fips, county_fips, year, format}`, a nonnegative `nearest_distance_miles`, and the tract ACS weight columns needed downstream. The invariant is one row per retained tract, year, and benchmark format for years `2014:2019` only.

`1_code/1_0_ingest/1_0_3_retail_access_data/1_0_3_2_build_retail_access_county_aggregates.R` should consume the tract nearest-distance artifact plus the county treatment and RUCC metadata. Its output contract is two files: a county-year-format weighted-summary artifact and a tract-level ECDF source artifact. The county summary invariant is one row per `{county_fips, year, format, weight_type}`. The ECDF source invariant is that every row still represents a tract-year-format observation with exactly one attached plotting weight and exactly one treatment/rural/year grouping combination.

`1_code/1_1_descriptives/1_1_2_retail_household_access/1_1_2_1_weighted_distance_snapshot_table.R`, `1_1_2_2_weighted_distance_trends.R`, and `1_1_2_3_access_ecdf_ever_vs_never.R` consume only the processed access artifacts and write descriptive CSV and JPEG outputs under `3_outputs/3_1_descriptives/3_1_2_retail_access`. Their invariants are that no script modifies processed upstream data and that each rendered figure has a matching source CSV.

If the implementation needs to choose a spatial CRS for distance computation, that choice must be documented in the distance-panel script together with the unit conversion used to report miles. The behavioral implication of the choice should be explicit: all nearest distances must be comparable across tracts and years within the retained continental scope.

## Completion Checklist

- [x] `1_0_3_0_build_retail_access_weight_inputs.R` writes the exact requested ACS weight columns into `2_10_0_tract_access_weights_2014_2019.rds` for years `2014:2019` only.
- [x] The new `2_10_retail_access` processed folder exists and contains the tract access-weight, tract nearest-distance, county weighted-summary, and ECDF source artifacts.
- [x] Output 1 writes both the agreed CSV and JPEG snapshot table artifacts.
- [x] Output 2 writes all four format-specific trend CSV/JPEG pairs.
- [x] Output 3 writes all twelve `format x weight` ECDF CSV/JPEG pairs.
- [x] The fail-before/pass-after validation for the new study-period access-weight artifact has passed.
- [x] The `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` sections reflect the final implementation state.
- [x] The ExecPlan status has been updated from `Planning` to the correct execution state.

## Change Notes

2026-05-27: Initial draft created after live clarification of the four key design decisions. The main planning change relative to the raw context note is that the previously vague distributional output is now fully specified as weighted ECDFs over a `2 x 2` rural/urban by year facet grid, and the exact ACS weights are now scoped to a new `2014:2019` access-specific artifact rather than a broader pre-period backfill.

2026-05-27: Updated after execution to record the implemented scripts, validation results, row counts, output counts, benchmark-grouping discovery, and the output-directory override required to place the final artifacts in `3_1_2_retail_access`.
