# SNAP Dollar Entry

## Pipeline Runner

Use `1_code/run_refactor_pipeline.R` as the entrypoint for the refactored pipeline.

- `--dry-run` prints the repository root, the requested stage(s), and the exact scripts that would run, then exits without executing any stage scripts or writing outputs.
- `--stage <stage>` runs only the requested stage. `--stage all` runs ingest, descriptives, and reduced-form in sequence.

Basic commands:

```sh
Rscript 1_code/run_refactor_pipeline.R --dry-run
Rscript 1_code/run_refactor_pipeline.R --stage ingest
Rscript 1_code/run_refactor_pipeline.R --stage descriptives
Rscript 1_code/run_refactor_pipeline.R --stage reduced_form
Rscript 1_code/run_refactor_pipeline.R --stage all
```

Accepted stages:
- `ingest`
- `descriptives`
- `reduced_form`
- `all`

This repository is conditionally reproducible given access to external input data referenced via `input_root.txt`.

## Repository Orientation

### High-Level Structure

- `1_code/`: Pipeline-defining R scripts and shared helpers.
- `1_code/1_0_ingest/`: Ingest and panel-construction scripts.
- `1_code/1_1_descriptives/`: Descriptive output scripts.
- `1_code/1_2_reduced_form/`: Reduced-form sample and estimation scripts.
- `2_processed_data/`: Pointer file for the processed-data root used by the pipeline.
- `3_outputs/`: Repo-local figures, tables, and output pointer files.
- `agent-docs/`: Planning documents, execution plans, and maintainer notes.
- `legacy/`: Legacy benchmark code and reference artifacts.

### Data Definitions, Location and Pathing

- `0_inputs/input_root.txt`: Text pointer to the external raw-input root.
- `2_processed_data/processed_root.txt`: Text pointer to the external processed-data root.
- `3_outputs/output_root.txt`: Text pointer for output-root configuration.

The ingest scripts resolve external data through the pointer files above rather than hardcoded user paths.

## Pipeline Summary

### Pipeline Order (High-Level)

1. `1_code/1_0_ingest/`
2. `1_code/1_1_descriptives/`
3. `1_code/1_2_reduced_form/`

## Scripts and Outputs

### Ingest Scripts

- `1_code/1_0_ingest/1_0_0_SNAP_waiver_ingest.R`: Builds the consolidated wide waiver artifacts.
- `1_code/1_0_ingest/1_0_0b_waiver_ingest.R`: Standardizes waiver geographies and writes the long waiver panel used by the U.S. benchmark analysis. It also saves benchmark comparison artifacts for the waiver lineage.
- `1_code/1_0_ingest/1_0_1_SNAP_retailer_ingest.R`: Cleans the SNAP retailer locator data and standardizes county geography. It writes retailer-level cleaned data and the county-year store-count panel used downstream.
- `1_code/1_0_ingest/1_0_2_unemployment_rates.R`: Promotes the benchmark unemployment panel into the processed-data layout. It writes the unemployment artifact consumed by the merged analysis panel.
- `1_code/1_0_ingest/1_0_3_ACS_prep.R`: Promotes ACS and population inputs into the processed-data layout. It writes the processed ACS and population artifacts used by the panel builder.
- `1_code/1_0_ingest/1_0_4_build_analysis_panel.R`: Reproduces the benchmark county-year analysis panel for the U.S. descriptives and reduced-form pipeline. It merges waiver, SNAP, ACS, prices, wages, population, and unemployment inputs.
- `1_code/1_0_ingest/shared_ingest_helpers.R`: Shared pathing and utility helpers for ingest scripts. It resolves the repo root, reads root-pointer text files, normalizes FIPS codes, and creates output directories.

### Descriptive Scripts

- `1_code/1_1_descriptives/1_1_0_retailer_format_stock_index.R`: Creates the all-county retailer format stock index figure. It computes a 2010-based stock index across retail formats and saves the descriptive figure.
- `1_code/1_1_descriptives/1_1_1_retailer_format_stock_index_rural.R`: Creates the rural-county retailer format stock index figure. It applies the same stock-index construction to the rural subset only.
- `1_code/1_1_descriptives/1_1_2_county_conferral_growth_rural_share.R`: Creates the county waiver counts over time figure split by rural, urban, and total counties. It aggregates county-level waiver coverage by year and rural status.
- `1_code/1_1_descriptives/1_1_3_retail_format_pre_post.R`: Creates the treated-county pre/post retail format growth figure split by rural versus non-rural counties. It summarizes treatment-period changes by retail format.
- `1_code/1_1_descriptives/1_1_4_ds_stock_trend_by_waiver.R`: Creates the dollar-store stock trend figure by ever-waived county status. It compares average dollar-store stock paths for waived versus never-waived counties.
- `1_code/1_1_descriptives/shared_us_analysis_helpers.R`: Shared loaders, output paths, and reusable objects for descriptive scripts. It assembles the descriptive context from the processed analysis panel, waiver panel, store counts, and RUCC data.

