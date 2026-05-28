# Make the reduced-form scripts auditable through comment-only documentation

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

## ExecPlan Status

Status: Planning  
Owner: Inder Majumdar + Codex  
Created: 2026-05-22  
Last Updated: 2026-05-22  
Related Project: `snap_dollar_entry` reduced-form script auditability and comment standardization

## Revision History

| Date | Change | Author |
| --- | --- | --- |
| 2026-05-22 | Initial planning draft created after auditing all `.R` files in `1_code/1_2_reduced_form` and grouping them by role, duplication pattern, and audit needs | Codex |

## Quick Summary

### Goal

Make the reduced-form code reviewable without changing any executable logic by introducing a rigorous, standardized comment regime across every reduced-form script. This matters because the current scripts are short on explanation even when the underlying logic is consequential, duplicated, or easy to misread.

### Deliverable

The deliverable is a comment-only documentation pass over every `.R` file in `1_code/1_2_reduced_form`, plus a validation routine proving that the executable parse tree is unchanged relative to pre-edit baselines. After completion, a reviewer should be able to open any reduced-form script and understand what it reads, what sample it builds, what model it estimates, what outputs it writes, and which assumptions deserve scrutiny.

### Success Criteria

- Every target reduced-form `.R` file has a standardized file-level preamble that explains purpose, inputs, outputs, and reviewer-relevant assumptions in plain language.
- Every non-trivial function has a contract comment describing inputs, returns, side effects, and invariants.
- Every non-obvious transformation or estimation block has a short comment that explains why the block exists, not only what R syntax it uses.
- The edits are comment-only: after taking pre-edit baselines, each target file has an identical parsed expression tree before and after the documentation pass.
- A reviewer can distinguish benchmark scripts, helper scripts, thin wrapper scripts, heterogeneity scripts, and isolated sensitivity scripts from their comments alone.

### Key Files

- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/1_2_0_0_1_desc_stats_outcomes.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/shared_reduced_form_helpers.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/shared_reduced_form_helpers.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_1_event_study_total_ds.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_2_event_study_chain_super_market.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_3_event_study_chain_convenience_store.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_4_event_study_chain_multi_category.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_5_event_study_chain_medium_grocery.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_6_event_study_chain_small_grocery.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_7_event_study_chain_produce.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_8_event_study_chain_farmers_market.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_9_event_study_all_table.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_10_event_study_total_ds_het.R`
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_11_event_study_all_table_image.R`
- `1_code/1_2_reduced_form/1_2_0_county/shared_reduced_form_helpers.R`
- `1_code/1_2_reduced_form/isolated/1_2_11_event_study_total_ds_never_treated_control.R`
- `1_code/1_2_reduced_form/isolated/1_2_12_compare_total_ds_control_groups.R`
- `1_code/1_2_reduced_form/isolated/1_2_13_honestdid_total_ds_control_groups.R`
- `1_code/1_2_reduced_form/isolated/1_2_14_compare_total_ds_control_groups_table_image.R`
- `agent-docs/execplans/2026-05-22-reduced-form-commenting-execplan.md`

## Purpose / Big Picture

After this work, a reviewer should be able to audit the reduced-form folder directly from the scripts instead of reverse-engineering intent from terse helper calls, repeated path boilerplate, and long mutate or modeling blocks. The point is not to make the code prettier. The point is to make the code inspectable: where the sample comes from, how treatment timing is handled, why sentinels like `10000` and `-1000` are introduced, which outputs are versioned rather than overwritten, and where duplicated logic creates a consistency risk.

This plan is intentionally documentation-only. It does not change formulas, sample rules, variables, output names, pathing, or dependencies. It does not consolidate duplicated code, rewrite helpers, or alter any output artifacts. The only allowed modifications in the execution phase are comments and blank-line formatting needed to make those comments readable.

