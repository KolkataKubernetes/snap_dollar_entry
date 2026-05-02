# Preserve waiver scope in the county waiver pipeline

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

## ExecPlan Status

Status: Complete  
Owner: Inder Majumdar + Codex  
Created: 2026-05-02  
Last Updated: 2026-05-02  
Related Project: `snap_dollar_entry` waiver ingest and county analysis-panel scope tracking

## Revision History

| Date | Change | Author |
| --- | --- | --- |
| 2026-05-02 | Initial planning draft created after auditing the raw waiver workbooks, the standardized waiver long files, the tract waiver expansion, and the county analysis-panel builder | Codex |
| 2026-05-02 | Executed the waiver-scope patch in the standardized waiver long file and county analysis-panel builder, then reran both scripts and validated the refreshed processed artifacts | Codex |

## Quick Summary

### Goal

Preserve whether a county-year treatment comes from a statewide waiver or from a substate waiver as the waiver data move from raw workbooks into the county analysis panel. This matters because the current county panel keeps only a generic treatment flag, which prevents annual state summaries or descriptive figures from distinguishing statewide coverage from partial coverage.

### Deliverable

The deliverable is a narrow ingest-and-panel patch that adds a new `waiver_scope` field to the county-oriented waiver pipeline and carries it into `2_9_analysis/2_9_0_us_analysis_panel.rds`. After the change, any county-year row in the county panel can be classified as `statewide`, `substate`, or `none` without returning to the raw waiver files.

### Success Criteria

- The standardized county-oriented waiver long file preserves a new `waiver_scope` column derived from the raw statewide flag.
- The county analysis panel contains `waiver_scope` for every county-year row.
- Untreated county-years are labeled `none`.
- Treated county-years that originated from statewide waivers are labeled `statewide`.
- Treated county-years that originated from direct county-coded waivers are labeled `substate`.
- The county analysis panel row count and county-year key remain unchanged from the pre-patch build.

### Key Files

