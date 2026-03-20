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

- `0_inputs/`: Pointer file for the external raw-input root.
- `1_code/`: Pipeline-defining R scripts and shared helpers.
- `1_code/1_0_ingest/`: Ingest and panel-construction scripts run by `--stage ingest`.
- `1_code/1_1_descriptives/`: Descriptive figure and companion-table scripts run by `--stage descriptives`.
- `1_code/1_2_reduced_form/`: Reduced-form sample, estimation, and export scripts run by `--stage reduced_form`.
- `1_code/1_2_reduced_form/isolated/`: Standalone reduced-form sensitivity scripts that are checked in but not called by `1_code/run_refactor_pipeline.R`.
- `1_code/shared_ingest_helpers.R`: Shared pathing and utility helpers for the ingest stage.
- `2_processed_data/`: Pointer file for the external processed-data root used by the pipeline.
- `3_outputs/`: Repo-local figures, tables, and output pointer files.
- `agent-docs/`: Planning documents, execution plans, and maintainer notes.
- `legacy/`: Legacy benchmark code and reference artifacts.

### Data Definitions, Location and Pathing

- `0_inputs/input_root.txt`: Text pointer to the external raw-input root.
- `2_processed_data/processed_root.txt`: Text pointer to the external processed-data root.
- `3_outputs/output_root.txt`: Text pointer for output-root configuration.

`1_code/run_refactor_pipeline.R` discovers stage scripts directly inside each stage directory, sorts them lexicographically, and skips files whose names start with `shared_`.

Ingest and reduced-form scripts resolve external data through the pointer files above rather than hardcoded user paths.

## Pipeline Summary

### Pipeline Order (High-Level)

1. `1_code/1_0_ingest/`: Writes processed waiver, SNAP, ACS, unemployment, and analysis-panel artifacts under the path referenced by `2_processed_data/processed_root.txt`.
2. `1_code/1_1_descriptives/`: Reads processed pipeline artifacts and writes repo-local descriptive figures and companion `.csv` files under `3_outputs/3_1_descriptives/`.
3. `1_code/1_2_reduced_form/`: Writes the processed event-study sample under the processed-data root and writes repo-local reduced-form figures and tables under `3_outputs/3_2_reduced_form/` and `3_outputs/tables/`.

## Scripts and Outputs

### Ingest Scripts

- `1_code/1_0_ingest/1_0_0_SNAP_waiver_ingest.R`: Builds the consolidated wide waiver artifacts.
- `1_code/1_0_ingest/1_0_0b_waiver_ingest.R`: Standardizes waiver geographies and writes the long waiver-panel artifacts used downstream.
- `1_code/1_0_ingest/1_0_1_SNAP_retailer_ingest.R`: Cleans SNAP retailer data and writes the cleaned retailer file plus the county-year store-count panel.
- `1_code/1_0_ingest/1_0_2_unemployment_rates.R`: Writes the processed unemployment artifact used by the merged analysis panel.
- `1_code/1_0_ingest/1_0_3_ACS_prep.R`: Writes the processed ACS, population, and ACS appendix artifacts used by the panel builder.
- `1_code/1_0_ingest/1_0_4_build_analysis_panel.R`: Rebuilds the benchmark county-year analysis panel and companion summary artifact used by the descriptive and reduced-form stages.
- `1_code/shared_ingest_helpers.R`: Shared pathing and utility helpers for ingest scripts.

### Descriptive Scripts