In this plan, a “rigorous commenting regime” means a fixed set of comment types applied consistently. Every file gets a file-level preamble. Every major section gets a purpose comment. Every non-trivial function gets a contract comment. Every analytically consequential block gets an “assumption” or “review focus” comment that tells a reviewer what to question. Comments must explain intent and implications in plain English, not merely restate code tokens.

## Progress

- [x] (2026-05-22 10:52 America/Chicago) Located the reduced-form subtree and confirmed the target area is `1_code/1_2_reduced_form`.
- [x] (2026-05-22 10:56 America/Chicago) Audited the plan template in `agent-docs/PLANS.md`.
- [x] (2026-05-22 11:02 America/Chicago) Enumerated all reduced-form `.R` files and line counts.
- [x] (2026-05-22 11:09 America/Chicago) Audited representative helper, benchmark, heterogeneity, and isolated scripts to identify repeated structures and missing documentation points.
- [x] (2026-05-22 11:18 America/Chicago) Confirmed that `1_code/1_2_reduced_form/1_2_1_censustract` currently contains no `.R` files, so this ExecPlan applies to the county and isolated branches only.
- [x] (2026-05-22 11:35 America/Chicago) Drafted this ExecPlan.
- [ ] Execute the comment-only documentation pass across all target files.
- [ ] Run the parse-tree invariance and coverage validations described below.

## Surprises & Discoveries

- Observation: The reduced-form area is smaller than it initially appears, but the key readability problem is repeated undocumented logic rather than raw file count.
  Evidence: The folder contains 19 target `.R` files, including three copies of `shared_reduced_form_helpers.R`, eight thin wrapper scripts, one benchmark sample builder, one heterogeneity script, one descriptive-statistics script, one multi-model table builder, one table-image script, and four isolated sensitivity scripts.

- Observation: Three helper files are effectively duplicated copies and therefore need synchronized comments to avoid drift in future review work.
  Evidence: `1_code/1_2_reduced_form/1_2_0_county/shared_reduced_form_helpers.R`, `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/shared_reduced_form_helpers.R`, and `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/shared_reduced_form_helpers.R` each contain the same helper definitions through `save_event_study_artifact()`.

- Observation: Several of the shortest scripts are the least readable because their substantive meaning is hidden in a one-line helper call.
  Evidence: Each of `1_2_1_event_study_total_ds.R` through `1_2_8_event_study_chain_farmers_market.R` is 26 lines long and differs mainly in the outcome name, label, and file stub passed into `save_event_study_artifact()`.

- Observation: The biggest audit risks are not syntax complexity alone; they are silent conventions and sentinels that currently appear without explanation.
  Evidence: Multiple scripts replace missing `eventYear2` with `10000`, replace missing `tau2` with `-1000`, restrict to `year %in% 2014:2019`, and use `year - eventYear2 >= -3`, yet those conventions are not explained inline.

- Observation: Several scripts are standalone copies of helper logic rather than direct consumers of shared helpers, so comments must also explain why those files are intentionally self-contained.
  Evidence: `1_2_10_event_study_total_ds_het.R` and all four files in `1_code/1_2_reduced_form/isolated` reimplement path handling, output versioning, and model setup instead of sourcing the shared helper file.

## Decision Log

- Decision: Scope this ExecPlan to comment-only changes in `.R` files and not to README updates.
  Rationale: The user requested a spec plan for a rigorous commenting regime and explicitly asked to avoid changing the codebase behavior. README governance also requires a separate instruction set and explicit request before README edits.
  Date/Author: 2026-05-22 / Codex

- Decision: Treat parse-tree invariance as the primary “no code change” validation standard.
  Rationale: In R, comments are excluded from the parsed expression tree. If each file parses to the same expressions before and after the edit, then the documentation pass did not alter executable logic.
  Date/Author: 2026-05-22 / Codex

