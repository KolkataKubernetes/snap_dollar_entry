# Build tract-level ingest and descriptive companions for the SNAP dollar-entry pipeline

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

---

## ExecPlan Status

Status: In Progress (Milestone 1 Complete)  
Owner: Inder Majumdar + Codex  
Created: 2026-03-19  
Last Updated: 2026-03-20  
Related Project: `snap_dollar_entry` tract-level waiver geography expansion

Optional Metadata:
Priority: High  
Estimated Effort: Multi-day  
Dependencies: local Box-backed roots in `0_inputs/input_root.txt` and `2_processed_data/processed_root.txt`; local geometry files in `0_8_geographies`; local Census API key file in `0_inputs/census_apikey.md`

---

## Revision History

| Date | Change | Author |
|-----|------|------|
| 2026-03-19 | Initial tract ExecPlan drafted from `agent-docs/agent_context/2026_03_19_waiver_geographies.md`, the current repo inventory, and current processed artifacts | Codex |
| 2026-03-19 | Updated the plan for the new segmented script/output layout, scoped out FIPS `60`, `66`, `69`, `72`, and `78`, fixed `Gosnold` to Massachusetts, dropped tract reduced-form work from scope, and recorded that `tidycensus` is installed | Codex |
| 2026-03-19 | Updated the plan to use the local Census API key file, to write tract descriptives into the existing waiver and retailer descriptive output folders, and to use `philadelphia_divisions.md` from the input root for the Philadelphia county list | Codex |
| 2026-03-20 | Recorded the Milestone 1 retailer-scope discovery that upstream `county_fips` in `2_5_0_snap_clean.rds` is derived by string-matching SNAP `County` and `State` to `national_county.txt`, and revised the intended tract retailer refinement to use lat/long as the first scope-and-match pass before county-based fallback | Codex |
| 2026-03-20 | Revised the intended tract retailer refinement again so the first validation step is a state-label-to-state-FIPS match from `national_county.txt`, then a state-restricted point-in-polygon tract assignment, then county-assisted fallback only if direct assignment fails | Codex |

---

## Quick Summary

**Goal**

Extend the existing county-based pipeline so the project can build tract-level waiver and retailer analysis panels and then generate tract-level descriptive outputs. This matters only if the tract branch stays aligned to the current county production scope, uses the new segmented ingest layout, preserves tract-versus-county comparability, and stops before any tract reduced-form design is imposed.

**Deliverable**

The completed work will add tract-specific ingest scripts, tract-specific processed analysis artifacts, and tract companion descriptive scripts. The observable deliverables are a tract waiver panel, a tract analysis panel before and after covariate matching, and tract descriptive outputs written into the existing descriptive output folders with `_tract` in their filenames and user-facing titles.

**Success Criteria**

- Running the new tract ingest scripts writes tract waiver, retailer, covariate, and analysis artifacts to the processed-data root without altering the existing county artifacts.
- Every observed waiver `LOC_TYPE` inside the tract-analysis scope is either mapped to tracts by an explicit rule or documented as an intentional exclusion in diagnostics.
- State FIPS codes `60`, `66`, `69`, `72`, and `78` are treated as out of scope and do not count as unexpected tract-match failures.
- The tract pre-covariate panel is larger than the county analysis panel and the tract diagnostics show no unexpected loss of in-scope waiver conferrals.
- The tract covariate merge is complete for the tract ACS controls, and at least one tract waiver descriptive output and one tract retailer descriptive output are created in `3_outputs/3_1_descriptives/3_1_0_waivers/` and `3_outputs/3_1_descriptives/3_1_1_retailers/`, each marked with `_tract`.

**Key Files**

