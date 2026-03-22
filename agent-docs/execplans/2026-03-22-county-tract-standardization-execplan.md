# Standardize county and tract reduced-form inputs after the 2026-03-19 tract expansion

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

## ExecPlan Status

Status: Complete  
Owner: Inder Majumdar + Codex  
Created: 2026-03-22  
Last Updated: 2026-03-22  
Related Project: `snap_dollar_entry` county/tract standardization for reduced form and descriptives

## Revision History

| Date | Change | Author |
| --- | --- | --- |
| 2026-03-22 | Initial planning draft created from the 2026-03-22 context note, the completed 2026-03-19 tract ExecPlan, and a direct audit of the current county and tract code paths | Codex |
| 2026-03-22 | Revised the plan after user decisions: the scope now requires exact county/tract parity for the four requested assumptions, and Milestone 4 now uses the strict interpretation that replaces the legacy county ACS path with an annual `tidycensus` pull | Codex |
| 2026-03-22 | Executed Milestone 1: shortened the county and tract panel horizons to `2019`, updated the affected county descriptive scripts, reran the milestone outputs, and validated that the county reduced-form sample and model summaries did not change | Codex |
| 2026-03-22 | Executed Milestone 2: removed the obsolete `2010:2013` treatment shortcut from the county and tract pre-covariate builders, reran the affected artifacts, and validated that the county reduced-form sample and model summaries still did not change | Codex |
| 2026-03-22 | Executed Milestone 3: restricted county and tract scope to the contiguous U.S. plus Washington, D.C., reran the affected ingest, tract-panel, event-study-sample, and county descriptive scripts, and validated that Alaska, Hawaii, and the territories are fully excluded from the refreshed outputs | Codex |
| 2026-03-22 | Executed Milestone 4: replaced the legacy county ACS path with annual county-level `tidycensus` pulls plus `2010` backfill, repointed the county analysis panel to the new ACS artifact, reran the downstream tract, reduced-form, and county descriptive scripts, and validated that the county panel controls now match the new ACS artifact exactly | Codex |

## Quick Summary

### Goal

Make the county and tract pipelines match exactly on the four requested reduced-form input assumptions: both branches should stop at `2019`, both should remove the obsolete `2010:2013` treatment shortcut, both should restrict geography to the 48 contiguous states plus Washington, D.C., and both should use annual ACS 5-year estimates from `tidycensus` with the year of the ACS estimate matched to the panel year.

### Deliverable

The deliverable is a narrow but complete parity patch across county and tract ingest and analysis-panel builders. When complete, the repository will have refreshed county and tract analysis artifacts whose scope rules and covariate timing assumptions match one another, plus refreshed county descriptives that no longer depend on `2020`.

### Success Criteria

- `2_9_analysis/2_9_0_us_analysis_panel.rds`, `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`, and `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` all stop at `2019`.
- Neither the county builder nor the tract pre-covariate builder contains the `treatment = if_else(year %in% 2010:2013, 1L, treatment)` shortcut.
- County and tract outputs used for reduced form and descriptives exclude Alaska, Hawaii, and the territories, while retaining Washington, D.C.
- The county ACS ingest path is rebuilt from annual ACS 5-year pulls through `tidycensus`, using the same variable definitions and `2010` backfill rule as the tract ACS path.
- The county reduced-form sample and downstream reduced-form outputs remain unchanged after Milestones 1 and 2, then change only in Milestones 3 and 4.

### Key Files