- Decision: Require comments to explain review relevance, not just mechanics.
  Rationale: The user wants comments that help assess validity and accuracy, so the regime must identify assumptions, implicit conventions, and outputs that deserve scrutiny.
  Date/Author: 2026-05-22 / Codex

- Decision: Keep duplicated helper comments synchronized rather than documenting only one helper copy and referring the reader elsewhere.
  Rationale: Reviewers open files locally, not abstract code families. Each file must stand on its own, and duplicated comments are acceptable because the helper files are already duplicated.
  Date/Author: 2026-05-22 / Codex

- Decision: Exclude `.DS_Store` files and the empty `1_2_1_censustract` directory from execution scope.
  Rationale: They are not executable reduced-form scripts and adding plan requirements for them would create noise without improving code auditability.
  Date/Author: 2026-05-22 / Codex

## Outcomes & Retrospective

The planning objective is complete. This ExecPlan now gives a future executor a precise, comment-only route to make the reduced-form folder readable without changing any executable behavior.

No script files were edited while creating this plan. The remaining work is execution: insert the comments, prove parse-tree invariance, and manually inspect that the resulting comments are genuinely useful rather than boilerplate.

The central lesson from the audit is that readability here will improve most if comments are tied to analytical choices and duplicated logic. Generic style comments will not solve the problem.

## Context and Orientation

The reduced-form folder currently has four functional groups.

First, the county benchmark branch under `1_code/1_2_reduced_form/1_2_0_county` contains the sample builder, descriptive statistics, benchmark event-study helpers, thin wrappers for individual outcomes, and scripts that build combined tables or images. This is the main reusable reduced-form pathway.

Second, the isolated branch under `1_code/1_2_reduced_form/isolated` contains standalone sensitivity scripts for alternative control groups and HonestDiD analysis. “Standalone” here means the scripts do not source the shared reduced-form helper file even when they replicate similar logic.

Third, there are three duplicated helper files named `shared_reduced_form_helpers.R`. These define path resolution, output path creation, the benchmark model runner, event-profile extraction, and a helper that writes the benchmark plot and ATT table for a requested outcome.

Fourth, `1_code/1_2_reduced_form/1_2_1_censustract` currently has no `.R` files, so there is nothing to annotate there in the current execution cycle.

The most important substantive conventions that comments must expose are the following:

- The benchmark sample is built from `2_9_analysis/2_9_0_us_analysis_panel.rds` and written to `2_9_analysis/2_9_2_event_study_sample.rds`.
- Benchmark event studies use an inverse hyperbolic sine transform implemented as `log(y + sqrt(y^2 + 1))`.
- Benchmark regressions use `sunab(eventYear2, year, ref.p = 0)` with controls `population + wage + meanInc + rent + urate` and fixed effects `county_fips + year`.
- Missing event time values are replaced by sentinel values such as `eventYear2 = 10000` and `tau2 = -1000` before sample restriction logic is applied.
- Most output-writing helpers use `next_available_path()` rather than overwriting existing files, so output comments must explain versioning behavior.

The folder inventory to be covered by execution is:

- Descriptive statistics: `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/1_2_0_0_1_desc_stats_outcomes.R`
- Helper copies: `1_code/1_2_reduced_form/1_2_0_county/shared_reduced_form_helpers.R`, `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/shared_reduced_form_helpers.R`, and `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/shared_reduced_form_helpers.R`
- Sample builder: `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R`
- Thin wrappers: `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_1_event_study_total_ds.R` through `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_8_event_study_chain_farmers_market.R`
- Combined benchmark outputs: `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_9_event_study_all_table.R` and `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_11_event_study_all_table_image.R`
- Heterogeneity analysis: `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_10_event_study_total_ds_het.R`
- Isolated sensitivity scripts: `1_code/1_2_reduced_form/isolated/1_2_11_event_study_total_ds_never_treated_control.R`, `1_code/1_2_reduced_form/isolated/1_2_12_compare_total_ds_control_groups.R`, `1_code/1_2_reduced_form/isolated/1_2_13_honestdid_total_ds_control_groups.R`, and `1_code/1_2_reduced_form/isolated/1_2_14_compare_total_ds_control_groups_table_image.R`

