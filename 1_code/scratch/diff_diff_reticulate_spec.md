# `diff-diff` nonlinear DID via `reticulate`: practical spec

## Goal

Use the Python `diff-diff` package as the nonlinear staggered DID engine, while keeping the surrounding workflow in R as much as possible through `reticulate`.

The motivation is to avoid hand-rolling staggered nonlinear DID aggregations if the Python package already provides a supported estimator plus built-in event/group/calendar/simple aggregation methods.

## Recommended estimator family

Based on the official `diff-diff` docs, the relevant nonlinear staggered estimator is `WooldridgeDiD`.

Why this is the right target:

- it is the package's documented estimator for nonlinear DID settings
- it supports staggered adoption
- it includes built-in aggregation rather than requiring us to code that ourselves

For our use cases, the likely mappings are:

- county count outcome: `WooldridgeDiD(..., method="poisson")`
- tract binary entry outcome: `WooldridgeDiD(..., method="logit")`

## Current local environment status

As of 2026-05-22:

- conda env exists: `snap_dollar_entry`
- Python in that env works: `Python 3.13.5`
- `diff-diff` is **not** currently installed in that env
- R package `reticulate` is **not** currently installed

That means a `reticulate` bridge is feasible, but not immediately runnable without one Python install step and one R install step.

## What would need to be installed

### Python side

Install `diff-diff` into the `snap_dollar_entry` conda env.

Representative command:

    conda run -n snap_dollar_entry python -m pip install diff-diff

If the package has compiled dependencies or version restrictions, those should be checked after install by importing:

    conda run -n snap_dollar_entry python -c "import diff_diff"

### R side

Install `reticulate` in the R library used by `/usr/local/bin/Rscript`.

Representative command from R:

    install.packages("reticulate")

## Proposed repository architecture

Keep Python isolated to a narrow bridge layer and continue doing the upstream sample construction and downstream formatting in R.

Recommended split:

- R builds the analysis-ready panel
- `reticulate` hands the panel to Python
- Python `diff-diff` estimates the nonlinear staggered DID
- R receives the resulting event-study and summary tables back for plotting and export

This preserves most of the current repository style while avoiding a fully separate Python pipeline.

## Minimal R-to-Python bridge pattern

In an R script or `.qmd`, the bridge would look roughly like this:

1. Point `reticulate` at the conda env:

       reticulate::use_condaenv("snap_dollar_entry", required = TRUE)

2. Import Python modules:

       diff_diff <- reticulate::import("diff_diff")
       pd <- reticulate::import("pandas")

3. Build the R data frame using the current pipeline logic.

4. Convert the R data frame to a pandas DataFrame.

5. Instantiate the estimator and fit it.

6. Pull the aggregated outputs back into R as ordinary data frames.

## Data contract we would need

The panel handed to `diff-diff` should be explicit and clean. At minimum, we would need:

- unit identifier
  county branch: `county_fips`
  tract branch: tract identifier
- calendar time
  likely `year`
- outcome
  count branch: `total_ds` or other outlet count
  tract branch: binary entry indicator
- treatment cohort / first treatment period
  one column giving first treated year
- covariates, if we want adjusted specifications
  likely the same benchmark controls already used in the county branch

We should avoid passing the benchmark Sun-Abraham sentinel timing conventions directly into Python without cleaning them first. A Python estimator should receive an explicit cohort variable, not placeholders like `10000`.

## Estimation workflow we would want

### County nonlinear count branch

1. Rebuild the county sample in R from the processed analysis panel.
2. Construct an explicit first-treatment cohort variable.
3. Pass the panel to Python.
4. Fit `WooldridgeDiD` with the Poisson method.
5. Use the package's built-in aggregation methods to get:
   - event-study aggregation
   - group aggregation
   - calendar aggregation
   - overall/simple ATT
6. Return those outputs to R for plotting and table export.

### Tract nonlinear binary branch

1. Build the tract panel in R.
2. Construct a binary entry outcome and first-treatment cohort variable.
3. Pass the panel to Python.
4. Fit `WooldridgeDiD` with the logit method.
5. Use the package's built-in aggregations.
6. Return the outputs to R for standard repo-style artifacts.

## Why this route is attractive

- It avoids writing our own nonlinear staggered aggregation layer.
- It keeps the data-cleaning logic in the existing R pipeline.
- It lets us preserve repo-consistent output generation in R.
- It narrows Python exposure to one estimator bridge rather than a full workflow rewrite.

## Main implementation risks

### Environment risk

`reticulate` is not installed and `diff-diff` is not installed. The first implementation step is therefore environment setup, not estimation.

### Python version risk

The local conda env is on Python `3.13.5`. If `diff-diff` has not been tested on `3.13`, installation or runtime compatibility may become an issue. If that happens, the clean fallback is to create a dedicated conda env with a more common supported version, likely `3.10` or `3.11`, and point `reticulate` there instead.

### Object-shape risk

Before wiring this into the main repo, we should run one small scratch prototype and inspect the exact object structure returned by `WooldridgeDiD` and its aggregation methods. We should not assume the returned tables already match the plotting format used in the current reduced-form scripts.

## Recommended prototype sequence

The safest sequence is:

1. Install `diff-diff` in `snap_dollar_entry` conda env.
2. Install `reticulate` in R.
3. Build a tiny scratch `.qmd` that:
   - connects to the conda env
   - imports `diff_diff`
   - fits one toy model on simulated data
   - prints the fitted object and aggregation outputs
4. Only after that succeeds, wire the bridge into county or tract pipeline scripts.

## Bottom line

If the package works as documented, `diff-diff` plus `reticulate` is the cleanest way to stay mostly in R while avoiding manual nonlinear staggered DID aggregation code.

The immediate blockers are not conceptual. They are environment setup and one scratch-level prototype to confirm:

- installation works in the local conda env
- the nonlinear estimator behaves as expected
- the aggregation outputs can be pulled back into R cleanly