- `1_code/1_1_descriptives/1_1_0_retailer_format_stock_index.R`: Creates the all-county retailer format stock index figure. It computes a 2010-based stock index across retail formats and saves the descriptive figure.
- `1_code/1_1_descriptives/1_1_1_retailer_format_stock_index_rural.R`: Creates the rural-county retailer format stock index figure. It applies the same stock-index construction to the rural subset only.
- `1_code/1_1_descriptives/1_1_2_county_conferral_growth_rural_share.R`: Creates the county waiver counts over time figure split by rural, urban, and total counties. It aggregates county-level waiver coverage by year and rural status.
- `1_code/1_1_descriptives/1_1_3_retail_format_pre_post.R`: Creates the treated-county pre/post retail format growth figure split by rural versus non-rural counties. It summarizes treatment-period changes by retail format.
- `1_code/1_1_descriptives/1_1_4_ds_stock_trend_by_waiver.R`: Creates the dollar-store stock trend figure by ever-waived county status. It compares average dollar-store stock paths for waived versus never-waived counties.
- `1_code/1_1_descriptives/1_1_5_snap_retailer_composition.R`: Writes the SNAP retailer composition figure and companion `.csv`.
- `1_code/1_1_descriptives/1_1_6_snap_retailer_composition_ever_treated.R`: Writes the SNAP retailer composition figure and companion `.csv` split by ever-treated status.
- `1_code/1_1_descriptives/1_1_7_snap_retailer_composition_flipped.R`: Writes the flipped-layout SNAP retailer composition figure and companion `.csv`.
- `1_code/1_1_descriptives/1_1_8_ds_stock_change_map_2010_2019.R`: Writes the county map of 2010-2019 dollar-store stock change and companion `.csv`.
- `1_code/1_1_descriptives/1_1_9_ever_waived_county_map.R`: Writes the county map of ever-waived status and companion `.csv`.
- `1_code/1_1_descriptives/1_1_10_retail_format_pre_post_single_series.R`: Writes the single-series treated-county pre/post retail-format growth figure and companion `.csv`.
- `1_code/1_1_descriptives/1_1_11_ds_stock_growth_by_treatment_status.R`: Writes the dollar-store stock-growth figure by treatment status and companion `.csv`.
- `1_code/1_1_descriptives/shared_us_analysis_helpers.R`: Shared loaders, output paths, and reusable objects for descriptive scripts.

### Reduced Form Scripts

- `1_code/1_2_reduced_form/1_2_0_build_event_study_sample.R`: Writes the processed event-study sample from the benchmark analysis panel.
- `1_code/1_2_reduced_form/1_2_1_event_study_total_ds.R`: Writes the total-dollar-store event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_2_event_study_chain_super_market.R`: Writes the supermarket event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_3_event_study_chain_convenience_store.R`: Writes the convenience-store event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_4_event_study_chain_multi_category.R`: Writes the multi-category event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_5_event_study_chain_medium_grocery.R`: Writes the medium-grocery event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_6_event_study_chain_small_grocery.R`: Writes the small-grocery event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_7_event_study_chain_produce.R`: Writes the produce event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_8_event_study_chain_farmers_market.R`: Writes the farmers-market event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_9_event_study_all_table.R`: Writes the combined ATT table across the reduced-form outcomes.
- `1_code/1_2_reduced_form/1_2_10_desc_stats_outcomes.R`: Writes the reduced-form outcome summary-statistics table.
- `1_code/1_2_reduced_form/1_2_11_event_study_all_table_image.R`: Writes image exports of the combined ATT table plus a companion `.csv`.
- `1_code/1_2_reduced_form/shared_reduced_form_helpers.R`: Shared loaders, model wrappers, and export helpers for reduced-form scripts. Main reduced-form scripts use non-destructive filename versioning (`_v01`, `_v02`, and so on) when a target output already exists.

### Output Files and Directories