## Commenting Standard

Every target file must receive the same four layers of documentation, with additional detail added where complexity requires it.

Layer 1 is the file-level preamble. Every file must start with a consistent block that states file name, purpose, inputs, outputs, dependencies, and a short “review focus” note. The review focus note is mandatory because the user wants to judge validity and accuracy, not just navigate syntax. For thin wrapper scripts, this review focus should explain that almost all substantive logic lives in the sourced helper and that the main thing to verify is whether the selected outcome and output stub match the file name.

Layer 2 is section-level purpose comments. Before each major block such as path setup, sample construction, model estimation, event-profile extraction, table rendering, or file writing, add a short comment that explains why the block exists and what invariant it should preserve. These comments should use plain English and should name the concrete object being created or modified.

Layer 3 is the function contract comment. Every non-trivial function must have a short block immediately above it with four elements written as plain comments: purpose, required inputs, returned value, and side effects or assumptions. For example, `run_event_study_model()` should state that it expects an outcome variable name already present in the event-study sample, estimates the benchmark Sun-Abraham specification, and clusters by `county_fips`.

Layer 4 is the audit comment. This is a short comment attached to analytically consequential lines or blocks. Audit comments must identify the interpretation or risk a reviewer should check. Examples include why `rent` and `meanInc` are rescaled by `1000`, why missing event timing is replaced by sentinels rather than left missing, why `year - eventYear2 >= -3` defines the pre-period window, how all-never-treated controls differ from eventually-treated controls, and how the HonestDiD target vectors map to “first post” and “average post”.

Comments must remain factual. They may explain what the code operationalizes, but they must not claim that a modeling choice is substantively correct unless that correctness is already encoded or directly testable from the script. For instance, a comment may say “this script uses all never-treated counties as the reference sample,” but it should not say “this is the right control group.”

## File-Specific Workplan

The helper files come first because they supply meaning to many short scripts. In all three copies of `shared_reduced_form_helpers.R`, add a file-level preamble and contract comments for `get_script_path()`, `find_repo_root()`, `get_repo_root()`, `read_root_path()`, `map_output_component()`, `build_output_dir_path()`, `reduced_form_output_subdir()`, `ensure_reduced_form_dirs()`, `next_available_path()`, `reduced_form_plot_path()`, `reduced_form_table_path()`, `theme_im()`, `load_event_study_sample()`, `run_event_study_model()`, `extract_event_profile()`, and `save_event_study_artifact()`. Above the outcome-label vectors, add a short registry comment that explains they define the benchmark output order used elsewhere. Above `save_event_study_artifact()`, add a comment noting that it writes a PDF and LaTeX ATT table without overwriting prior outputs because file names are versioned through `next_available_path()`.

In `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R`, preserve the existing preamble style but tighten it into the new standard and add section comments for path resolution, input loading, sample construction, and output writing. Add audit comments directly above the block that creates `lowq`, rescales `rent` and `meanInc`, creates `no_stores`, sets `state_fips`, fills `tau2` and `eventYear2` sentinels, and restricts the sample to 2014 through 2019 with the `year - eventYear2 >= -3` rule. Each of those comments must explain why a reviewer should care about the line, not just what the line does.

In `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/1_2_0_0_1_desc_stats_outcomes.R`, add a file preamble, a short note that the script summarizes the benchmark event-study sample rather than the full analysis panel, and section comments before sample loading, outcome renaming, and `stargazer()` export. Add one audit comment explaining that the displayed labels come from `event_study_labels`, which must stay aligned with `event_study_outcomes`.

