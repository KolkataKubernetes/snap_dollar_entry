# SNAP Dollar Entry

## Pipeline Runner

Use `1_code/run_refactor_pipeline.R` as the entrypoint for the refactored pipeline.

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
- `1_code/1_0_ingest/1_0_0b_waiver_ingest.R`: Standardizes waiver geographies and writes long-panel waiver artifacts plus comparison outputs.
- `1_code/1_0_ingest/1_0_1_SNAP_retailer_ingest.R`: Cleans SNAP retailer data and writes retailer-level and county-year store-count artifacts.
- `1_code/1_0_ingest/1_0_2_unemployment_rates.R`: Writes the unemployment panel used downstream.
- `1_code/1_0_ingest/1_0_3_ACS_prep.R`: Writes ACS-derived processed artifacts used downstream.
- `1_code/1_0_ingest/1_0_4_build_analysis_panel.R`: Merges processed inputs into the analysis-ready panel.
- `1_code/1_0_ingest/shared_ingest_helpers.R`: Shared pathing and utility helpers used by ingest scripts.

### Visualization Scripts

- `1_code/1_1_descriptives/1_1_0_retailer_format_stock_index.R`
- `1_code/1_1_descriptives/1_1_1_retailer_format_stock_index_rural.R`
- `1_code/1_1_descriptives/1_1_2_county_conferral_growth_rural_share.R`
- `1_code/1_1_descriptives/1_1_3_retail_format_pre_post.R`
- `1_code/1_1_descriptives/1_1_4_ds_stock_trend_by_waiver.R`
- `1_code/1_1_descriptives/shared_us_analysis_helpers.R`: Shared loaders, output paths, and reusable objects for descriptive scripts.

### Transform/Clean Scripts

- `1_code/1_2_reduced_form/1_2_0_build_event_study_sample.R`
- `1_code/1_2_reduced_form/1_2_1_event_study_total_ds.R`
- `1_code/1_2_reduced_form/1_2_2_event_study_chain_super_market.R`
- `1_code/1_2_reduced_form/1_2_3_event_study_chain_convenience_store.R`
- `1_code/1_2_reduced_form/1_2_4_event_study_chain_multi_category.R`
- `1_code/1_2_reduced_form/1_2_5_event_study_chain_medium_grocery.R`
- `1_code/1_2_reduced_form/1_2_6_event_study_chain_small_grocery.R`
- `1_code/1_2_reduced_form/1_2_7_event_study_chain_produce.R`
- `1_code/1_2_reduced_form/1_2_8_event_study_chain_farmers_market.R`
- `1_code/1_2_reduced_form/1_2_9_event_study_all_table.R`
- `1_code/1_2_reduced_form/1_2_10_desc_stats_outcomes.R`
- `1_code/1_2_reduced_form/shared_reduced_form_helpers.R`: Shared loaders, model wrappers, and export helpers for reduced-form scripts.

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