- External processed-data root, as referenced by `2_processed_data/processed_root.txt`
  - `2_0_waivers/2_0_0_waiver_data_consolidated_generated.rds`
  - `2_0_waivers/2_0_2_waived_data_consolidated_long_generated.rds`
  - `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
  - `2_1_acs/2_1_0_unemployment.rds`
  - `2_1_acs/2_1_1_acs_2012_2020.rds`
  - `2_1_acs/2_1_2_population.rds`
  - `2_1_acs/2_1_3_Append_CountyDP03.rds`
  - `2_1_acs/2_1_4_Append_CountyDP04.rds`
  - `2_5_SNAP/2_5_0_snap_clean.rds`
  - `2_5_SNAP/2_5_1_store_count.rds`
  - `2_9_analysis/2_9_0_us_analysis_panel.rds`
  - `2_9_analysis/2_9_1_us_analysis_panel_summary.rds`
  - `2_9_analysis/2_9_2_event_study_sample.rds`
- `3_outputs/3_1_descriptives/`
  - `3_1_0_retailer_format_stock_index.jpeg`
  - `3_1_1_retailer_format_stock_index_rural.jpeg`
  - `3_1_2_county_conferral_growth_rural_share.jpeg`
  - `3_1_3_retail_format_pre_post.jpeg`
  - `3_1_4_ds_stock_trend_by_waiver.jpeg`
  - `3_1_5_snap_retailer_composition.{csv,jpeg}`
  - `3_1_6_snap_retailer_composition_ever_treated.{csv,jpeg}`
  - `3_1_7_snap_retailer_composition_flipped.{csv,jpeg}`
  - `3_1_8_ds_stock_change_map_2010_2019.{csv,jpeg}`
  - `3_1_9_ever_waived_county_map.{csv,jpeg}`
  - `3_1_10_retail_format_pre_post_single_series.{csv,jpeg}`
  - `3_1_11_ds_stock_growth_by_treatment_status.{csv,jpeg}`
- `3_outputs/3_2_reduced_form/`
  - `3_2_1_event_study_ihs_total_ds.pdf`
  - `3_2_2_event_study_ihs_chain_super_market.pdf`
  - `3_2_3_event_study_ihs_chain_convenience_store.pdf`
  - `3_2_4_event_study_ihs_chain_multi_category.pdf`
  - `3_2_5_event_study_ihs_chain_medium_grocery.pdf`
  - `3_2_6_event_study_ihs_chain_small_grocery.pdf`
  - `3_2_7_event_study_ihs_chain_produce.pdf`
  - `3_2_8_event_study_ihs_chain_farmers_market.pdf`
  - `3_2_11_event_study_ihs_all_table.{png,jpeg}`
  - Reruns of reduced-form figure exports may append `_v01`, `_v02`, and so on to avoid overwriting existing files.
- `3_outputs/tables/`
  - `3_2_1_event_study_ihs_total_ds.tex`
  - `3_2_2_event_study_ihs_chain_super_market.tex`
  - `3_2_3_event_study_ihs_chain_convenience_store.tex`
  - `3_2_4_event_study_ihs_chain_multi_category.tex`
  - `3_2_5_event_study_ihs_chain_medium_grocery.tex`
  - `3_2_6_event_study_ihs_chain_small_grocery.tex`
  - `3_2_7_event_study_ihs_chain_produce.tex`
  - `3_2_8_event_study_ihs_chain_farmers_market.tex`
  - `3_2_9_event_study_ihs_all.tex`
  - `3_2_10_desc_stats_outcomes.tex`
  - `3_2_11_event_study_ihs_all_table.csv`
  - Reruns of reduced-form table exports may append `_v01`, `_v02`, and so on to avoid overwriting existing files.

### TEMP/TEST Outputs

- `1_code/1_2_reduced_form/isolated/1_2_11_event_study_total_ds_never_treated_control.R`: Writes isolated never-treated-control sensitivity outputs under `3_outputs/3_2_reduced_form/` and `3_outputs/tables/` using the `3_2_11_event_study_ihs_total_ds_never_treated_control*` filename family.
- `1_code/1_2_reduced_form/isolated/1_2_12_compare_total_ds_control_groups.R`: Writes isolated control-group comparison outputs using the `3_2_12_event_study_ihs_total_ds_compare_controls*` filename family.
- `1_code/1_2_reduced_form/isolated/1_2_13_honestdid_total_ds_control_groups.R`: Writes isolated HonestDiD sensitivity outputs using the `3_2_13_honestdid_total_ds_*` filename family.
- `1_code/1_2_reduced_form/isolated/1_2_14_compare_total_ds_control_groups_table_image.R`: Writes isolated table-image comparison outputs using the `3_2_14_event_study_ihs_total_ds_compare_controls_table*` filename family.

## Versioning and Change Log

- `2026-03-19`: Updated the README mechanically to match the completed pipeline inventory, including the additional descriptive scripts, the `1_2_11` reduced-form table-image script, the processed-data artifacts written under `processed_root.txt`, and the separation of `isolated/` sensitivity scripts into `TEMP/TEST Outputs`.
- `2026-03-16`: Added a pipeline-runner preamble for `1_code/run_refactor_pipeline.R` and populated the README with mechanical inventory, pathing, pipeline-order, and output-directory documentation.
- `2026-03-16`: Expanded the script inventory with file-level descriptions based on code preambles and clarified the behavior of `--dry-run` in the pipeline runner section.