In the thin wrapper scripts `1_2_1_event_study_total_ds.R` through `1_2_8_event_study_chain_farmers_market.R`, do not pad them with unnecessary inline comments. Instead, add a brief preamble, a one-line section comment before sourcing the helper, and a one-line comment above `save_event_study_artifact()` that states which benchmark outcome is being delegated to the helper and which file stub will name the outputs. The goal is to make it obvious that these are dispatch scripts, not places where estimation logic lives.

In `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_9_event_study_all_table.R`, add a preamble and section comments for helper loading, model list construction, and ATT table export. Add an audit comment that the table column order is inherited from `event_study_outcomes` and `event_study_labels`, so those registries define interpretation as well as formatting.

In `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_11_event_study_all_table_image.R`, annotate the significance-star helper, ATT cell formatting, summary extraction, multi-model evaluation, and image table rendering blocks. Add an audit comment that this script is presentation-oriented: it turns model outputs into a slide-ready image table, so reviewers should verify consistency against `1_2_9_event_study_all_table.R` rather than reading it as an independent estimation script.

In `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_10_event_study_total_ds_het.R`, expand the existing preamble and add explicit section comments for path resolution, helper-like local utility definitions, benchmark sample reconstruction, RUCC merge, three-group heterogeneity estimation, metro/nonmetro estimation, ATT table writing, and plot export. Add audit comments for the fact that this file intentionally does not source the shared helper, for the RUCC input dependency, for each grouping choice, and for the fact that the script rebuilds the event-study sample inline rather than reusing `2_9_2_event_study_sample.rds`.

In `1_code/1_2_reduced_form/isolated/1_2_11_event_study_total_ds_never_treated_control.R`, add comments that isolate the alternative control-group logic from the otherwise benchmark-like model. The key audit note must explain that the critical design difference is the inclusion of all never-treated counties as controls.

In `1_code/1_2_reduced_form/isolated/1_2_12_compare_total_ds_control_groups.R`, add comments that explain the shared base panel, the two derived samples, the two model objects, the merged event-profile output, and the ATT comparison outputs. Add an audit comment that the script is comparative: reviewers should check whether the only intended difference between the two models is the control-group construction.

In `1_code/1_2_reduced_form/isolated/1_2_13_honestdid_total_ds_control_groups.R`, add contract comments for `estimate_model()`, `extract_aggregated_event_study()`, and `run_honestdid_target()`. The audit comments must explain the event-time aggregation logic, the meaning of `mbar_vec`, the difference between the “first post” and “average post” target vectors, and how the breakdown `Mbar` is defined operationally in the script.

In `1_code/1_2_reduced_form/isolated/1_2_14_compare_total_ds_control_groups_table_image.R`, add comments that parallel the comparative logic from `1_2_12_compare_total_ds_control_groups.R` but explain that the deliverable is a formatted image table plus CSV, not a regression figure. Add an audit note that the fit statistics and ATT values shown in the image must match the underlying models used in the comparison script.

## Plan of Work

Begin by creating a temporary baseline directory outside the tracked tree, for example under `/private/tmp`, and copy every target `.R` file there before any edits. Those baselines are required for the parse-tree invariance check later.

Make the edits in three passes.

Pass one is structural. Add or standardize file-level preambles in every target script, ensuring each preamble includes purpose, inputs, outputs, dependencies, and review focus. For files that already have a preamble, such as `1_2_0_build_event_study_sample.R` and the isolated scripts, preserve the factual content but rewrite for consistency and completeness.

Pass two is explanatory. Insert section comments and function contract comments across the helper, benchmark, heterogeneity, and isolated scripts. Keep comments short, specific, and local to the block they explain. Do not comment obvious library calls or simple assignments unless they participate in a materially important convention.

Pass three is audit-oriented. Add comments only where they improve reviewability of assumptions, duplicated logic, or output semantics. Focus on sentinels, sample restrictions, model formulas, control-group definitions, aggregation logic, versioned output writing, and the relationship between thin wrappers and shared helpers.