### Reduced Form Scripts

- `1_code/1_2_reduced_form/1_2_0_build_event_study_sample.R`: Builds the event-study estimation sample from the processed benchmark analysis panel. It applies the benchmark sample restrictions and writes the reduced-form sample artifact.
- `1_code/1_2_reduced_form/1_2_1_event_study_total_ds.R`: Estimates and exports the event-study results for total dollar stores. It writes both the figure and the companion regression table.
- `1_code/1_2_reduced_form/1_2_2_event_study_chain_super_market.R`: Estimates and exports the event-study results for supermarkets. It writes the supermarket figure and table artifacts.
- `1_code/1_2_reduced_form/1_2_3_event_study_chain_convenience_store.R`: Estimates and exports the event-study results for convenience stores. It writes the convenience-store figure and table artifacts.
- `1_code/1_2_reduced_form/1_2_4_event_study_chain_multi_category.R`: Estimates and exports the event-study results for multi-category retailers. It writes the multi-category figure and table artifacts.
- `1_code/1_2_reduced_form/1_2_5_event_study_chain_medium_grocery.R`: Estimates and exports the event-study results for medium grocery stores. It writes the medium-grocery figure and table artifacts.
- `1_code/1_2_reduced_form/1_2_6_event_study_chain_small_grocery.R`: Estimates and exports the event-study results for small grocery stores. It writes the small-grocery figure and table artifacts.
- `1_code/1_2_reduced_form/1_2_7_event_study_chain_produce.R`: Estimates and exports the event-study results for produce retailers. It writes the produce figure and table artifacts.
- `1_code/1_2_reduced_form/1_2_8_event_study_chain_farmers_market.R`: Estimates and exports the event-study results for farmers markets. It writes the farmers-market figure and table artifacts.
- `1_code/1_2_reduced_form/1_2_9_event_study_all_table.R`: Combines the reduced-form event-study models into a single summary table. It writes the multi-outcome ATT table artifact.
- `1_code/1_2_reduced_form/1_2_10_desc_stats_outcomes.R`: Produces the descriptive statistics table for the reduced-form outcome variables. It writes the LaTeX summary-statistics table used with the reduced-form outputs.
- `1_code/1_2_reduced_form/shared_reduced_form_helpers.R`: Shared loaders, model wrappers, and export helpers for reduced-form scripts. It centralizes event-study sample loading, model specification, labeling, and figure/table export paths.

### Output Files and Directories

- `3_outputs/3_1_descriptives/`
  - `3_1_0_retailer_format_stock_index.jpeg`
  - `3_1_1_retailer_format_stock_index_rural.jpeg`
  - `3_1_2_county_conferral_growth_rural_share.jpeg`
  - `3_1_3_retail_format_pre_post.jpeg`
  - `3_1_4_ds_stock_trend_by_waiver.jpeg`
- `3_outputs/3_2_reduced_form/`
  - `3_2_1_event_study_ihs_total_ds.pdf`
  - `3_2_2_event_study_ihs_chain_super_market.pdf`
  - `3_2_3_event_study_ihs_chain_convenience_store.pdf`
  - `3_2_4_event_study_ihs_chain_multi_category.pdf`
  - `3_2_5_event_study_ihs_chain_medium_grocery.pdf`
  - `3_2_6_event_study_ihs_chain_small_grocery.pdf`
  - `3_2_7_event_study_ihs_chain_produce.pdf`
  - `3_2_8_event_study_ihs_chain_farmers_market.pdf`
- `3_outputs/tables/`
  - `3_2_10_desc_stats_outcomes.tex`
  - `3_2_1_event_study_ihs_total_ds.tex`
  - `3_2_2_event_study_ihs_chain_super_market.tex`
  - `3_2_3_event_study_ihs_chain_convenience_store.tex`
  - `3_2_4_event_study_ihs_chain_multi_category.tex`
  - `3_2_5_event_study_ihs_chain_medium_grocery.tex`
  - `3_2_6_event_study_ihs_chain_small_grocery.tex`
  - `3_2_7_event_study_ihs_chain_produce.tex`
  - `3_2_8_event_study_ihs_chain_farmers_market.tex`
  - `3_2_9_event_study_ihs_all.tex`

### TEMP/TEST Outputs

- No `TEMP` scripts are currently listed as pipeline-defining scripts in `1_code/`.

## Versioning and Change Log

- `2026-03-16`: Added a pipeline-runner preamble for `1_code/run_refactor_pipeline.R` and populated the README with mechanical inventory, pathing, pipeline-order, and output-directory documentation.
- `2026-03-16`: Expanded the script inventory with file-level descriptions based on code preambles and clarified the behavior of `--dry-run` in the pipeline runner section.
