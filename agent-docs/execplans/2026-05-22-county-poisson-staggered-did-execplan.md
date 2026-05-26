# Build a county-level staggered Poisson DID branch for the reduced-form analysis

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

## ExecPlan Status

Status: Planning  
Owner: Inder Majumdar + Codex  
Created: 2026-05-22  
Last Updated: 2026-05-22  
Related Project: `snap_dollar_entry` county reduced-form pipeline

Optional Metadata:  
Priority: High  
Estimated Effort: Multi-day  
Dependencies: `NonlinearDiD` 0.2.0, benchmark county analysis panel in `2_9_analysis`, versioned `3_outputs/` write paths

## Revision History

- 2026-05-22: Initial ExecPlan drafted after auditing the county benchmark reduced-form scripts, the empty `1_2_0_1b_poissonregs` folder, the saved county event-study sample, and the installed `NonlinearDiD` package behavior. Author: Codex.

## Quick Summary

**Goal**

Build a new county-level reduced-form branch that replaces the current inverse-hyperbolic-sine Sun-Abraham event studies with a Poisson difference-in-differences design that respects staggered adoption and the fact that the outlet outcomes are non-negative counts. The branch matters only if it reproduces the county benchmark scope while using a count-data estimand rather than an OLS-style transformed-outcome regression.

**Deliverable**

A new script family under `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs` that builds a Poisson-ready county sample, estimates group-time staggered Poisson DID effects for the benchmark county outcomes, and writes versioned plots, tables, and CSV summaries under the mirrored `3_outputs` subdirectories.

**Success Criteria**

- Running the new Poisson sample builder writes a branch-specific county sample that preserves the benchmark treated universe and covariates but includes the extra pre-period needed for cohort-2014 comparisons.
- Running the Poisson outcome scripts produces versioned county-level event-study artifacts for the benchmark outlet outcomes without changing the existing Sun-Abraham branch.
- The implementation does not call `nonlinear_attgt(..., data_type = "panel", outcome_model = "poisson")` as if it were a valid Poisson panel estimator in the installed package version.
- The exported group-time and aggregated results make the control-group definition explicit: benchmark mirror uses not-yet-treated counties, not never-treated counties.

**Key Files**

- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/shared_reduced_form_helpers.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_1_event_study_total_ds.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_9_event_study_all_table.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_11_event_study_all_table_image.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/`
- `2_processed_data/processed_root.txt`
- `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_1b_poissonregs/`
- `3_outputs/3_0_tables/3_2_0_county/3_2_0_1b_poissonregs/`

## Purpose / Big Picture

After this change, a contributor should be able to run a county-level reduced-form branch that answers the same substantive question as the current benchmark branch, but does so with a Poisson DID design that is built for non-negative count outcomes and staggered treatment timing. The user-visible result is a parallel set of county reduced-form outputs that can be compared directly against the existing Sun-Abraham inverse-hyperbolic-sine outputs.

This plan is intentionally not a “swap one function call” plan. The installed `NonlinearDiD` package does contain staggered DID helpers and a two-period Poisson DID helper, but the package behavior observed locally means the direct panel-data staggered entry point cannot be treated as a valid Poisson replacement for the county benchmark. The plan therefore uses the package where it is behaviorally aligned with the requested estimand and avoids the parts that are not.

## Progress

- [x] (2026-05-22 14:08 America/Chicago) Audited `agent-docs/PLANS.md`.
- [x] (2026-05-22 14:12 America/Chicago) Audited the county reduced-form benchmark scripts and confirmed the new Poisson folder `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs` is empty.
- [x] (2026-05-22 14:18 America/Chicago) Confirmed the benchmark county helper uses `feols()` with `sunab(eventYear2, year, ref.p = 0)`, county and year fixed effects, county clustering, and the controls `population + wage + meanInc + rent + urate`.
- [x] (2026-05-22 14:24 America/Chicago) Confirmed the saved benchmark event-study sample `2_9_2_event_study_sample.rds` contains only ever-treated counties, years 2014 through 2019, and no never-treated benchmark controls.
- [x] (2026-05-22 14:40 America/Chicago) Confirmed the installed `NonlinearDiD` package exposes `nonlinear_attgt()`, `nonlinear_aggte()`, `nonlinear_pretest()`, and `count_did_poisson()`.
- [x] (2026-05-22 14:51 America/Chicago) Verified on simulated panel data that `nonlinear_attgt(..., data_type = "panel", outcome_model = "poisson")` returns the same `ATT(g,t)` values as `outcome_model = "linear"` in the installed package version.
- [x] (2026-05-22 15:02 America/Chicago) Drafted this ExecPlan.
- [ ] Build the branch-specific Poisson sample and helper layer.
- [ ] Implement the benchmark outcome scripts, combined table, and image-table exporters.
- [ ] Validate artifact creation and the estimator-path guardrails described below.

## Surprises & Discoveries

- Observation: The current benchmark county sample contains only ever-treated counties, so the benchmark control group is “not yet treated” rather than “never treated.”
  Evidence: The saved sample `2_9_2_event_study_sample.rds` has `11998` rows, `2010` unique counties, years `2014:2019`, and `treated_group == TRUE` for every row inspected locally on 2026-05-22.

- Observation: The direct staggered panel entry point in the installed `NonlinearDiD` package cannot currently be treated as a Poisson panel estimator.
  Evidence: On 2026-05-22, a local simulation using `sim_count_panel()` showed that `nonlinear_attgt(..., data_type = "panel", outcome_model = "poisson")` and `nonlinear_attgt(..., data_type = "panel", outcome_model = "linear")` returned exactly identical `attgt$att` values, with `all.equal(...) == TRUE` and `max abs diff == 0`.

- Observation: The package’s two-period count helper is usable for point estimation but not sufficient by itself for the benchmark county branch.
  Evidence: `count_did_poisson()` accepts a two-period comparison and returns a log rate ratio, rate ratio, and average partial effect, but it does not itself create staggered `ATT(g,t)` objects across cohorts and times.

- Observation: The earliest treated cohort needs one earlier year than the benchmark saved event-study sample if the implementation is going to estimate cohort-time DID cells with a “baseline period” of `g - 1`.
  Evidence: The benchmark sample starts in 2014, but the treatment cohorts in the analysis panel include 2014. A group-time DID cell for cohort `g = 2014` requires 2013 as the base period.

- Observation: The empty `1_2_0_1b_poissonregs` folder already gives the new branch a clean boundary.
  Evidence: The directory exists but contains no files as of 2026-05-22, so the Poisson branch can be added without editing the current Sun-Abraham script family in place.

## Decision Log

- Decision: Mirror the benchmark county design with not-yet-treated controls in the first Poisson branch.
  Rationale: The current benchmark county sample excludes never-treated counties entirely, so not-yet-treated controls are the closest staggered-control analogue to the benchmark branch.
  Date/Author: 2026-05-22 / Codex

- Decision: Do not implement the county Poisson branch by directly calling `nonlinear_attgt(..., data_type = "panel", outcome_model = "poisson")`.
  Rationale: Local verification showed that, in the installed package version, the panel-data Poisson path does not produce behavior distinct from the linear panel path, so using it would misstate the estimator actually being run.
  Date/Author: 2026-05-22 / Codex

- Decision: Use the package’s two-period Poisson DID capability as the core estimator and build staggered group-time aggregation around it locally.
  Rationale: This remains within the package’s count-DID capability while avoiding the misleading panel shortcut and preserving the staggered-adoption design structure.
  Date/Author: 2026-05-22 / Codex

- Decision: Keep the first Poisson branch scoped to the main benchmark county outcome family and defer heterogeneity and isolated sensitivity branches.
  Rationale: The primary risk is estimator correctness. Replicating the core eight-outcome county branch first is the smallest meaningful deliverable.
  Date/Author: 2026-05-22 / Codex

- Decision: Build the Poisson sample from `2_9_0_us_analysis_panel.rds`, not from the already-saved `2_9_2_event_study_sample.rds`.
  Rationale: The saved benchmark event-study sample starts too late for cohort-2014 base-period comparisons. Rebuilding from the analysis panel allows the Poisson branch to include 2013 while preserving the benchmark treated-universe logic.
  Date/Author: 2026-05-22 / Codex

- Decision: Export both count-scale and multiplicative summaries, with the count-scale event-study profile treated as the default presentation artifact unless the user later requests otherwise.
  Rationale: The user’s stated concern is the count nature of the outcome and the bound at zero. Count-scale average partial effects are easier to compare against the existing reduced-form figures, while multiplicative rate ratios remain available for interpretation and robustness.
  Date/Author: 2026-05-22 / Codex

## Outcomes & Retrospective

The planning objective is complete. This document now gives a future executor a county-level Poisson DID path that is consistent with the current repository layout and explicit about the installed package’s limitations.

The most important lesson from the audit is that “use NonlinearDiD” is not a sufficient specification. The repository’s benchmark sample design and the installed package’s actual behavior must both be respected, otherwise the new branch would look nonlinear while silently remaining linear.

## Context and Orientation

The current county reduced-form benchmark lives under `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs`. Its central helper `shared_reduced_form_helpers.R` loads `2_9_analysis/2_9_2_event_study_sample.rds`, runs a Sun-Abraham event study with `fixest::feols()`, clusters at `county_fips`, and writes versioned PDF and LaTeX outputs under mirrored `3_outputs` directories. Thin wrapper scripts call that helper once per outcome.

The benchmark sample builder `1_2_0_build_event_study_sample.R` rebuilds the event-study sample from `2_9_analysis/2_9_0_us_analysis_panel.rds`. It rescales `rent` and `meanInc` by `1000`, restricts to years `2014:2019`, replaces missing timing values with sentinels, and then keeps only counties and states that ever enter the treated universe. In the inspected saved sample, this logic leaves only ever-treated counties. That means the benchmark’s identifying comparison is between earlier-treated and later-treated counties, not between treated and never-treated counties.

Three terms matter for this plan.

“Cohort” means the first year a county is treated. In the current county branch, that year is stored as `eventYear2`.

“Group-time ATT” means the treatment effect for one treated cohort `g` evaluated at one calendar time `t`. In staggered DID notation, this is `ATT(g,t)`.

“Not-yet-treated controls” means counties that will eventually be treated, but whose first treatment year is strictly later than the current calendar time `t`. This is the benchmark-like control group because the current county sample excludes never-treated counties.

The installed `NonlinearDiD` package exposes two relevant interfaces. `nonlinear_attgt()` is meant to compute staggered `ATT(g,t)` objects. `count_did_poisson()` estimates a two-period DID for count outcomes and returns a log rate ratio, a rate ratio, and a count-scale average partial effect. Local inspection on 2026-05-22 showed that the panel branch of `nonlinear_attgt()` should not be treated as a valid Poisson panel path in the installed version, so this plan uses `count_did_poisson()` as the count estimator inside a locally written staggered loop.

## Scope

This ExecPlan covers the first-pass county benchmark family only.

In scope:

- a new Poisson sample builder for the county benchmark treated universe
- one shared Poisson helper layer
- one outcome script per benchmark county outcome
- one combined ATT table across the benchmark outcome family
- one slide-ready image table across the benchmark outcome family
- CSV exports that preserve group-time and aggregated Poisson results for auditability

Out of scope for this first pass:

- the RUCC heterogeneity script `1_2_10_event_study_total_ds_het.R`
- the isolated never-treated and HonestDiD sensitivity scripts in `1_code/1_2_reduced_form/isolated`
- README edits

## Data Artifact Flow

The Poisson branch should create a clean, explicit pipeline.

Raw analytical input comes from `2_9_analysis/2_9_0_us_analysis_panel.rds`, resolved through `2_processed_data/processed_root.txt`. This is the same processed panel that feeds the benchmark county branch.

The new Poisson sample builder should write one branch-specific intermediate file, recommended as `2_9_analysis/2_9_3_county_poisson_did_sample.rds`. This object should preserve the benchmark county treated universe and benchmark covariates, but it should include years `2013:2019` so cohort `2014` has a valid base period. It should contain at least the columns `{county_fips, year, eventYear2, total_ds, chain_super_market, chain_convenience_store, chain_multi_category, chain_medium_grocery, chain_small_grocery, chain_produce, chain_farmers_market, population, wage, meanInc, rent, urate}` plus an explicit Poisson cohort variable such as `g_first_treat`.

The Poisson outcome scripts should read only `2_9_3_county_poisson_did_sample.rds`, estimate their staggered Poisson branch, and write versioned outputs under:

- `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_1b_poissonregs/` for plots and image tables
- `3_outputs/3_0_tables/3_2_0_county/3_2_0_1b_poissonregs/` for LaTeX tables and CSV summaries

For each outcome, the branch should write at least four artifacts:

- an event-study PDF on the chosen count-scale presentation metric
- a LaTeX summary table
- a CSV of group-time `ATT(g,t)` cells
- a CSV of aggregated dynamic and overall results

The combined table scripts should consume the same helper outputs and write one multi-outcome LaTeX table plus one slide-ready image table and one backing CSV.

## Data Contracts, Inputs, and Dependencies

`2_9_analysis/2_9_0_us_analysis_panel.rds` is the authoritative processed county-year input. The Poisson sample builder must assume it contains one row per county-year, the outlet-count outcomes used in the current benchmark branch, the first-treatment timing column `eventYear2`, and the controls already used by the benchmark county regressions.

`1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/shared_reduced_form_helpers.R` is the benchmark path/output helper source. The new Poisson helper layer may reuse its repository-root discovery and versioned-output path logic, but it must not reuse its Sun-Abraham model runner.

`NonlinearDiD` 0.2.0 is required. Within this package, the operative contract for this plan is:

- `count_did_poisson()` consumes a two-period long-format data frame, a count outcome name, a time variable, a unit ID, one treated period, one control period, and a cohort or treatment indicator. It returns at least `att_log_rr`, `rate_ratio`, `att_ape`, and the fitted generalized linear model object.
- `nonlinear_aggte()` may be used only as an aggregation convenience if the implementation constructs an object with the same `attgt` schema expected by the function. It must not be used as evidence that the underlying estimator was the package’s panel Poisson staggered estimator.
- `nonlinear_pretest()` is optional in this first pass and should only be used if the implementation can supply coherent standard errors on the constructed `ATT(g,t)` object.

The Poisson helper’s core function contract should be explicit. A function such as `run_staggered_poisson_outcome(var_name)` should:

1. Load the Poisson-ready county sample.
2. Enumerate each treated cohort `g` and each calendar time `t` observed for that outcome.
3. For each valid cell, form the 2x2 dataset consisting of cohort `g` and the benchmark-mirroring not-yet-treated controls with first treatment year greater than `t`, observed in periods `g - 1` and `t`.
4. Call `count_did_poisson()` on that 2x2 data.
5. Store the cell-level point estimate and inference objects in a rectangular `ATT(g,t)` table.
6. Aggregate those cells into dynamic and overall summaries for plotting and tables.

The Poisson sample builder’s contract should also be explicit. A function or script such as `1_2_0_1b_0_build_poisson_event_study_sample.R` should read `2_9_0_us_analysis_panel.rds`, apply the benchmark treated-universe and control-variable conventions, extend the year window back to 2013, and write `2_9_3_county_poisson_did_sample.rds` without modifying any incumbent benchmark sample file.

## Plan of Work

### Milestone 1: Build a benchmark-mirroring Poisson sample

Create a new script in `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs` that rebuilds the county benchmark sample from `2_9_0_us_analysis_panel.rds`. Do not read the saved Sun-Abraham event-study sample because it starts in 2014 and therefore cannot supply a base period for the 2014 cohort.

This sample builder should preserve the benchmark treated-universe logic. That means: keep the same county and state eligibility logic, keep the same control variables and rescaling for `rent` and `meanInc`, and keep the same count outcomes. The one deliberate deviation from the benchmark sample is the year window: the Poisson branch should use `2013:2019`, not `2014:2019`, so each treated cohort has a valid `g - 1` base period. The script should write a new branch-specific intermediate file, not overwrite `2_9_2_event_study_sample.rds`.

The script should create an explicit cohort variable suitable for the new helper layer. For the benchmark-mirroring branch, `g_first_treat` should equal the first treatment year for each ever-treated county. Because the first-pass branch mirrors the benchmark sample universe, this file does not need never-treated counties.

### Milestone 2: Add a shared Poisson helper layer with estimator-path guardrails

Create a new helper file in `1_2_0_1b_poissonregs` that handles path resolution, sample loading, versioned output paths, group-time Poisson estimation, aggregation, and output writing. Reuse existing root/output helpers where possible, but keep all Poisson estimation logic in the new helper.

The helper must include a guardrail that explicitly prevents future contributors from silently using the direct panel `nonlinear_attgt(..., outcome_model = "poisson")` path. The helper should contain a short validation function or a clearly labeled comment block summarizing the locally verified issue: in the installed package version, that panel path behaves identically to the linear path on simulated panel data.

The core estimator function should loop over cohorts and calendar times. For each treated cohort `g` and time `t`, it should build a two-period comparison using base period `g - 1` and comparison period `t`. Controls should be counties whose first treatment year is greater than `t`. The function should skip invalid cells cleanly when the comparison set is empty.

The function should call `count_did_poisson()` on each valid 2x2 comparison and save three related measures per cell:

- `att_log_rr`: log rate ratio
- `rate_ratio`: multiplicative treatment effect
- `att_ape`: count-scale average partial effect

The helper should then build a rectangular `ATT(g,t)` table with the columns needed for downstream aggregation and auditing. At minimum this table should contain `{group, time, att, se, post, n_treated, n_control, att_log_rr, rate_ratio, att_ape}` plus confidence intervals for the chosen presentation metric.

Inference requires special care. The installed `count_did_poisson()` interface documents clustered standard errors, but the point-estimation helper alone is not enough to guarantee county-clustered inference for the full staggered branch. The implementation should therefore compute branch-level inference with a county bootstrap over the full estimation routine. Use a light bootstrap count for smoke tests and a larger default for final analytical runs. The exact count may be configurable, but the default must be recorded in the script header and exported metadata.

### Milestone 3: Implement the benchmark outcome wrappers and combined outputs

Create one thin wrapper script per benchmark county outcome in `1_2_0_1b_poissonregs`. Match the existing benchmark outcome family:

- `total_ds`
- `chain_super_market`
- `chain_convenience_store`
- `chain_multi_category`
- `chain_medium_grocery`
- `chain_small_grocery`
- `chain_produce`
- `chain_farmers_market`

Each wrapper should call the shared Poisson helper once and should write artifacts under the mirrored Poisson output folders. Use naming that makes the estimand obvious. For example, if the primary plot/table uses count-scale average partial effects, include `poisson_ape` in the file stub rather than a generic `event_study` label.

After the single-outcome scripts work, create one combined LaTeX table script and one slide-ready image table script, parallel to the benchmark `1_2_9_event_study_all_table.R` and `1_2_11_event_study_all_table_image.R`. These should summarize the primary Poisson estimand consistently across outcomes and should also write a CSV backing table for inspection.

### Milestone 4: Keep the branch auditable and separable from the benchmark

The Poisson branch must remain additive. Do not delete or overwrite the benchmark Sun-Abraham scripts or outputs. The purpose is comparison, not substitution in place.

Each Poisson script should emit enough metadata that a reviewer can confirm exactly what was estimated. At minimum, the CSV outputs should make clear the control-group rule, the cohort variable, the base-period rule `g - 1`, the presentation metric, and the bootstrap setting used for inference.

## Concrete Steps

All commands below should be run from `/Users/indermajumdar/Research/snap_dollar_entry`.

Build the branch-specific Poisson sample:

    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_0_build_poisson_event_study_sample.R

Run one benchmark Poisson outcome:

    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_1_event_study_poisson_total_ds.R

Run the combined Poisson table:

    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_9_event_study_poisson_all_table.R

Run the Poisson image-table exporter:

    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_10_event_study_poisson_all_table_image.R

Expected behavior after implementation:

- the sample builder prints the new sample path and basic counts for rows, counties, cohort years, and year range
- each outcome script prints the output artifact paths it wrote
- reruns create versioned user-facing artifacts under `3_outputs` instead of overwriting prior plots or tables

## Validation and Acceptance

Validation 1 is the estimator-path guardrail.

Command:

    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_0_validate_poisson_path.R

Expected artifacts or output:

- a short console summary that reports the locally verified package issue for the direct panel `nonlinear_attgt()` Poisson path
- a passing confirmation that the implemented county Poisson helper does not rely on that path

Expected behavior or result:

- before implementation, this validation fails because the guardrail script does not yet exist
- after implementation, it passes and explicitly documents why the branch uses the two-period Poisson helper inside a staggered loop

Why this is sufficient evidence:

- it proves the implementation is not silently calling a path that behaves linearly in the installed package version

Validation 2 is end-to-end artifact creation for one benchmark outcome.

Command:

    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_0_build_poisson_event_study_sample.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_1_event_study_poisson_total_ds.R

Expected artifacts or output:

- `2_9_analysis/2_9_3_county_poisson_did_sample.rds`
- a versioned PDF event-study plot for `total_ds`
- a versioned LaTeX table for `total_ds`
- a CSV of cell-level `ATT(g,t)` results
- a CSV of aggregated dynamic and overall results

Expected behavior or result:

- the sample spans `2013:2019`
- the control-group metadata says `notyettreated`
- the event-study CSV includes non-missing post-treatment rows for at least cohorts `2014`, `2015`, and `2016`

Why this is sufficient evidence:

- it proves the new branch can construct the required sample, estimate a staggered Poisson DID for a benchmark outcome, and write auditable artifacts without touching the incumbent benchmark branch

Validation 3 is combined-table consistency across the benchmark outcome family.

Command:

    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_9_event_study_poisson_all_table.R
    /usr/local/bin/Rscript 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1b_poissonregs/1_2_0_1b_10_event_study_poisson_all_table_image.R

Expected artifacts or output:

- one versioned LaTeX table covering all benchmark outcomes
- one versioned image table
- one CSV backing the image table

Expected behavior or result:

- outcome order matches the benchmark outcome registry
- labels match the benchmark display labels
- the table and image-table scripts draw from the same underlying outcome results

Why this is sufficient evidence:

- it proves the Poisson branch reproduces the full county benchmark artifact pattern, not just one diagnostic regression

## Idempotence and Recovery

This plan is additive. The new Poisson branch lives in a new code folder and writes to new output subdirectories, so it can be rerun without disturbing the benchmark Sun-Abraham branch.

User-facing outputs must remain non-destructive. Plots, LaTeX tables, image tables, and CSV summaries should use versioned file names through the same `next_available_path()` pattern already used in the benchmark branch.

The branch-specific sample file may use one stable processed-data path because it is an intermediate dependency for the new scripts, but it must never overwrite `2_9_2_event_study_sample.rds`. If the Poisson sample builder fails halfway through, rerun it; it should regenerate the branch-specific sample from the processed analysis panel without needing manual cleanup.

If future package updates fix the panel `nonlinear_attgt()` Poisson path, do not silently switch estimators. Record the package version change, rerun the guardrail validation, and update this ExecPlan’s `Decision Log` first.

## Completion Checklist

- [ ] A branch-specific Poisson county sample builder exists and writes `2_9_3_county_poisson_did_sample.rds`.
- [ ] A shared Poisson helper exists and records why the direct panel `nonlinear_attgt()` Poisson path is not used.
- [ ] Single-outcome Poisson scripts exist for the benchmark county outcome family.
- [ ] Combined LaTeX and image-table scripts exist for the benchmark county outcome family.
- [ ] Validation 1 passes.
- [ ] Validation 2 passes.
- [ ] Validation 3 passes.
- [ ] The incumbent Sun-Abraham county branch remains unchanged.

## Artifacts and Notes

Evidence collected during planning on 2026-05-22 that should be preserved during execution:

    Benchmark saved county event-study sample:
    rows = 11998
    counties = 2010
    years = 2014:2019
    treated_group table: TRUE = 11998

    Local package behavior check on simulated panel count data:
    nonlinear_attgt(panel, outcome_model = "poisson") versus
    nonlinear_attgt(panel, outcome_model = "linear")
    all.equal(attgt$att) == TRUE
    max abs diff == 0

Change note: This ExecPlan records a package-behavior constraint discovered during planning. The reason for including that constraint directly in the plan is that the user’s requested estimator depends on the package path actually being nonlinear for panel counts, and the installed version does not satisfy that requirement when called through the direct staggered panel entry point.