- `1_code/1_0_ingest/1_0_0_waivers/1_0_0_0_SNAP_waiver_ingest.R`
- `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R`
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R`
- `1_code/1_0_ingest/1_0_2_build_panel/shared_ingest_helpers.R`
- `2_processed_data/processed_root.txt`
- `agent-docs/execplans/2026-05-02-waiver-scope-county-panel-execplan.md`

## Purpose / Big Picture

After this change, a contributor will be able to use the county analysis panel itself to tell whether a treated county-year inherited treatment from a statewide ABAWD waiver or from a waiver that was already county-coded in the source files. Right now that distinction exists in the raw workbooks and in the early waiver artifacts, but it becomes unrecoverable in the county panel because statewide rows are converted into county rows and then the statewide flag is dropped.

This plan is intentionally narrow. It does not redesign waiver geography standardization, does not add new county mappings for towns, reservations, or other sub-county geographies, and does not change the treatment definition itself. It only preserves origin information that already exists in the raw data for the subset of waiver rows that currently enter the county analysis panel.

The phrase “waiver scope” in this plan means the source breadth of a county-year treatment after county standardization. `statewide` means the county-year comes from a raw waiver row where the state was waived in full. `substate` means the county-year comes from a raw waiver row that was already county-coded and matched to a county FIPS code. `none` means the county-year is untreated in the county panel. These labels are operational data values, not abstract categories.

## Progress

- [x] (2026-05-02 13:35 America/Chicago) Audited the raw workbook schema and confirmed that the source Excel files already contain `ENTIRE_STATE` and `LOC_TYPE`.
- [x] (2026-05-02 13:40 America/Chicago) Audited `2_0_0_waiver_data_consolidated_generated.rds` and `2_0_4_waived_data_consolidated_long.rds` and confirmed that `ENTIRE_STATE` is preserved through the standardized waiver long file.
- [x] (2026-05-02 13:45 America/Chicago) Audited the county analysis-panel builder and confirmed that statewide rows are first rewritten to county rows and then `ENTIRE_STATE` is dropped before the county panel is saved.
- [x] (2026-05-02 13:49 America/Chicago) Drafted this ExecPlan.
- [x] (2026-05-02 14:05 America/Chicago) Implemented `waiver_scope` in `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R` for statewide, county-coded, and other non-statewide waiver rows.
- [x] (2026-05-02 14:10 America/Chicago) Updated `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` to carry `waiver_scope` into the county panel, fill untreated rows with `none`, and collapse overlapping scope rows with statewide precedence.
- [x] (2026-05-02 14:18 America/Chicago) Reran the standardized waiver ingest and county analysis-panel builder against the Box-backed processed-data directory.
- [x] (2026-05-02 14:23 America/Chicago) Validated that the refreshed long waiver file and county panel contain the intended `waiver_scope` values and that county-year uniqueness and row count remain unchanged at 62,380 rows.

## Surprises & Discoveries

- Observation: The raw waiver workbooks already contain the needed statewide indicator, so no inference logic is required at ingest.
  Evidence: The `2013_ABAWD_waiver.xlsx` workbook includes `ENTIRE_STATE` and `LOC_TYPE`, with statewide examples showing `ENTIRE_STATE = 1` and `LOC_TYPE = "State"`.

- Observation: The first raw-to-wide ingest does not create the statewide flag; it simply preserves it.
  Evidence: `1_code/1_0_ingest/1_0_0_waivers/1_0_0_0_SNAP_waiver_ingest.R` row-binds the Excel workbooks with `map(readxl::read_excel) |> bind_rows()` and writes `2_0_0_waiver_data_consolidated_generated.rds`.

- Observation: The county-standardization step converts statewide rows into county rows by overwriting `LOC_TYPE`, which means `ENTIRE_STATE` becomes the only surviving signal of statewide origin at that stage.
  Evidence: `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R` filters `ENTIRE_STATE == 1`, joins all counties in the state, and mutates `LOC_TYPE = "County"` before recombining.

- Observation: The county analysis panel drops `ENTIRE_STATE`, which is the precise point where statewide origin becomes unrecoverable in the county branch.
  Evidence: `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` keeps only `county_fips`, `year`, `countyname = LOC`, `type = LOC_TYPE`, and `treatment = 1L` in `waiver_treatment`.

- Observation: This plan can preserve statewide versus direct county-coded treatment, but it does not repair county coverage for waiver rows that never receive a county FIPS code.
  Evidence: In `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R`, non-county and non-statewide rows are sent to `other_rows` with `FIPS = NA_character_`, so they do not enter the county panel today.

- Observation: Some county-years appear in both statewide-origin and county-origin waiver rows, so naïvely carrying `waiver_scope` into the county panel would duplicate county-year rows.
  Evidence: A direct audit of `2_0_4_waived_data_consolidated_long.rds` found 65 overlapping county-year keys with both `statewide` and `substate` origin labels, concentrated in California in 2018.

## Decision Log

- Decision: Use a single string field named `waiver_scope` with values `statewide`, `substate`, and `none`.
  Rationale: These values are short, explicit, and sufficient for county descriptive work. They avoid overloading the existing `type` field and avoid `NA` for untreated rows, which simplifies downstream counting and plotting.
  Date/Author: 2026-05-02 / Codex

- Decision: Derive `waiver_scope` in `1_0_0_1_waiver_ingest.R`, not later in the county panel builder.
  Rationale: The standardized waiver long file is the last county-oriented artifact that still knows whether a county row came from a statewide source row. Deriving the field there makes the logic explicit and reusable.
  Date/Author: 2026-05-02 / Codex

- Decision: Keep this plan narrow and do not extend county FIPS assignment to towns, reservations, boroughs, or other non-county waiver geographies.
  Rationale: That would be a broader redesign of waiver geography standardization and would change substantive county treatment coverage. The current request is only to preserve source scope for county rows that already enter the panel.
  Date/Author: 2026-05-02 / Codex

- Decision: Preserve the existing `type` field in the county panel even after adding `waiver_scope`.
  Rationale: `type` is already used in event-timing logic and other scripts. The new field should be additive, not a replacement.
  Date/Author: 2026-05-02 / Codex

- Decision: When a county-year has both statewide-origin and county-origin waiver rows, collapse it to one county-year row with `waiver_scope = "statewide"`.
  Rationale: The county panel must remain one row per county-year. In these overlaps, the county is covered by a statewide waiver, so `statewide` is the least lossy single-label summary within the requested three-value design.
  Date/Author: 2026-05-02 / Codex

## Outcomes & Retrospective

The implementation succeeded and the primary purpose was met. The standardized waiver long file now carries `waiver_scope`, and the county analysis panel now carries `waiver_scope` with only `none`, `statewide`, and `substate`.

The post-run validation counts were:

- `2_0_4_waived_data_consolidated_long.rds`: `statewide = 46,643`, `substate = 56,984`.
- `2_9_analysis/2_9_0_us_analysis_panel.rds`: `none = 51,603`, `statewide = 7,219`, `substate = 3,558`.
- County panel structural check: `62,380` rows and `62,380` unique `county_fips, year` keys.

The remaining limitation is conceptual rather than technical. `substate` still means county-coded waiver rows that survive the current county standardization path. It does not mean every non-statewide waiver geography in the raw workbooks, because many non-county geographies still never receive county FIPS codes in this branch.

## Context and Orientation

The waiver pipeline currently moves through three relevant county-oriented stages.

First, `1_code/1_0_ingest/1_0_0_waivers/1_0_0_0_SNAP_waiver_ingest.R` reads the raw annual Excel workbooks from `0_0_waivers/0_0_1_ABAWD_panels` and saves a combined wide artifact at `2_0_waivers/2_0_0_waiver_data_consolidated_generated.rds`. This stage preserves the raw columns, including `ENTIRE_STATE`.

Second, `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R` expands the wide artifact into a monthly long artifact and standardizes geography. In that script, statewide waiver rows are expanded to one county row per county in the state. This is where the raw statewide flag still exists, but the geography label is rewritten from `State` to `County`. The output is `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`.

Third, `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` reads the standardized long waiver artifact, filters to rows with county FIPS codes, and builds the final county analysis panel at `2_9_analysis/2_9_0_us_analysis_panel.rds`. At this stage the builder currently keeps only a generic treatment indicator and the rewritten `type = LOC_TYPE`, which means statewide origin is lost.

The exact loss mechanism is important. In `1_0_0_1_waiver_ingest.R`, the statewide rows become county rows and still carry `ENTIRE_STATE = 1`. In `1_0_2_0_build_analysis_panel.R`, `ENTIRE_STATE` is not included in `waiver_treatment`, so the county panel cannot distinguish whether `type = "County"` came from a truly county-coded waiver or from a statewide waiver expanded to all counties.

This plan does not touch the tract branch. The tract files preserve more geography detail and have their own collapse logic, but the requested deliverable is a `waiver_scope` field in the county panel.

## Plan of Work

Add `waiver_scope` in `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R` at the point where the script creates `state_rows`, `county_rows`, and `other_rows`. The field should be defined before those objects are recombined.

For `state_rows`, assign `waiver_scope = "statewide"` before or during the county expansion. These rows originate from raw rows with `ENTIRE_STATE == 1`, even though the script later overwrites `LOC_TYPE` to `County`.

For `county_rows`, assign `waiver_scope = "substate"`. These are the rows that were already `LOC_TYPE == "County"` in the standardized monthly long data and that match directly to county FIPS codes.

For `other_rows`, assign `waiver_scope = "substate"` as well, because they are not statewide waivers. Even though these rows continue to lack county FIPS and therefore do not enter the county panel, keeping the classification consistent in the long artifact avoids future ambiguity if later work uses that file directly.

After recombining the standardized long file, preserve `waiver_scope` as a saved column in `2_0_4_waived_data_consolidated_long.rds`. No existing columns should be renamed or removed.

Then update `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` so `waiver_treatment` includes `waiver_scope` alongside the current fields. The county analysis panel should carry `waiver_scope` through the `right_join()` onto the county-year grid.

Because county-years without treatment are manufactured by joining the waiver rows onto the full county-year grid, set `waiver_scope = "none"` immediately after the join for rows where the incoming value is missing. This should happen in the same block where `treatment = coalesce(treatment, 0L)` is assigned.

Do not change the `treated`, `eventYear1`, `eventYear2`, `tau1`, or `tau2` logic in this plan. `waiver_scope` is descriptive metadata, not a new treatment definition.

Do not change the current county-year row universe, the county-year key, the reduced-form sampling rules, or the output file names. The patch should be additive.

If a helper or descriptive script later needs `waiver_scope`, it should be able to read it directly from `ctx$analysis_panel` or the saved county panel without any further changes to the ingest design. Those downstream uses are outside this plan unless a script fails because it assumes a fixed column order or explicitly subsets columns.

## Concrete Steps

All commands below should be run from `/Users/indermajumdar/Research/snap_dollar_entry`.

Implement the ingest and county-panel edits, then run:

    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R
    /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R

After those scripts succeed, inspect the resulting artifacts with:

    /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]); processed_root <- substring(processed_root, 2, nchar(processed_root) - 1); long <- readRDS(file.path(processed_root, "2_0_waivers", "2_0_4_waived_data_consolidated_long.rds")); panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds")); cat("long waiver_scope values\\n"); print(table(long$waiver_scope, useNA = "ifany")); cat("\\npanel waiver_scope values\\n"); print(table(panel$waiver_scope, useNA = "ifany"));'

The expected qualitative transcript is:

    The long waiver file prints at least `statewide` and `substate`.
    The county panel prints all three values: `statewide`, `substate`, and `none`.
    No `NA` values appear in `panel$waiver_scope`.

Then verify county-panel key stability with:

    /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]); processed_root <- substring(processed_root, 2, nchar(processed_root) - 1); panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds")); cat("rows:", nrow(panel), "\\n"); cat("unique county-year rows:", nrow(unique(panel[c("county_fips","year")])), "\\n");'

The expected qualitative transcript is:

    The total row count equals the number of unique `county_fips, year` pairs.
    The row count matches the pre-patch county analysis panel row count.

Observed execution result:

    `1_0_0_1_waiver_ingest.R` reran successfully after escalation to write into the Box-backed processed-data directory.
    `1_0_2_0_build_analysis_panel.R` reran successfully and printed:
      rows             62380
      treated_counties  2543
      min_year          2000
      max_year          2019

## Validation and Acceptance

Validation must cover both data meaning and structural stability.

First, verify that `2_0_4_waived_data_consolidated_long.rds` contains `waiver_scope` and that rows with `ENTIRE_STATE == 1` are labeled `statewide`. This directly checks that the new field is created where the statewide signal still exists.

Second, verify that `2_9_analysis/2_9_0_us_analysis_panel.rds` contains `waiver_scope` with no missing values, and that untreated rows are labeled `none`. This directly checks the primary deliverable.

Third, verify that the county panel still has one row per county-year and that the total row count is unchanged from the pre-patch build. This ensures the patch does not silently alter panel scope.

Acceptance is met only when all three checks pass.

## Completion Checklist

- [x] `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R` assigns and saves `waiver_scope`.
- [x] `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R` carries `waiver_scope` into the county panel and fills untreated rows with `none`.
- [x] `2_0_4_waived_data_consolidated_long.rds` contains `waiver_scope` with `statewide` on statewide-origin rows.
- [x] `2_9_analysis/2_9_0_us_analysis_panel.rds` contains `waiver_scope` with values only in `{statewide, substate, none}`.
- [x] County-panel row count and county-year uniqueness are unchanged.
- [x] `Progress`, `Decision Log`, and `Outcomes & Retrospective` are updated to reflect the final implementation state.

## Idempotence and Recovery

This patch is safe to rerun. The two touched scripts overwrite their existing processed `.rds` outputs with the same file names, so re-execution should deterministically refresh the waiver long artifact and the county analysis panel.

If validation fails after implementation, the safe recovery path is to inspect the saved long waiver artifact first. If `waiver_scope` is already wrong there, fix `1_0_0_1_waiver_ingest.R` and rerun both scripts. If the long artifact is correct but the county panel is wrong, fix only `1_0_2_0_build_analysis_panel.R` and rerun the county builder.

Because this plan is additive and does not change output file names, rollback is straightforward: revert the code edits and rerun the same two scripts to restore the prior schema.

## Artifacts and Notes

The most important planning evidence for this change is the audited loss point in the county builder and the preservation of `ENTIRE_STATE` upstream.

Relevant snippets:

    In `1_0_0_1_waiver_ingest.R`, statewide rows are expanded to counties and `LOC_TYPE` is changed to `County`.

    In `1_0_2_0_build_analysis_panel.R`, `waiver_treatment` currently keeps:
      county_fips,
      year,
      countyname = LOC,
      type = LOC_TYPE,
      treatment = 1L

    Therefore `ENTIRE_STATE` is not available in the saved county panel today.

Plan change note: This file was created to specify a narrow additive ingest change after confirming that the raw waiver workbooks already preserve statewide scope and that the county panel loses it only because that scope is not carried forward.

Plan change note: This file was updated after execution to record the statewide-overlap discovery, the statewide-precedence collapse rule, the rerun commands, and the final validation counts for the refreshed processed artifacts.