- `agent-docs/agent_context/2026_03_22_county_tract_standardization.md`
- `agent-docs/execplans/2026-03-19-waiver-geographies-execplan.md`
- `0_inputs/census_apikey.md`
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R`
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R`
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R`
- `1_code/1_0_ingest/tract_ingest_helpers.R`
- `1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R`
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_2_ACS_prep.R`
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R`
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R`
- `1_code/1_1_descriptives/shared_us_analysis_helpers.R`
- `1_code/1_1_descriptives/1_1_0_waivers/shared_us_analysis_helpers.R`
- `1_code/1_1_descriptives/1_1_1_retailers/shared_us_analysis_helpers.R`
- `1_code/1_1_descriptives/1_1_0_waivers/1_1_0_1_ds_stock_trend_by_waiver.R`
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_0_retailer_format_stock_index.R`
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_1_retailer_format_stock_index_rural.R`
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_5_ds_stock_growth_by_treatment_status.R`

## Purpose / Big Picture

After this change, county and tract reduced-form inputs will be aligned on the assumptions that matter for the next round of work. A contributor should be able to compare county and tract reduced-form or descriptive outputs knowing that any difference is not coming from hidden differences in panel horizon, geography scope, or ACS timing rules.

This plan remains intentionally narrow. It does not redesign the reduced form, alter outcome definitions, repair any older conceptual issues in variable naming, or refactor the repository broadly. The only goal is to enforce exact parity between county and tract data ingestion assumptions for the four requested changes.

An “annual ACS 5-year estimate” here means the Census American Community Survey 5-year product published for year `t`, summarizing approximately the five-year window ending in year `t`. In this plan, both county and tract row `year = t` should use the ACS 5-year product for year `t` when `t` is between `2010` and `2019`, and rows in `2000:2009` should inherit the `2010` ACS 5-year values so the existing long panel structure is preserved.

## Progress

- [x] (2026-03-22 20:20 America/Chicago) Read `agent-docs/PLANS.md` and the provided context note.
- [x] (2026-03-22 20:30 America/Chicago) Re-read the completed tract ExecPlan from `2026-03-19`.
- [x] (2026-03-22 20:45 America/Chicago) Audited the current county builder and confirmed that it still creates a `2000:2020` county-year grid and still forces `treatment = 1` in `2010:2013`.
- [x] (2026-03-22 20:50 America/Chicago) Audited the current tract builders and confirmed that the final tract panel stops at `2019`, but the tract pre-covariate builder still creates `2000:2020` rows and still forces `treatment = 1` in `2010:2013`.
- [x] (2026-03-22 20:55 America/Chicago) Checked the live processed county and tract artifacts and confirmed that both still include Alaska and Hawaii while excluding the territories.
- [x] (2026-03-22 21:00 America/Chicago) Checked the current county ACS inputs and confirmed that the strict Milestone 4 must actively replace the existing legacy county covariate path rather than merely verify it.
- [x] (2026-03-22 21:15 America/Chicago) Resolved the planning scope with the user: the patch must enforce exact county/tract parity and must use a strict county ACS replacement built from `tidycensus`.
- [x] (2026-03-22 13:40 America/Chicago) Implemented Milestone 1, reran the county and tract panel builders plus the affected county descriptive and reduced-form scripts, and validated that the county reduced-form sample and model summaries are unchanged.
- [x] (2026-03-22 14:05 America/Chicago) Implemented Milestone 2, reran the county and tract panel builders plus the county event-study sample builder, and validated that the county reduced-form sample and model summaries are unchanged.
- [x] (2026-03-22 15:57 America/Chicago) Implemented Milestone 3, reran the county scope, tract waiver, tract retailer, tract panel, county event-study-sample, and affected county descriptive scripts, and validated that county, tract, and county event-study artifacts now exclude Alaska, Hawaii, and the territories while retaining Washington, D.C.
- [x] (2026-03-22 17:20 America/Chicago) Implemented Milestone 4, rewrote the county ACS ingest path around annual `tidycensus` county pulls plus `2010` backfill, repointed the county analysis panel to the new ACS artifact, reran the affected tract, county reduced-form, and county descriptive scripts, and validated the new county ACS coverage and panel merge behavior.
- [x] (2026-03-22 17:20 America/Chicago) Refreshed the affected county descriptive artifacts after Milestones 1, 3, and 4.

## Surprises & Discoveries

- Observation: The county branch still explicitly builds a `2000:2020` panel and still applies the obsolete treatment shortcut.
  Evidence: `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` uses `year = 2000:2020` and `treatment = if_else(year %in% 2010:2013, 1L, treatment)`.

- Observation: The tract branch did not fully remove those two behaviors.
  Evidence: `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R` still uses `year = 2000:2020` and the same `2010:2013` treatment override, even though `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R` filters the retained tract panel to `year <= 2019`.

- Observation: The tract geography restriction was only partially implemented.
  Evidence: `1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R` and `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R` explicitly ignore only `60`, `66`, `69`, `72`, and `78`, not Alaska `02` or Hawaii `15`.

- Observation: Tract scope is inherited from the county analysis panel, so once county scope is corrected and tract scripts are rerun, tract geography will also contract.
  Evidence: `1_code/1_0_ingest/tract_ingest_helpers.R` defines `get_county_scope()` by reading `2_9_analysis/2_9_0_us_analysis_panel.rds`, and `load_scope_tracts()` loads only tracts whose counties appear in that county panel.

- Observation: The current county builder still relies on a legacy covariate split across three processed files plus a price file for income and rent.
  Evidence: `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` reads `2_1_0_unemployment.rds`, `2_1_2_population.rds`, `2_1_3_Append_CountyDP03.rds`, and `0_4_prices/0_4_2_Prices.csv`.

- Observation: Exact tract parity in Milestone 4 requires matching tract variable definitions, not merely matching the idea of time variation.
  Evidence: `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R` defines `meanInc` and `income` from `B20002_001E`, `population` from `B11001_001E`, `rent` from `B25064_001E`, and unemployment from a `B23025` or `B23001` ratio. County Milestone 4 must mirror those same definitions unless the user explicitly chooses a different county definition.

- Observation: Milestone 1 changed only the intended horizon artifacts and did not change the county reduced-form layer.
  Evidence: after rerunning Milestone 1, `2_9_analysis/2_9_0_us_analysis_panel.rds`, `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`, and `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` all report `max(year) = 2019` and zero `2020` rows, while the rebuilt county event-study sample still has `12202` rows and the recomputed ATT summaries across all eight county event-study outcomes have `max_abs_diff = 0` relative to the pre-Milestone-1 baseline.

- Observation: Removing the obsolete `2010:2013` shortcut did not eliminate all pre-2014 treated rows, because some are real treatment observations rather than shortcut-generated rows.
  Evidence: after Milestone 2, the county panel still has `4610` rows with `year %in% 2010:2013` and `treatment == 1`, and the tract final panel still has `109925` such rows, down from the shortcut-inflated baselines of `12624` and `292124` respectively. The shortcut line itself is gone from both builders, and the county event-study sample still has `12202` rows with ATT summaries that match the Milestone-1 baseline exactly (`max_abs_diff = 0`).

- Observation: Milestone 3 produced the intended contiguous-U.S.-plus-D.C. scope change and is the first milestone that moved the county reduced-form sample.
  Evidence: after rerunning Milestone 3, `2_9_analysis/2_9_0_us_analysis_panel.rds` has `0` Alaska rows, `0` Hawaii rows, `0` territory rows, and `20` Washington, D.C. rows; `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` has `0` Alaska rows, `0` Hawaii rows, `0` territory rows, and `3580` Washington, D.C. rows; and `2_9_analysis/2_9_2_event_study_sample.rds` has `0` Alaska rows, `0` Hawaii rows, `0` territory rows, and `6` Washington, D.C. rows. The county event-study sample fell from `12202` rows to `11998` rows, which is consistent with scope contraction rather than an unintended horizon or treatment-coding change.

- Observation: The Census county crosswalk includes `UM` with state FIPS `74`, so the county ACS ingest needed a broader exclusion list than the earlier county/tract scope milestones.
  Evidence: `prepare_county_crosswalk()` returns a `UM` row with `state_fips == "74"`, and the first Milestone-4 ACS pull failed until `74` was added to the excluded-state list used by the county ACS script.

- Observation: The new county ACS artifact preserves the live `3119`-county scope, but annual ACS nonreturns leave a small number of county-year covariate gaps that were silently papered over by the legacy path.
  Evidence: `2_1_acs/2_1_12_acs_county_2000_2019_covariates.rds` has `62380` rows spanning `2000:2019` with `31190` backfill rows and `31190` annual rows, but the annual summary shows only `3109` joined counties in `2010:2013` and `3108` joined counties in `2014:2019`. The biggest persistent gaps are the Connecticut planning-region-style codes `09110:09190` and `46102`, while additional sparse gaps appear for counties such as `48301`, `42033`, `51515`, `46113`, `49009`, `32011`, `32029`, and `35039`.

- Observation: Milestone 4 changed the county reduced-form controls without changing the county reduced-form sample size.
  Evidence: after rerunning Milestone 4, `2_9_analysis/2_9_2_event_study_sample.rds` still has `11998` rows, but the refreshed county event-study regressions report `10` RHS-side dropped observations due to missing control values under the new county ACS path. A direct merge check shows `0` mismatches between the county panel columns `meanInc`, `income`, `rent`, `population`, and `urate` and the new county ACS artifact on shared county-year keys.

## Decision Log

- Decision: The execution plan must enforce exact parity between county and tract pipelines for the four requested assumptions, even if this requires tract-side cleanup as well as county edits.
  Rationale: The user explicitly said the plan should ensure exact parity in data ingestion and reduced-form assumptions.
  Date/Author: 2026-03-22 / Inder Majumdar + Codex

- Decision: Milestone 4 will use the strict interpretation and replace the legacy county ACS source path with annual ACS 5-year pulls from `tidycensus`.
  Rationale: The user explicitly rejected a verification-only Milestone 4 and asked for a real data-source replacement.
  Date/Author: 2026-03-22 / Inder Majumdar + Codex

- Decision: This plan should stay narrowly focused on the four requested changes and should not fix other conceptual issues unless those fixes are mechanically required to implement parity.
  Rationale: The user explicitly warned against introducing unrelated logical changes during this patch.
  Date/Author: 2026-03-22 / Codex

- Decision: Accept the small Milestone-4 estimation-stage sample loss from the new county ACS regime rather than adding another imputation or fallback layer.
  Rationale: After review, the user judged that the `10` dropped regression observations are acceptably small relative to the county event-study sample and do not justify further scope expansion in this standardization pass.
  Date/Author: 2026-03-22 / Inder Majumdar + Codex

## Outcomes & Retrospective

All four milestones are complete. The county, tract pre-covariate, and tract final analysis artifacts all stop at `2019`; the obsolete `2010:2013` shortcut has been removed from the county and tract builders; county plus tract scope excludes Alaska, Hawaii, and the territories while retaining Washington, D.C.; and the county control path now comes from annual county ACS pulls with tract-style `2010` backfill.

The two behavior-preserving milestones, Milestones 1 and 2, passed the reduced-form verification: the county event-study sample remained unchanged and the recomputed ATT summaries for all eight county event-study outcomes matched the pre-change baselines exactly. Milestone 3 then produced the first intended sample change: the rebuilt county event-study sample has `11998` rows, down from `12202`, after the Alaska and Hawaii exclusions were applied consistently.

Milestone 4 then replaced the legacy county ACS covariate path with the new canonical outputs `2_1_acs/2_1_11_acs_county_2010_2019_raw.rds`, `2_1_acs/2_1_12_acs_county_2000_2019_covariates.rds`, and `2_1_acs/2_1_13_acs_county_2000_2019_summary.rds`. The county panel now sources `meanInc`, `income`, `rent`, `population`, and `urate` from that new ACS artifact exactly, and the county reduced-form/descriptive scripts have been refreshed against those controls.

The main residual risk is not code wiring but data coverage: the new county ACS path surfaces a small set of county-year nonreturns that leave `NA` controls in a handful of rows. Those gaps are now explicit and auditable in the county ACS summary rather than being hidden inside the legacy input bundle. The user reviewed the resulting loss and explicitly accepted the `10`-observation estimation-stage drop, so no further spec items remain open under this plan.

## Context and Orientation

The county reduced-form input panel is built by `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R`. That script currently creates one row per county-year from `2000` through `2020`, merges waiver treatment, retailer outcomes, and county covariates, and writes `2_9_analysis/2_9_0_us_analysis_panel.rds`. The county reduced-form sample in `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R` already filters to `2014:2019`, so Milestones 1 and 2 should not affect that sample.

The tract branch is split into tract-specific waiver geography mapping, tract-specific retailer assignment, a tract pre-covariate panel builder, and a tract final-panel builder that merges annual ACS controls. The most important files are `1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R`, `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R`, `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R`, and `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R`.

The tract ACS path in `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R` is the template for Milestone 4. It reads the Census API key from `0_inputs/census_apikey.md`, pulls annual ACS 5-year tract estimates for `2010:2019`, uses the published ACS year as the panel year for those rows, and repeats the `2010` ACS values onto `2000:2009`. County Milestone 4 should mirror that timing rule and those variable definitions, but at county geography.

The county descriptive layer depends on helper files that still manufacture `2000:2020` or `2010:2020` year grids. If Milestone 1 changes the county panel to stop at `2019`, these helper files and the small set of directly affected county descriptive scripts must be updated in the same milestone or they will create artificial `2020` rows filled with zeros.

## Plan of Work

### Milestone 1: End both panel branches at 2019

Update `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` so the county-year grid is `2000:2019`, not `2000:2020`. This change should happen where the county-year grid is created, not only by filtering after the fact, because the grid itself defines the county scope that later tract helpers inherit.

Update `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R` so the tract-year grid is also `2000:2019`, not `2000:2020`. The retained final tract panel already truncates to `2019`, but the upstream pre-covariate artifact should match the retained horizon so the tract pipeline is internally consistent.

Update the county descriptive helper files `1_code/1_1_descriptives/shared_us_analysis_helpers.R`, `1_code/1_1_descriptives/1_1_0_waivers/shared_us_analysis_helpers.R`, and `1_code/1_1_descriptives/1_1_1_retailers/shared_us_analysis_helpers.R` so any internally manufactured county-year grids use `2000:2019`. Then update the explicitly `2020`-bound county descriptive scripts `1_code/1_1_descriptives/1_1_0_waivers/1_1_0_1_ds_stock_trend_by_waiver.R`, `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_0_retailer_format_stock_index.R`, `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_1_retailer_format_stock_index_rural.R`, and `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_5_ds_stock_growth_by_treatment_status.R` so their plotted year windows are `2010:2019`.

Milestone 1 should not change the county reduced-form sample or downstream reduced-form outputs because the sample builder already filters to `2014:2019`. This milestone therefore needs an explicit no-change verification in the reduced-form layer, not just a panel-horizon check.

### Milestone 2: Remove the obsolete 2010:2013 treatment shortcut in both branches

Remove the line `treatment = if_else(year %in% 2010:2013, 1L, treatment)` from `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R`.

Remove the identical line from `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R`.

Do not change the `eventYear2` logic or the `year >= 2014` filter used to construct the reduced-form treatment timing. The whole point of Milestone 2 is to remove only the shortcut, not to redesign treatment coding more broadly.

Milestone 2 should also leave the county reduced-form sample unchanged because the sample builder still reads only `2014:2019`.

### Milestone 3: Restrict both branches to the 48 contiguous states plus Washington, D.C.

In `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R`, define the retained county universe so it excludes state FIPS `02`, `15`, `60`, `66`, `69`, `72`, and `78`. Use the county FIPS code, not the state name string, as the scope rule. The safest implementation is to build the county-year grid only from counties whose state FIPS are retained. That way all later joins inherit the same county scope.

Because tract scope is inherited from the county panel through `load_scope_tracts()`, rerunning the county panel after this change will shrink the tract county scope automatically. Still, update `1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R` and `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R` so their explicit `ignored_state_fips` vectors also include `02` and `15`. This keeps tract diagnostics honest: Alaska and Hawaii should appear as intentional exclusions, not as unexplained retained rows or unexplained drops.

Do not alter Washington, D.C. handling. The current processed county and tract artifacts already include D.C., and the user explicitly wants to retain it.

Milestone 3 is the first milestone expected to change estimation results.

### Milestone 4: Replace the legacy county ACS path with tract-style annual tidycensus pulls

Rewrite `1_code/1_0_ingest/1_0_1_covariates/1_0_1_2_ACS_prep.R` so it no longer merely promotes legacy files from `0_inputs/0_1_acs`. Instead, it should use `tidycensus` plus the API key in `0_inputs/census_apikey.md` to pull county-level annual ACS 5-year estimates for `2010:2019`.

This county ACS pull must use the same variable definitions as the tract ACS script in `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R`. That means:

- `meanInc` and `income` should both be defined from `B20002_001E`, exactly as in tract.
- `rent` should be defined from `B25064_001E`, exactly as in tract.
- `population` should be defined from `B11001_001E`, exactly as in tract, even though the column name is historically `population` in the county panel.
- `urate` should be defined from `B23025` when available and otherwise from a `B23001` fallback, exactly as in tract.

The county ACS script should then construct a `2000:2019` county-year covariate panel by repeating the `2010` ACS values onto `2000:2009`, exactly paralleling the tract backfill rule. It should write a new canonical county ACS covariate artifact and a summary artifact. Use new output names rather than overwriting the older legacy-file names, so execution is auditable. A good pattern is:

- `2_1_acs/2_1_11_acs_county_2010_2019_raw.rds`
- `2_1_acs/2_1_12_acs_county_2000_2019_covariates.rds`
- `2_1_acs/2_1_13_acs_county_2000_2019_summary.rds`

After that script is rewritten, update `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` so the county analysis builder stops reading `2_1_0_unemployment.rds`, `2_1_2_population.rds`, `2_1_3_Append_CountyDP03.rds`, and `0_4_prices/0_4_2_Prices.csv` for the reduced-form controls. Instead, it should read the new canonical county ACS covariate artifact plus the existing county wage file. Keep the output column names `meanInc`, `income`, `rent`, `population`, and `urate` so downstream reduced-form and descriptive code does not need to change.

Milestone 4 is the second milestone expected to change estimation results.

## Concrete Steps

All commands below should be run from `/Users/indermajumdar/Research/snap_dollar_entry`.

Do not use the full stage runner while executing this plan. `1_code/run_refactor_pipeline.R` will run every ingest script, including legacy county ACS scripts and unrelated tract scripts. The safer path is to run only the scripts touched by the active milestone.

For Milestone 1, run:

    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_1_event_study_total_ds.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_2_event_study_chain_super_market.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_3_event_study_chain_convenience_store.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_4_event_study_chain_multi_category.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_5_event_study_chain_medium_grocery.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_6_event_study_chain_small_grocery.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_7_event_study_chain_produce.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_8_event_study_chain_farmers_market.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_9_event_study_all_table.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_11_event_study_all_table_image.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_0_waivers/1_1_0_1_ds_stock_trend_by_waiver.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_0_retailer_format_stock_index.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_1_retailer_format_stock_index_rural.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_5_ds_stock_growth_by_treatment_status.R

For Milestone 2, run:

    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R

For Milestone 3, run:

    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_0_waivers/1_1_0_1_ds_stock_trend_by_waiver.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_0_retailer_format_stock_index.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_1_retailer_format_stock_index_rural.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_5_ds_stock_growth_by_treatment_status.R

For Milestone 4, run:

    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_1_covariates/1_0_1_2_ACS_prep.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_0_waivers/1_1_0_1_ds_stock_trend_by_waiver.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_0_retailer_format_stock_index.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_1_retailer_format_stock_index_rural.R
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_5_ds_stock_growth_by_treatment_status.R

## Validation and Acceptance

Milestone 1 validation:

- Read `2_9_analysis/2_9_0_us_analysis_panel.rds`, `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`, and `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` and verify `max(year) == 2019` with zero `2020` rows in all three artifacts.
- Rebuild `2_9_analysis/2_9_2_event_study_sample.rds` and confirm it is unchanged relative to the pre-Milestone-1 artifact on row count and key identifying fields.
- Rerun the county reduced-form scripts that consume `2_9_analysis/2_9_2_event_study_sample.rds` and confirm their output artifacts are unchanged relative to the pre-Milestone-1 baseline. This check exists to prove that dropping unused `2020` rows does not require any hidden reduced-form code changes that were missed in the design.

Milestone 2 validation:

- Rebuild `2_9_analysis/2_9_0_us_analysis_panel.rds`, `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`, and `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` and confirm that the `2010:2013` forced-treatment rows disappear mechanically.
- Rebuild `2_9_analysis/2_9_2_event_study_sample.rds` and confirm it is unchanged relative to the pre-Milestone-2 artifact.

Milestone 3 validation:

- Read the refreshed county and tract analysis artifacts and verify there are zero rows whose county or tract state FIPS are `02`, `15`, `60`, `66`, `69`, `72`, or `78`.
- Verify that D.C. rows remain present in the county and tract outputs.
- Check the tract waiver and retailer diagnostics and confirm Alaska and Hawaii are recorded as intentional exclusions rather than unexplained unmatched cases.

Milestone 4 validation:

- Read `2_1_acs/2_1_12_acs_county_2000_2019_covariates.rds` and confirm it spans `2000:2019`, has `acs_source_year` spanning `2010:2019`, and flags `2000:2009` rows as `2010` backfill.
- For at least one retained county, verify that `meanInc`, `rent`, and `urate` differ across `2010:2019`, proving that the county ACS file is genuinely annual.
- Read the refreshed county analysis panel and confirm the reduced-form control columns `meanInc`, `income`, `rent`, `population`, and `urate` come from the new county ACS artifact rather than the old legacy inputs.

At least one validation check per milestone must be recorded in this plan with a short evidence snippet during execution.

## Idempotence and Recovery

Every script touched by this plan already owns the artifacts it writes. Safe recovery means fixing the code and rerunning only the affected script or scripts. Do not rerun the entire pipeline unless a downstream dependency truly requires it.

Milestones 1 and 2 should be completed and validated before Milestone 3 begins. This matters because Milestones 1 and 2 are intended to be behavior-preserving for the county reduced-form sample, so they provide a stable base before the first result-changing milestone.

Milestone 4 should be executed only after Milestone 3 completes because the new county ACS pull should target the final contiguous-U.S.-plus-D.C. county scope, not the older broader county set.

## Artifacts and Notes

These baseline facts should remain attached to the plan because they define the pre-execution state.

    County baseline:
    - `2_9_analysis/2_9_0_us_analysis_panel.rds` spans `2000:2020`
    - it contains `3156` rows in `2020`
    - it contains `12624` rows with `year %in% 2010:2013` and `treatment == 1`
    - it includes Alaska and Hawaii rows
    - it excludes territory state FIPS `60`, `66`, `69`, `72`, and `78`

    Tract baseline:
    - `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds` spans `2000:2020`
    - `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds` spans `2000:2019`
    - the final tract artifact still contains `292124` rows with `year %in% 2010:2013` and `treatment == 1`
    - the final tract artifact still includes Alaska and Hawaii rows

    County ACS baseline:
    - the county builder still reads legacy processed county files and a legacy price file for reduced-form controls
    - Milestone 4 therefore must replace an active input path, not merely add a side artifact

## Data Contracts, Inputs, and Dependencies

`1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` must continue to write one row per retained county-year to `2_9_analysis/2_9_0_us_analysis_panel.rds`. After Milestone 4, its required reduced-form control inputs are the county wage file plus the new county ACS covariate artifact. The invariant is that the output still exposes the columns consumed downstream by reduced form: `population`, `wage`, `meanInc`, `rent`, and `urate`.

`1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R` must continue to write one row per retained tract-year to `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`. Its retained year grid must match the final tract panel horizon.

`1_code/1_0_ingest/1_0_1_covariates/1_0_1_2_ACS_prep.R` will become the canonical county ACS ingest script. It should consume `0_inputs/census_apikey.md`, `2_processed_data/processed_root.txt`, and the retained county scope implied by the contiguous-U.S.-plus-D.C. rules. It should produce a canonical county covariate file and a county summary file whose row structure is one row per retained county-year in `2000:2019`.

`1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R` remains the county template for ACS timing and variable definitions. This plan does not alter the tract ACS definitions; it only forces the county branch to match them.

The county descriptive helper files must continue to provide in-memory county-year tables that are consistent with the retained county panel horizon. They should not create extra years that do not exist in `2_9_analysis/2_9_0_us_analysis_panel.rds`.

All execution should use `/usr/local/bin/Rscript`. The shell-default `Rscript` on this machine should not be trusted for this repository.

## Completion Checklist

- [x] County and tract analysis artifacts all stop at `2019`.
- [x] County and tract pre-`2014` treatment shortcuts are removed.
- [x] County and tract retained scopes exclude Alaska, Hawaii, and the territories while retaining Washington, D.C.
- [x] County ACS controls are rebuilt from annual `tidycensus` 5-year pulls using the same variable definitions and timing rules as tract.
- [x] County reduced-form sample and downstream reduced-form outputs are unchanged after Milestones 1 and 2.
- [x] Validation checks for Milestones 3 and 4 confirm the intended scope and covariate-source changes.
- [x] `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` are updated during execution.

Change note: This revision incorporates the user’s decisions that the patch must enforce exact county/tract parity and that Milestone 4 must replace, not merely audit, the county ACS source path.