- `agent-docs/agent_context/2026_03_19_waiver_geographies.md`
- `agent-docs/PLANS.md`
- `0_inputs/census_apikey.md`
- `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R`
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_0_SNAP_retailer_ingest.R`
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_2_ACS_prep.R`
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R`
- `1_code/1_1_descriptives/1_1_0_waivers/shared_us_analysis_helpers.R`
- `1_code/1_1_descriptives/1_1_1_retailers/shared_us_analysis_helpers.R`
- `1_code/run_refactor_pipeline.R`
- `agent-docs/execplans/2026-03-19-waiver-geographies-execplan.md`

---

## Purpose / Big Picture

After this change, a contributor should be able to keep running the existing county pipeline exactly as before and also run an additive tract branch that stops at ingest plus descriptives. The user-visible improvement is that the project will support tract-level waiver and retailer descriptive evidence without forcing an early commitment to a tract reduced-form strategy.

This plan is intentionally narrower than the earliest tract draft. The tract reduced-form layer is out of scope. The tract work in scope is only: waiver-to-tract geography handling, retailer-to-tract outcome construction, tract covariate construction, tract analysis panel assembly, and tract descriptive outputs written into the existing descriptive output folders with `_tract` added so they are easy to identify.

---

## Progress

- [x] (2026-03-19 21:45Z) Reviewed `agent-docs/agent_context/2026_03_19_waiver_geographies.md`.
- [x] (2026-03-19 21:55Z) Reviewed `agent-docs/PLANS.md`, `agent-docs/ExecPlan_TEMPLATE.md`, and the existing completed ExecPlan in `agent-docs/execplans/`.
- [x] (2026-03-19 22:10Z) Inventoried the production county pipeline and confirmed the tract work must start from the same live waiver artifact the county panel uses.
- [x] (2026-03-19 22:35Z) Enumerated all observed waiver `LOC_TYPE` values and confirmed they match the user’s context note.
- [x] (2026-03-19 22:45Z) Confirmed the local geometry inventory includes tract, place, county-subdivision, AIANNH, NYC community-district, and Maine LMA files, and that Massachusetts county subdivisions contain NECTA codes.
- [x] (2026-03-19 23:05Z) Confirmed the processed SNAP retailer panel retains complete store-level latitude and longitude, which is sufficient to build tract-level retailer counts without a new geocoder.
- [x] (2026-03-19 23:15Z) Confirmed the shell-default `Rscript` is broken on this machine and `/usr/local/bin/Rscript` is the working executable.
- [x] (2026-03-19 23:30Z) Wrote the initial tract ExecPlan locally.
- [x] (2026-03-19 23:50Z) Re-inventoried the repo after the user’s directory reorganization and confirmed the new segmented code structure.
- [x] (2026-03-19 23:55Z) Confirmed `tidycensus` is now installed in the working `/usr/local/bin/Rscript` environment.
- [x] (2026-03-20 00:05Z) Confirmed the local Census API key file exists at `0_inputs/census_apikey.md`.
- [x] (2026-03-20 00:10Z) Updated the ExecPlan so tract descriptives write into the existing waiver and retailer descriptive output folders rather than new tract-only output directories.
- [x] (2026-03-19 America/Chicago) Added `1_0_0_2_waiver_geographies_to_tracts.R`, `1_0_1_3_SNAP_retailer_tract_panel.R`, `1_0_2_1_build_analysis_panel_tract_pre_covariates.R`, and `1_code/1_0_ingest/tract_ingest_helpers.R`.
- [x] (2026-03-19 America/Chicago) Ran Milestone 1 successfully and wrote `2_0_6`, `2_0_7`, `2_0_8`, `2_5_2`, `2_5_3`, `2_5_4`, and `2_9_3` to the Box-backed processed-data root.
- [x] (2026-03-19 America/Chicago) Verified the tract waiver diagnostics have zero unexpected retained-geography drops and the tract pre-covariate panel is larger than the county panel.
- [x] (2026-03-20 America/Chicago) Refined `1_0_1_3_SNAP_retailer_tract_panel.R` so retailer state labels are validated against `national_county.txt`, the initial tract intersect is restricted to the validated state tract layer, and rows with missing derived county FIPS are still eligible for spatial tract assignment.
- [x] (2026-03-20 America/Chicago) Re-ran the tract retailer and tract pre-covariate scripts. The refreshed retailer diagnostics now show `828767` matched in-scope rows, only `1573` out-of-scope rows, and `29739` assigned rows whose tract match was recovered despite missing upstream `county_fips_original`.
- [ ] Add tract descriptive companion scripts into the existing descriptive script folders and ensure their outputs land in the existing descriptive output folders with `_tract`-suffixed names and titles.
- [ ] Execute tract ACS/covariate ingest, validate geometry coverage and covariate completeness, then execute tract descriptives and update this ExecPlan as work proceeds.

---

## Surprises & Discoveries

- Observation: The live production county pipeline still uses `2_0_4_waived_data_consolidated_long.rds`, even though a larger `_selected` waiver artifact also exists.
  Evidence: the county build script reads `2_0_4_waived_data_consolidated_long.rds`, while `_selected` exists only as a processed artifact.

- Observation: All observed non-county geography classes in the live waiver data were already described in the user’s memo; there are no surprise `LOC_TYPE` values to plan around.
  Evidence: the live waiver artifact contains 21 `LOC_TYPE` values and all are covered by the memo.

- Observation: The repo now uses segmented script directories for ingest and descriptives.
  Evidence: ingest is split across `1_0_0_waivers`, `1_0_1_covariates`, and `1_0_2_build_panel`, while descriptives are split across `1_1_0_waivers` and `1_1_1_retailers`.

- Observation: the user wants tract descriptives saved into the existing county descriptive output folders rather than new tract-only output folders.
  Evidence: the requested targets are `3_outputs/3_1_descriptives/3_1_0_waivers/` for tract waiver descriptives and `3_outputs/3_1_descriptives/3_1_1_retailers/` for tract retailer descriptives.

- Observation: The local tract shapefile inventory does not include FIPS `60`, `66`, `69`, `72`, or `78`, and the user explicitly said these can be ignored.
  Evidence: the local tract zip inventory omits those codes, and the user confirmed they are irrelevant island territories for this project.

- Observation: The current SNAP processed retailer panel is already suitable for tract assignment because it preserves complete point coordinates.
  Evidence: `2_5_SNAP/2_5_0_snap_clean.rds` has `830340` rows and zero missing `Latitude` or `Longitude` values.

- Observation: The upstream SNAP `county_fips` field used by the tract retailer script is not a raw source field; it is derived in `1_0_1_0_SNAP_retailer_ingest.R` by exact string matching SNAP `County` and `State` labels against `0_3_county_list/national_county.txt`.
  Evidence: the upstream ingest merges the SNAP retailer panel to the Census county list on cleaned `County` and `State`, and the first tract retailer run showed `30290` rows with missing `county_fips_original` that still had usable point coordinates.

- Observation: `national_county.txt` already carries the state-abbreviation to state-FIPS mapping needed for a tract-specific state validation step before any county matching is used.
  Evidence: the file is structured as `state_id`, `state_fips`, `county_fips_component`, `county_name`, `classfp`, so the first two columns are enough to validate and standardize SNAP `State` labels independently of the county-name match.

- Observation: Milestone 1 required several tract-branch alias fixes that were not visible from the county pipeline because county-only rows had already been standardized differently.
  Evidence: the tract waiver crosswalk needed explicit normalizations for `Shannon County`/`Oglala Lakota County`, `Dickenson County`, the Rhode Island `Kingstown` spellings, `Dummer`, `Burrillville`, `San Ildefonso Pueblo`, and the Fort Sill Apache reservation naming variant before diagnostics reached zero unexpected drops.

- Observation: The reservation source contains at least one case where the waiver state label does not align cleanly with the tract-intersection footprint.
  Evidence: the `Fort Sill Apache` waiver row is tagged `NM`, but the matched AIANNH geometry intersects tract scope in Oklahoma and Texas, so the tract script now uses a national reservation-intersection fallback rather than enforcing the waiver state filter for reservation polygons.

- Observation: Retailer tract assignment by direct point-in-polygon is incomplete at the national scale even after switching from `st_within` to `st_intersects`.
  Evidence: the refreshed Milestone 1 retailer diagnostics show `557200` direct point-in-polygon assignments and `271567` nearest-tract fallbacks, with `4388` county-prefix mismatches remaining after the state-first, county-assisted fallback assignment.

- Observation: The state-first retailer refinement materially reduced artificial out-of-scope loss without changing the county-mismatch total.
  Evidence: after re-running `1_0_1_3_SNAP_retailer_tract_panel.R`, retailer out-of-scope rows fell from `31312` to `1573`, all `30290` rows with missing upstream `county_fips_original` were allowed into the spatial matcher, `29739` of them received tract assignments, and the remaining out-of-scope rows are only the explicitly ignored territory states Guam (`1022`) and U.S. Virgin Islands (`551`). The county-mismatch count remained `4388`.

- Observation: `tidycensus` is now available in the working R environment.
  Evidence: `/usr/local/bin/Rscript -e 'requireNamespace("tidycensus", quietly = TRUE)'` now returns `TRUE`.

- Observation: A local Census API key file is now present in the repository.
  Evidence: `0_inputs/census_apikey.md` exists and can be read by the tract ACS ingest script.

- Observation: The live waiver panel contains one missing `STATE_ABBREV` value that should be normalized directly instead of treated as ambiguous.
  Evidence: the only blank state-abbreviation row is `Gosnold`, `Town`, `2018_MA`, and the user confirmed this row belongs to Massachusetts.

---

## Decision Log

- Decision: Treat the tract work as a companion pipeline rather than a shared parameterized refactor of the existing county scripts.
  Rationale: The user explicitly prefers separate county and tract script branches to avoid accidental changes to the incumbent county workflow.
  Date/Author: 2026-03-19 / Inder Majumdar + Codex

- Decision: Use the live production waiver source `2_0_4_waived_data_consolidated_long.rds` as the tract branch starting artifact.
  Rationale: This is the source consumed by the current county pipeline, so it preserves direct county-versus-tract comparability.
  Date/Author: 2026-03-19 / Inder Majumdar + Codex

- Decision: Ignore state FIPS codes `60`, `66`, `69`, `72`, and `78` in the tract branch.
  Rationale: The user explicitly said these island territories are not relevant for the analysis, and the local tract shapefiles do not include them.
  Date/Author: 2026-03-19 / Inder Majumdar + Codex

- Decision: Normalize `Gosnold`, `Town`, `2018_MA` to `STATE_ABBREV = "MA"` in the tract waiver crosswalk.
  Rationale: The user explicitly confirmed that the missing state is Massachusetts.
  Date/Author: 2026-03-19 / Inder Majumdar + Codex

- Decision: Use majority tract-area overlap as the default polygon-to-tract assignment rule.
  Rationale: The user selected majority area rather than any-overlap or population weighting for partial tract coverage.
  Date/Author: 2026-03-19 / Inder Majumdar + Codex

- Decision: If a retained in-scope waiver geography produces zero tract assignments under the majority-area rule, assign the tract or tied tracts with the largest overlap share and flag the case in diagnostics.
  Rationale: The user also requires that waiver conferrals not be dropped, so the majority-area rule needs an explicit recovery path for edge cases.
  Date/Author: 2026-03-19 / Codex

- Decision: Reservation and reservation-area polygons should not be constrained to the waiver row’s state abbreviation during tract intersection.
  Rationale: At least one retained waiver reservation row (`Fort Sill Apache`) would otherwise be dropped despite having a valid AIANNH geometry that intersects the tract-analysis scope outside the waiver row’s nominal state label.
  Date/Author: 2026-03-19 / Codex

- Decision: Retailer nearest-tract fallback should be restricted to the store row’s original county when that county is available in scope, and only then fall back to the full state tract set.
  Rationale: The first tract retailer run produced over `260000` county-prefix mismatches because an unrestricted state-level nearest fallback overrode the county information too aggressively.
  Date/Author: 2026-03-19 / Codex

- Decision: Revise the tract retailer scope rule after Milestone 1 so the first validation step is a SNAP `State` label to `state_fips` match using `national_county.txt`, the first tract assignment pass is a state-restricted point-in-polygon match on all coordinate-valid rows, and the upstream county string-match result is retained only for fallback and diagnostics.
  Rationale: Milestone 1 showed that using derived `county_fips_original` as the entry gate excludes retailer rows that have valid lat/long but failed the upstream county-name string match. The better tract-specific rule is to standardize `State` first using the stable state lookup already present in `national_county.txt`, restrict the initial tract intersect to that state’s tract layer for speed and clarity, then use the county match only to constrain nearest-tract fallback when available, and only then fall back to the state tract set if county matching is unavailable.
  Date/Author: 2026-03-20 / Inder Majumdar + Codex

- Decision: Use `EPSG:5070` for all area-based tract intersections.
  Rationale: The work requires a U.S.-appropriate equal-area CRS so overlap shares are meaningful.
  Date/Author: 2026-03-19 / Codex

- Decision: Use county subdivisions for Rhode Island city and town tract assignment, including the RI `City` waivers.
  Rationale: Both RI places and county subdivisions contain the relevant names, but county subdivisions align better with Rhode Island municipal geography and with the user’s RI-specific concern.
  Date/Author: 2026-03-19 / Codex

- Decision: Use `philadelphia_divisions.md` from the Box-backed input root as the source of truth for the Philadelphia metropolitan-division county list.
  Rationale: The user explicitly wants the Philadelphia division mapping read from the new input-root file rather than from the agent-context memo.
  Date/Author: 2026-03-20 / Inder Majumdar + Codex

- Decision: Keep the tract control definition `meanInc = B20003_001E / B20003_002E`, carry the county-parity `income = B20002_001E`, and document any tract-level `DP03_0063E` availability as an ingest diagnostic only.
  Rationale: The user wants the tract branch to carry the tract earnings-based income measure while still preserving parity fields needed for later comparisons.
  Date/Author: 2026-03-19 / Inder Majumdar + Codex

- Decision: Remove tract reduced-form scripts from the scope of this ExecPlan.
  Rationale: The user wants to think through the tract reduced-form strategy later and only asked for the ingest and descriptive pipeline at this stage.
  Date/Author: 2026-03-19 / Inder Majumdar + Codex

- Decision: Keep tract descriptive scripts in the existing county descriptive script folders so their outputs land in the existing descriptive output folders.
  Rationale: The descriptive helpers derive output paths from the script folder, and the user explicitly wants tract descriptives saved into `3_outputs/3_1_descriptives/3_1_0_waivers/` and `3_outputs/3_1_descriptives/3_1_1_retailers/`.
  Date/Author: 2026-03-20 / Inder Majumdar + Codex

- Decision: Distinguish tract descriptive artifacts by adding `_tract` to filenames and titles rather than by creating new output directories.
  Rationale: The user wants the tract descriptives to live beside the existing county outputs while still being easy to single out.
  Date/Author: 2026-03-20 / Inder Majumdar + Codex

- Decision: The tract ACS ingest script should read the key from `0_inputs/census_apikey.md` rather than hardcode it in script source.
  Rationale: The key is already stored locally in the repo, and using that file keeps the tract ACS pull reproducible without embedding the key in code.
  Date/Author: 2026-03-20 / Inder Majumdar + Codex

---

## Outcomes & Retrospective

**Summary of Outcome**

This section is still incomplete because Milestone 2 and the tract descriptives have not started, but Milestone 1 is now implemented and validated.

**Expected vs. Actual Result**

- Expected outcome at this stage: Milestone 1 should produce the tract waiver crosswalk, tract waiver diagnostics, tract retailer tract panel, retailer diagnostics, and the tract pre-covariate analysis panel.
- Actual outcome: those Milestone 1 artifacts now exist under the Box-backed processed-data root, the waiver plus pre-covariate validation checks pass, and the retailer tract rerun recovered tract assignments for rows that had been excluded only because the upstream county string match failed.
- Difference (if any): the retailer stage still relies heavily on nearest-tract fallback (`271567` rows) even after the state-first refinement, but it no longer uses the upstream derived `county_fips` as the scope gate. Milestone 1 is now materially better aligned with the tract design intent because valid coordinate rows can receive tract assignments even when the upstream county string match failed.

**Key Challenges Encountered**

- Challenge: the repo layout changed after the initial plan draft.  
  Resolution: the plan was revised so tract script placement and output targets follow the segmented ingest structure and the user’s descriptive-output preferences.

- Challenge: the initial tract plan assumed a later tract reduced-form layer that the user no longer wants in scope.  
  Resolution: the plan now stops at ingest plus descriptives and leaves the tract reduced-form design for a future ExecPlan.

**Lessons Learned**

- Lesson: in this repository, script-folder placement is part of the output contract because the helpers infer output destinations from the relative script path.

**Follow-up Work**

- Follow-up task: update this section and the `Progress` log after each implementation milestone.
- Follow-up task: complete Milestone 2 tract ACS/covariate ingest and assess whether the retailer fallback share needs additional refinement before tract descriptive outputs are produced.

---

## Context and Orientation

The current checked-in production pipeline is county-based and now organized into segmented directories. Ingest scripts live under `1_code/1_0_ingest/`, with waivers in `1_0_0_waivers`, retailer and control ingestion in `1_0_1_covariates`, and panel assembly in `1_0_2_build_panel`. Descriptive scripts live under `1_code/1_1_descriptives/`, with county waiver descriptives in `1_1_0_waivers` and county retailer descriptives in `1_1_1_retailers`. The reduced-form layer exists under `1_code/1_2_reduced_form/`, but tract reduced-form work is out of scope for this plan.

Three facts define the tract implementation starting point.

First, the tract branch must begin from the same waiver artifact the county pipeline uses today: `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`. There is a larger processed `_selected` artifact, but it is not consumed by the live county analysis and therefore is not the tract baseline.

Second, the tract branch cannot rely on pre-existing tract retailer counts. The current retailer ingest writes store-level SNAP rows with latitude and longitude and then aggregates them only to `county_fips`. That is enough to build tract outcomes, because the point coordinates are still available in the processed SNAP clean file.

The current retailer ingest also matters for tract scope. `1_0_1_0_SNAP_retailer_ingest.R` derives `county_fips` by matching the SNAP retailer panel’s cleaned `County` and `State` labels against `0_3_county_list/national_county.txt`; the tract retailer script initially reused that derived county code as a first-pass scope gate. After Milestone 1 auditing, that rule was revised and rerun. The tract retailer branch now first validates SNAP `State` against the `state_id`/`state_fips` lookup already present in `national_county.txt`, then uses that `state_fips` to restrict direct point-in-polygon tract assignment to the relevant state tract layer, then uses the upstream county match only to restrict nearest-tract fallback where it exists, and keeps the county-match result as a diagnostic rather than an entry requirement.

Third, descriptive output routing depends on the script folder. Because the user wants tract descriptives written into the existing descriptive output folders rather than new tract-only directories, the tract descriptive scripts should live alongside the county descriptive scripts: tract waiver descriptives in `1_code/1_1_descriptives/1_1_0_waivers/` and tract retailer descriptives in `1_code/1_1_descriptives/1_1_1_retailers/`. The tract artifacts are then distinguished by `_tract` in filenames and user-facing titles.

In this plan, a “conferral” means one retained waiver geography-period observation from the live waiver source after removing the explicitly ignored territory FIPS codes `60`, `66`, `69`, `72`, and `78`. A “crosswalk” means a table that expands one waiver or retailer observation into one or more tract identifiers together with diagnostic fields explaining that expansion. A “tract panel” means an annual `tract_fips` by `year` dataset that mirrors the county panel structure as closely as possible through the ingest layer.

The current county analysis panel has `66276` rows, spans `2000` through `2020`, and includes `3156` county units across the state/DC scope represented in the local tract shapefiles. This matters because the tract branch should mirror that county-production scope rather than invent a different geographic universe.

The live waiver panel currently contains 21 observed `LOC_TYPE` values. The local geometry inventory needed for this work is already present under the Box-backed input root referenced by `0_inputs/input_root.txt`, including local tract zips, place zips, county-subdivision zips, AIANNH polygons, a New York City community-district shapefile zip, a Maine LMA file, and `philadelphia_divisions.md`. Massachusetts county subdivisions also carry `NECTAFP10` and `CNECTAFP10`, so the NECTA bridge can be built locally.

The current working machine still has one execution constraint that must be encoded in the commands: the shell-default `Rscript` is broken, while `/usr/local/bin/Rscript` works. The working R library now includes `sf`, `tigris`, `readxl`, and `tidycensus`. The Census API key now lives in `0_inputs/census_apikey.md`, so the tract ACS ingest script should read that file and register the key before it calls `tidycensus`.

---

## Data Artifact Flow

Raw Inputs  
- `0_inputs/input_root.txt`
- `2_processed_data/processed_root.txt`
- `0_inputs/census_apikey.md`
- External Box-backed raw root at `0_0_waivers/`
- External Box-backed raw root at `0_1_acs/`
- External Box-backed raw root at `0_4_prices/`
- External Box-backed raw root at `0_5_SNAP/0_5_2_Historical SNAP Retailer Locator Data-20231231.csv`
- External Box-backed raw root at `0_8_geographies/census_tracts/*.zip`
- External Box-backed raw root at `0_8_geographies/census_places/*.zip`
- External Box-backed raw root at `0_8_geographies/census_county_subdivisions/*.zip`
- External Box-backed raw root at `0_8_geographies/census_american_indian_areas/tl_2010_us_aiannh10.zip`
- External Box-backed raw root at `0_8_geographies/NY_Comm_District/nyc_community_districts_shapefile.zip`
- External Box-backed raw root at `0_8_geographies/maine_LMA/maine_labor_market_areas.geojson`
- Existing processed inputs `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
- Existing processed inputs `2_5_SNAP/2_5_0_snap_clean.rds`
- Existing processed inputs `2_1_acs/2_1_0_unemployment.rds`, `2_1_acs/2_1_3_Append_CountyDP03.rds`

Intermediate Artifacts  
- `2_0_waivers/2_0_6_waiver_geography_to_tract_crosswalk.rds`
- `2_0_waivers/2_0_7_waived_data_consolidated_long_tract.rds`
- `2_0_waivers/2_0_8_waiver_tract_match_diagnostics.rds`
- `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds`
- `2_5_SNAP/2_5_3_store_count_tract.rds`
- `2_5_SNAP/2_5_4_snap_tract_match_diagnostics.rds`
- `2_1_acs/2_1_5_acs_tract_2010_raw.rds`
- `2_1_acs/2_1_6_acs_tract_2010_covariates.rds`
- `2_1_acs/2_1_7_acs_tract_match_summary.rds`
- `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`
- `2_9_analysis/2_9_4_us_analysis_panel_tract.rds`
- `2_9_analysis/2_9_5_us_analysis_panel_tract_summary.rds`

Final Outputs  
- Tract waiver descriptive outputs under `3_outputs/3_1_descriptives/3_1_0_waivers/`, with `_tract` in the filename and title
- Tract retailer descriptive outputs under `3_outputs/3_1_descriptives/3_1_1_retailers/`, with `_tract` in the filename and title
- This ExecPlan file updated as execution proceeds

---

## Plan of Work

The implementation should proceed in four connected workstreams, but only the first three affect processed-data ingest and only the fourth produces user-facing outputs.

The first workstream adds tract treatment geography support under the waiver-ingest segment. Create `1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R` as a tract companion to the current county waiver logic. This script reads the live county-production waiver long file, normalizes tract-branch data issues such as `Gosnold`’s missing `STATE_ABBREV` and `Phiadelphia`, drops the explicitly ignored territory FIPS codes `60`, `66`, `69`, `72`, and `78`, constructs a unique geography table by `STATE_ABBREV`, `LOC_TYPE`, and `LOC`, and then expands each retained geography to tract identifiers. Use local tract shapefiles directly for `County`, `County/Town`, and `State`. Use county subdivisions for `Town`, `Township`, `Plantation`, `Unorganized`, Vermont `City`, Rhode Island `City`, and Rhode Island `Town`. Use places for non-VT/non-RI `City`, Pennsylvania `Boro` and `Borough`, and Pennsylvania `Other = Berwick`. Use AIANNH for `Reservation` and `Reservation Area`. Use the NYC community-district shapefile for `Community District` by parsing the borough and district number out of strings like `District 10, Manhattan` and matching them to `BoroCD`. Use the Maine LMA GeoJSON for `LMA`. Use `philadelphia_divisions.md` from the input root for `Metropolitan Division` and `OTHER`, both of which refer to the Philadelphia metropolitan division. Build `NECTA` from Massachusetts county subdivisions using `NECTAFP10` and `CNECTAFP10`; after identifying the member towns, assign tracts by the same majority-area rule used elsewhere. Treat `Island`, `Borough and Census Area`, and `Native Village Statistical Area` as intentional exclusions and write them to diagnostics rather than attempting a tract expansion. The script must write both a reusable tract crosswalk and a tract-expanded waiver long file.

The second workstream adds tract retailer outcomes under the covariate-ingest segment. Create `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R` as a tract companion to the current SNAP retailer ingest. This script reads the existing store-level SNAP clean file, converts the point coordinates to `sf` geometry, assigns every in-scope store to a 2010 tract polygon using point-in-polygon logic, and writes both a store-level tract-enriched file and a tract-year retailer count panel. The county chain logic does not change: preserve the existing chain labels and year-expansion logic, then aggregate to `tract_fips`, `county_fips`, `chain`, and `year`. The tract count file should remain sparse; the later tract panel builder will generate the complete tract-year grid and zero-fill missing outcome combinations.

The third workstream adds tract controls and tract analysis panels. Create `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R` to pull the 2010 ACS 5-year tract variables via `tidycensus`. This script must read the key from `0_inputs/census_apikey.md`, register it for the session without hardcoding it into script source, and then fetch the raw variables needed to build `meanInc`, `income`, `urate`, `population`, and `rent`. It must also keep the raw numerator and denominator fields that feed any derived control and record whether tract-level `DP03_0063E` is available for 2010. Then create `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R` to join tract treatment timing to tract retailer outcomes and save a complete tract panel before ACS controls are merged. This script must mirror the county panel structure as closely as possible, using `tract_fips` as the unit key, carrying `county_fips` as the 5-digit tract prefix, and zero-filling outcome counts on a complete tract-year grid for the state/DC scope represented in the current county analysis panel. Finally, create `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R` to merge tract ACS controls and county-level wages onto the pre-covariate tract panel, write the final tract analysis panel, and write a tract match summary artifact.

The fourth workstream adds tract descriptive scripts only. Do not add any tract reduced-form scripts. Place the tract waiver descriptive companions in `1_code/1_1_descriptives/1_1_0_waivers/` beside the county waiver descriptives, continuing the existing numbering with tract-specific stems such as `1_1_0_3_tract_conferral_growth_rural_share.R`, `1_1_0_4_ds_stock_trend_by_waiver_tract.R`, and `1_1_0_5_ever_waived_tract_map.R`. Place the tract retailer descriptive companions in `1_code/1_1_descriptives/1_1_1_retailers/` beside the county retailer descriptives, again continuing the existing numbering with tract-specific stems. Because output routing depends on the script folder, these placements will send tract waiver outputs to `3_outputs/3_1_descriptives/3_1_0_waivers/` and tract retailer outputs to `3_outputs/3_1_descriptives/3_1_1_retailers/`. Every tract output filename and every user-facing title or subtitle should include `_tract` so the tract artifacts can be singled out easily. Update or extend the descriptive shared helper files only where necessary so the tract scripts read the tract analysis artifacts and write non-destructive tract output paths. If an existing shared helper is edited, label the additions with short tract-specific comments so the change is obvious in the file.

Execution should be broken into the two user-requested tract ingest milestones before any downstream plotting work. Milestone 1 is the tract pre-covariate build: waiver-to-tract crosswalk, SNAP retailer-to-tract panel, and `2_9_3_us_analysis_panel_tract_pre_covariates.rds`, together with diagnostics proving that no in-scope waiver conferrals were dropped unexpectedly. Milestone 2 is the tract ACS pull and the covariate-complete tract panel, together with diagnostics proving a complete tract-level control match. Only after both milestones succeed should the tract descriptive scripts be added and run.

---

## Concrete Steps

All commands below should be run from the repository root:

    /Users/indermajumdar/Research/snap_dollar_entry

Always use `/usr/local/bin/Rscript` in this repository unless the environment has been repaired, because the shell-default `Rscript` currently fails on startup.

1. Inspect the tract-milestone targets before implementation so there is a clear fail-before-pass reference.

       root=$(tr -d "'" < 2_processed_data/processed_root.txt)
       test -f "$root/2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds"
       test -f "$root/2_9_analysis/2_9_4_us_analysis_panel_tract.rds"

   Expected behavior: both commands fail before the tract scripts are implemented.

2. After the tract ingest scripts are created, run Milestone 1.

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R
       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R
       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R

   Expected behavior: the tract crosswalk, waiver diagnostics, retailer tract diagnostics, and tract pre-covariate panel are written under the processed-data root. The diagnostics must enumerate tract-match results by `LOC_TYPE`.

3. Run Milestone 2.

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R
       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R

   Expected behavior: the ACS tract raw pull, tract covariate file, covariate match summary, final tract analysis panel, and tract panel summary are written under the processed-data root. The covariate summary should show complete non-missing coverage for the tract-level ACS controls and should document how county-level wages were merged.

4. Build one tract waiver descriptive output and one tract retailer descriptive output.

       /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_0_waivers/1_1_0_4_ds_stock_trend_by_waiver_tract.R
       /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_retailers/1_1_1_9_retailer_format_stock_index_tract.R

   Expected behavior: the tract outputs appear under `3_outputs/3_1_descriptives/3_1_0_waivers/` and `3_outputs/3_1_descriptives/3_1_1_retailers/` with `_tract` in the filenames and user-facing titles.

5. Verify the runner queue before a full-stage dry run once the tract ingest and descriptive scripts exist.

       /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage ingest --dry-run
       /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage descriptives --dry-run

   Expected behavior: the dry-run script lists include the new tract scripts in the desired numeric order within the segmented directories.

---

## Validation and Acceptance

Validation in this plan is behavioral. A tract implementation is not correct just because scripts exist; it is correct only if the tract artifacts are produced, waiver conferrals remain accounted for within the declared tract scope, the tract controls are complete, and the tract descriptive outputs land in the requested output folders.

**Validation Check 1: tract pre-covariate panel artifact exists and is larger than the county panel**

1. Command:

       /usr/local/bin/Rscript -e 'processed_root <- gsub("^[\"\\047]|[\"\\047]$", "", readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]); county <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds")); tract <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_3_us_analysis_panel_tract_pre_covariates.rds")); cat("county_rows:", nrow(county), "\n"); cat("tract_rows:", nrow(tract), "\n"); stopifnot(nrow(tract) > nrow(county))'

2. Expected behavior or output:
   The command fails before implementation because the tract file does not exist. After Milestone 1 it passes and prints both row counts, with tract rows exceeding county rows.

3. Why this is sufficient evidence:
   The command proves the tract pre-covariate panel was created and that it has the expected higher-resolution unit structure.

**Validation Check 2: no unexpected in-scope waiver conferrals were dropped during tract assignment**

1. Command:

       /usr/local/bin/Rscript -e 'processed_root <- gsub("^[\"\\047]|[\"\\047]$", "", readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]); diag <- readRDS(file.path(processed_root, "2_0_waivers", "2_0_8_waiver_tract_match_diagnostics.rds")); print(diag); stopifnot(sum(diag$unexpected_drop_n, na.rm = TRUE) == 0)'

2. Expected behavior or output:
   After Milestone 1 the diagnostics print a by-`LOC_TYPE` summary and the assertion passes with zero unexpected drops. Rows removed only because they fall in FIPS `60`, `66`, `69`, `72`, or `78`, or because they are one of the declared geography exclusions `Island`, `Borough and Census Area`, or `Native Village Statistical Area`, must appear only as explicit scope or exclusion rows in diagnostics.

3. Why this is sufficient evidence:
   The user’s central tract requirement is that waiver conferrals not be silently lost. This diagnostic makes the tract-expansion accounting observable by geography type.

**Validation Check 3: tract covariate merge is complete**

1. Command:

       /usr/local/bin/Rscript -e 'processed_root <- gsub("^[\"\\047]|[\"\\047]$", "", readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]); x <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_4_us_analysis_panel_tract.rds")); vars <- c("meanInc", "income", "urate", "population", "rent", "wage"); print(colSums(is.na(x[vars]))); stopifnot(all(colSums(is.na(x[vars])) == 0))'

2. Expected behavior or output:
   The command fails before Milestone 2 because the final tract panel does not exist. After Milestone 2 it passes and prints zero missing values for the listed controls.

3. Why this is sufficient evidence:
   The tract descriptive scripts depend on these controls and on the fully built tract panel. A complete non-missing merge proves the tract ingest branch is analytically usable.

**Validation Check 4: tract descriptive outputs land in the requested existing output folders**

1. Command:

       test -f 3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_4_ds_stock_trend_by_waiver_tract.jpeg -o -f 3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_4_ds_stock_trend_by_waiver_tract_v01.jpeg
       test -f 3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_9_retailer_format_stock_index_tract.jpeg -o -f 3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_9_retailer_format_stock_index_tract_v01.jpeg

2. Expected behavior or output:
   Before implementation the tests fail. After the representative tract descriptive scripts run, the tests pass.

3. Why this is sufficient evidence:
   This verifies that the tract processed artifacts flow successfully into the tract descriptive layer and that the tract outputs are being written into the existing descriptive output folders as requested.

---

## Idempotence and Recovery

The plan should be implemented additively. New tract scripts write new processed artifacts and new tract descriptive output stems; they do not rewrite or rename the current county artifacts. This makes the tract branch inherently safer than a shared refactor.

The tract crosswalk and diagnostics steps should be written so that rerunning them regenerates the same processed `.rds` artifacts from the same inputs. If a rerun would overwrite an existing tract descriptive artifact, the implementation should version the output file rather than overwrite it silently.

If the tract geometry matching fails for a subset of location types, do not patch around the issue manually in downstream scripts. Instead, stop at the tract diagnostics stage, update this ExecPlan’s `Surprises & Discoveries` and `Decision Log`, and repair the relevant geometry rule in the upstream tract crosswalk script.

If `tidycensus` is installed but the Census API configuration is not usable during execution, do not fall back to a different covariate source. Pause Milestone 2, document the missing configuration in this ExecPlan, and resume only after the required access is available.

---

## Artifacts and Notes

Important baseline evidence gathered while planning:

    Live county analysis panel rows: 66276
    Live county analysis panel counties: 3156
    Live county analysis panel year range: 2000 2020

    Live waiver panel rows: 103627
    Live `_selected` waiver panel rows: 106759

    SNAP clean rows: 830340
    Missing Latitude: 0
    Missing Longitude: 0

    Installed R packages in working `/usr/local/bin/Rscript` environment:
    sf: TRUE
    tigris: TRUE
    readxl: TRUE
    tidycensus: TRUE

    Explicitly ignored state FIPS in the tract branch:
    60 66 69 72 78

    Census API key file used for tract ACS pulls:
    0_inputs/census_apikey.md

These snippets should remain short. As execution proceeds, add only the transcripts or summaries that materially prove success or explain a design change.

---

## Data Contracts, Inputs, and Dependencies

This plan relies on concrete data contracts rather than abstract module boundaries.

The script `1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R` must use `sf` and base/tidyverse string-handling tools to read the live waiver long file plus the local geometry inventory. Its required inputs are `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`, the local geometry files under `0_8_geographies/`, and the repository pointer files that locate the external data roots. It must write `2_0_6_waiver_geography_to_tract_crosswalk.rds`, `2_0_7_waived_data_consolidated_long_tract.rds`, and `2_0_8_waiver_tract_match_diagnostics.rds`. Its key invariants are: every retained in-scope waiver geography expands to at least one tract, every tract identifier is an 11-digit character string, every county identifier carried alongside it is a 5-digit character string, and every exclusion, scope removal, or fallback assignment is visible in diagnostics.

The script `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R` must use `sf` to assign the store-level SNAP rows to tracts from their existing point coordinates. Its required inputs are `2_5_SNAP/2_5_0_snap_clean.rds`, the local tract shapefiles, and the existing chain labels already carried in the SNAP clean file. It must write `2_5_2_snap_clean_with_tracts.rds`, `2_5_3_store_count_tract.rds`, and `2_5_4_snap_tract_match_diagnostics.rds`. Its invariants are: each in-scope store row has one tract assignment, `tract_fips` implies the same `county_fips` prefix carried in the output, and the year-expansion logic stays identical to the county retailer pipeline.

The script `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R` must use `tidycensus` for the 2010 ACS 5-year tract pull and should not substitute another source. Its required inputs are the local Census API key file `0_inputs/census_apikey.md`, the list of tract-analysis-scope states, and the exact variable definitions in this ExecPlan: `B20003_001E`, `B20003_002E`, `B20002_001E`, `B23025_005E`, `B23025_003E`, `B11001_001E`, `B25062_001E`, and `B25061_001E`, plus tract-level `DP03_0063E` availability if present. It must write `2_1_5_acs_tract_2010_raw.rds`, `2_1_6_acs_tract_2010_covariates.rds`, and `2_1_7_acs_tract_match_summary.rds`. Its invariants are: one row per tract-year in the tract control file, zero-padded tract identifiers, derived controls computed exactly as specified, the local API key is read without hardcoding it into script source, and raw numerator/denominator fields are preserved.

The script `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R` must read the tract waiver long file and the tract retailer count file and write `2_9_3_us_analysis_panel_tract_pre_covariates.rds`. Its inputs are `2_0_7_waived_data_consolidated_long_tract.rds`, `2_5_3_store_count_tract.rds`, the tract-analysis-scope state list implied by this ExecPlan, and the same year grid used by the county analysis panel. Its invariants are: one row per `tract_fips`-`year`, zero-filled outcomes on the complete tract-year grid, tract treatment timing constructed analogously to the county panel, and retained `county_fips` for downstream wage merges and descriptive splits.

The script `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R` must read the pre-covariate tract panel, tract ACS covariates, county wage input, and any county-level parity inputs that remain necessary, then write `2_9_4_us_analysis_panel_tract.rds` and `2_9_5_us_analysis_panel_tract_summary.rds`. Its invariants are: one row per tract-year, complete non-missing tract ACS controls, county wage merged by the tract’s county prefix and year, and summary metrics that make it easy to compare the tract panel against the existing county panel.

The descriptive helper changes in `1_code/1_1_descriptives/1_1_0_waivers/shared_us_analysis_helpers.R` and `1_code/1_1_descriptives/1_1_1_retailers/shared_us_analysis_helpers.R` should remain minimal. If helper code is changed, the contract should stay artifact-driven: helper functions must load the tract processed artifacts, use tract-safe identifiers, write tract outputs into the existing waiver and retailer descriptive output folders, and preserve `_tract` in filenames and titles without breaking the existing county helper behavior.

If a dependency affects results, the reason for the choice must be documented in code comments and in this ExecPlan. `sf` is chosen for geometry intersections because the tract-assignment rules depend on polygon area shares and point-in-polygon checks. `tidycensus` is chosen because the user explicitly requested tract-level ACS 5-year pulls for 2010. `EPSG:5070` is chosen because overlap shares should be measured in a U.S. equal-area projection.

---

## Completion Checklist

Before marking the ExecPlan **Complete**, verify:

- [ ] All planned tract ingest scripts have been implemented and run
- [x] Tract waiver diagnostics show zero unexpected in-scope conferral drops
- [x] Tract retailer diagnostics show successful tract assignment for all in-scope SNAP retailer rows
- [x] Milestone 1 tract waiver, retailer, and pre-covariate artifacts were rebuilt successfully after the state-first retailer refinement
- [x] Milestone 1 rerun reduced retailer out-of-scope rows to the explicitly ignored territory rows only
- [ ] Tract ACS covariate pull and merge completed with zero missing values in the tract control set
- [ ] `2_9_3_us_analysis_panel_tract_pre_covariates.rds` and `2_9_4_us_analysis_panel_tract.rds` exist
- [ ] At least one tract waiver descriptive output and one tract retailer descriptive output exist in `3_outputs/3_1_descriptives/3_1_0_waivers/` and `3_outputs/3_1_descriptives/3_1_1_retailers/`, each clearly marked with `_tract`
- [ ] County scripts and county outputs remain intact
- [ ] `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` reflect the final state
- [ ] ExecPlan Status updated to **Complete**

---

## Change Notes

- 2026-03-19: Initial tract ExecPlan written from the waiver-geographies context memo, the current county pipeline, the local geometry inventory, and the working machine environment.
- 2026-03-19: ExecPlan revised to match the segmented ingest layout, to treat FIPS `60`, `66`, `69`, `72`, and `78` as explicitly ignored scope exclusions, to record `Gosnold` as Massachusetts, to remove tract reduced-form work from scope, and to reflect that `tidycensus` is installed.
- 2026-03-20: ExecPlan revised again so the tract ACS ingest reads the local Census API key file, tract descriptives write into the existing waiver and retailer descriptive output folders, tract filenames and titles use `_tract`, and the Philadelphia metropolitan-division county list is read from `philadelphia_divisions.md` in the input root.
- 2026-03-20: Milestone 1 was rerun with a state-first retailer tract matcher. The rerun kept the waiver results intact, reduced retailer out-of-scope rows to the explicitly ignored territories only, and rebuilt `2_5_2`, `2_5_3`, `2_5_4`, and `2_9_3`.