During execution, keep the helpers synchronized. The three helper copies should receive identical comment content except where directory-specific wording is required. If divergence is discovered in code content during execution, stop and record that discovery in this ExecPlan before proceeding, because inconsistent helper comments would become misleading.

Do not modify executable tokens, object names, formulas, file names, package calls, or write behavior. This includes avoiding “small cleanup” changes such as replacing `write.csv()` with `readr::write_csv()`, changing spacing inside formulas, or renaming objects for readability. Those would fall outside the documentation-only scope.

## Concrete Steps

All commands below should be run from `/Users/indermajumdar/Research/snap_dollar_entry` unless another working directory is shown explicitly.

First, create a baseline snapshot before editing:

    mkdir -p /private/tmp/reduced_form_comment_baseline
    while IFS= read -r f; do
      mkdir -p "/private/tmp/reduced_form_comment_baseline/$(dirname "$f")"
      cp "$f" "/private/tmp/reduced_form_comment_baseline/$f"
    done < <(find 1_code/1_2_reduced_form -name '*.R' | sort)

Then edit the target files by adding comments only.

After editing, run a syntax and parse-tree invariance check:

    /usr/local/bin/Rscript -e 'files <- sort(Sys.glob("1_code/1_2_reduced_form/**/*.R")); baseline_root <- "/private/tmp/reduced_form_comment_baseline"; check_one <- function(f) { old <- parse(file.path(baseline_root, f), keep.source = FALSE); new <- parse(f, keep.source = FALSE); if (!identical(as.list(old), as.list(new))) stop(sprintf("Executable change detected in %s", f)); invisible(TRUE) }; invisible(lapply(files, check_one)); cat("Parse-tree invariance check passed for", length(files), "files.\\n")'

Then run a comment-coverage spot check:

    rg -n "^# File name:|^# Description:|^# INPUTS:|^# OUTPUTS:|^# Review focus:|^# Purpose:|^# Returns:|^# Side effects:" 1_code/1_2_reduced_form

The expected qualitative transcript is:

    Every target script prints multiple matches.
    Thin wrapper scripts show a short preamble and at least one delegation comment.
    Helper and isolated scripts show repeated function contract markers such as `Purpose`, `Returns`, or `Side effects`.

Finally, run a manual diff review limited to the reduced-form folder:

    git diff -- 1_code/1_2_reduced_form

The expected qualitative transcript is:

    The diff shows only comment additions, comment rewrites, and blank-line formatting.
    No formulas, object names, file paths, package calls, or write functions change.

## Validation and Acceptance

Validation is documentation-focused because the plan must not change behavior.

First, the parse-tree invariance check must pass for every target `.R` file against the pre-edit baseline copy. This is the main proof that the documentation pass did not alter executable logic.

Second, a manual reduced-form diff review must confirm that all modifications are comments or blank lines. This is necessary because parse-tree equality does not distinguish comments from other non-semantic formatting changes, and the user explicitly wants a reviewable commenting regime rather than a silent code restyle.

Third, spot-check at least one file from each script class after editing: one helper file, `1_2_0_build_event_study_sample.R`, one thin wrapper, `1_2_10_event_study_total_ds_het.R`, and one isolated script. Acceptance requires that a reviewer can answer the following from comments alone without tracing helper internals: what the script reads, what it writes, which sample or control-group rule is distinctive, and which assumptions deserve scrutiny.

Acceptance is met only when all three validations pass.

## Completion Checklist

- [ ] Baseline copies exist for every target reduced-form `.R` file.
- [ ] Every target file has a file-level preamble with purpose, inputs, outputs, dependencies, and review focus.
- [ ] Every non-trivial function has a contract comment covering purpose, inputs, returns, and side effects or assumptions.
- [ ] Every analytically consequential sample, estimation, aggregation, and output block has a concise audit-oriented comment.
- [ ] The three helper copies contain synchronized comments.
- [ ] Parse-tree invariance passes for every target file.
- [ ] Manual `git diff` review confirms comment-only edits.
- [ ] `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` are updated during execution.

## Idempotence and Recovery

This work is safe to redo because it is comment-only. If a comment pass becomes cluttered or inaccurate, restore the affected file from the baseline copy in `/private/tmp/reduced_form_comment_baseline` and reapply the documentation cleanly. Do not use destructive git commands for recovery unless explicitly requested.

If the parse-tree invariance check fails for any file, stop immediately. Compare the current file to its baseline, remove the accidental executable edit, and rerun the parse check before continuing to other files. Do not proceed on the assumption that a “small” executable difference is harmless, because that would violate the scope of this plan.

## Artifacts and Notes

The current reduced-form script inventory and line counts are:

    40  1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/1_2_0_0_1_desc_stats_outcomes.R
    252 1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/shared_reduced_form_helpers.R
    74  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R
    418 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_10_event_study_total_ds_het.R
    218 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_11_event_study_all_table_image.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_1_event_study_total_ds.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_2_event_study_chain_super_market.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_3_event_study_chain_convenience_store.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_4_event_study_chain_multi_category.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_5_event_study_chain_medium_grocery.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_6_event_study_chain_small_grocery.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_7_event_study_chain_produce.R
    26  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_8_event_study_chain_farmers_market.R
    44  1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_9_event_study_all_table.R
    252 1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/shared_reduced_form_helpers.R
    252 1_code/1_2_reduced_form/1_2_0_county/shared_reduced_form_helpers.R
    214 1_code/1_2_reduced_form/isolated/1_2_11_event_study_total_ds_never_treated_control.R
    249 1_code/1_2_reduced_form/isolated/1_2_12_compare_total_ds_control_groups.R
    334 1_code/1_2_reduced_form/isolated/1_2_13_honestdid_total_ds_control_groups.R
    318 1_code/1_2_reduced_form/isolated/1_2_14_compare_total_ds_control_groups_table_image.R

The highest-priority audit anchors for the final comments are:

    `eventYear2 = 10000` and `tau2 = -1000` sentinel conventions
    `year %in% 2014:2019` and `year - eventYear2 >= -3` sample restrictions
    benchmark versus isolated control-group definitions
    duplicated helper logic and standalone script design
    versioned output writing through `next_available_path()`

## Data Contracts, Inputs, and Dependencies

This documentation pass depends on the current reduced-form source files themselves; no data artifacts need to be regenerated during execution.

The target scripts consume these libraries at the source level and comments should name them only where they materially affect interpretation:

- `fixest` for Sun-Abraham event-study estimation and ATT summaries.
- `ggplot2` for event-study figures and image table rendering support.
- `dplyr` and `stringr` for sample construction and path text cleanup.
- `stargazer`, `grid`, `gridExtra`, `gtable`, `readr`, `readxl`, `tibble`, and `HonestDiD` in the specific scripts that use them.

The main data contracts that comments should describe are:

- `2_processed_data/processed_root.txt` stores the root path for processed artifacts and is read as a plain text pointer.
- `2_9_analysis/2_9_0_us_analysis_panel.rds` is the raw input to the reduced-form sample-building and isolated comparison scripts.
- `2_9_analysis/2_9_2_event_study_sample.rds` is the benchmark event-study sample consumed by helper-driven benchmark scripts.
- `0_inputs/input_root.txt` and `0_7_Ruralurbancontinuumcodes2013.xls` are additional inputs only for the RUCC heterogeneity script.
- Reduced-form scripts mostly write versioned `.pdf`, `.tex`, `.csv`, `.png`, or `.jpeg` outputs under `3_outputs`, and comments should state when versioning is automatic.

Change note: This ExecPlan was created because the reduced-form scripts are currently hard to review. The plan chooses a parse-tree invariance standard so the future execution can materially improve readability while remaining strictly comment-only.
