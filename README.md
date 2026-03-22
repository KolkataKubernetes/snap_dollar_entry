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
- `1_code/1_0_ingest/1_0_0_waivers/`: Waiver ingest scripts and waiver-ingest helpers.
- `1_code/1_0_ingest/1_0_1_covariates/`: SNAP retailer, unemployment, ACS, and tract retailer ingest scripts plus covariate-ingest helpers.
- `1_code/1_0_ingest/1_0_2_build_panel/`: County and tract panel-construction scripts plus build-panel helpers.
- `1_code/1_1_descriptives/`: Descriptive figure and companion-table scripts run by `--stage descriptives`.
- `1_code/1_1_descriptives/1_1_0_waivers/`: Waiver descriptive scripts and waiver descriptive helpers.
- `1_code/1_1_descriptives/1_1_1_retailers/`: Retailer descriptive scripts and retailer descriptive helpers.
- `1_code/1_2_reduced_form/`: Reduced-form sample, estimation, and export scripts run by `--stage reduced_form`.
- `1_code/1_2_reduced_form/1_2_0_county/`: County reduced-form scripts and helpers that are called by the pipeline runner.
- `1_code/1_2_reduced_form/isolated/`: Standalone reduced-form sensitivity scripts that are checked in but not called by `1_code/run_refactor_pipeline.R`.
- `1_code/1_0_ingest/shared_ingest_helpers.R`: Shared pathing and utility helpers for the ingest stage.
- `1_code/1_0_ingest/tract_ingest_helpers.R`: Shared tract-ingest helpers used by the tract waiver, retailer, and panel scripts.
- `2_processed_data/`: Pointer file for the external processed-data root used by the pipeline.
- `3_outputs/`: Repo-local figures, tables, and output pointer files.
- `agent-docs/`: Planning documents, execution plans, and maintainer notes.
- `legacy/`: Legacy benchmark code and reference artifacts.

### Data Definitions, Location and Pathing

- `0_inputs/input_root.txt`: Text pointer to the external raw-input root.
- `2_processed_data/processed_root.txt`: Text pointer to the external processed-data root.
- `3_outputs/output_root.txt`: Text pointer for output-root configuration.

`1_code/run_refactor_pipeline.R` discovers stage scripts recursively inside each stage directory, sorts them by numeric filename prefix, and skips files whose names start with `shared_`.

Ingest and reduced-form scripts resolve external data through the pointer files above rather than hardcoded user paths.

## Pipeline Summary

### Pipeline Order (High-Level)

1. `1_code/1_0_ingest/`: Writes processed waiver, SNAP, ACS, unemployment, county-panel, and tract-panel artifacts under the path referenced by `2_processed_data/processed_root.txt`.
2. `1_code/1_1_descriptives/`: Reads processed pipeline artifacts and writes repo-local descriptive figures and companion `.csv` files under `3_outputs/3_1_descriptives/`.
3. `1_code/1_2_reduced_form/`: Writes the processed event-study sample under the processed-data root and writes repo-local reduced-form figures and tables under `3_outputs/3_2_reduced_form/` and `3_outputs/3_0_tables/`.

## Scripts and Outputs

### Ingest Scripts

- `1_code/1_0_ingest/1_0_0_waivers/1_0_0_0_SNAP_waiver_ingest.R`: Builds the consolidated wide waiver artifacts.
- `1_code/1_0_ingest/1_0_0_waivers/1_0_0_1_waiver_ingest.R`: Standardizes waiver geographies and writes the long waiver-panel artifacts used downstream.
- `1_code/1_0_ingest/1_0_0_waivers/1_0_0_2_waiver_geographies_to_tracts.R`: Expands the live waiver long panel to tract identifiers and writes tract-match diagnostics.
- `1_code/1_0_ingest/1_0_0_waivers/shared_ingest_helpers.R`: Waiver-ingest helper file used inside the waiver ingest subdirectory.
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_0_SNAP_retailer_ingest.R`: Cleans SNAP retailer data and writes the cleaned retailer file plus the county-year store-count panel.
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_1_unemployment_rates.R`: Writes the processed unemployment artifact used by the merged analysis panel.
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_2_ACS_prep.R`: Writes the processed ACS, population, and ACS appendix artifacts used by the county panel builder.
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_panel.R`: Assigns cleaned SNAP retailer rows to tracts and writes tract retailer diagnostics plus tract-year store counts.
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_4_ACS_tract_prep.R`: Pulls review-stage annual ACS 5-year tract covariates for retained ACS years `2010:2019`, writes tract-level annual ACS diagnostics, and builds the review-stage tract covariate sidecar artifacts.
- `1_code/1_0_ingest/1_0_1_covariates/shared_ingest_helpers.R`: Covariate-ingest helper file used inside the covariates subdirectory.
- `1_code/1_0_ingest/1_0_1_covariates/1_0_1_3_SNAP_retailer_tract_matching.md`: Maintainer note documenting the state-first SNAP retailer tract-matching workflow and diagnostics.
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_0_build_analysis_panel.R`: Rebuilds the benchmark county-year analysis panel and companion summary artifact used by the descriptive and reduced-form stages.
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_1_build_analysis_panel_tract_pre_covariates.R`: Builds the tract-year analysis panel through the treatment and retailer-outcome layers, before tract covariates are merged.
- `1_code/1_0_ingest/1_0_2_build_panel/1_0_2_2_build_analysis_panel_tract.R`: Merges review-stage tract ACS covariates onto the tract-year panel and writes review-stage tract panel sidecar artifacts and summaries.
- `1_code/1_0_ingest/1_0_2_build_panel/shared_ingest_helpers.R`: Build-panel helper file used inside the panel subdirectory.
- `1_code/1_0_ingest/shared_ingest_helpers.R`: Shared pathing and utility helpers for ingest scripts.
- `1_code/1_0_ingest/tract_ingest_helpers.R`: Shared tract-ingest helpers for tract scope loading, geometry access, and geography-name normalization.

### Current Tract ACS Exclusions Used by the 2019-Bounded Sidecar Branch

The current review-stage annual ACS tract branch uses a small explicit `2011:2019` mismatch set as tract exclusions in the retained `2019`-bounded sidecar outputs.

- `15` unmatched tract IDs are in the Census `94xx` tract-code class associated with American Indian area tract coding rather than ordinary county-based tract numbering: `36053940101`, `36053940102`, `36053940103`, `36053940200`, `36053940300`, `36053940401`, `36053940403`, `36053940600`, `36053940700`, `36065940000`, `36065940100`, `36065940200`, `46113940500`, `46113940800`, and `46113940900`.
- `11` additional unmatched tract IDs are ordinary-looking `2010` tract IDs that the annual ACS pull does not return in `2011:2019`: `02270000100`, `04019002701`, `04019002903`, `04019410501`, `04019410502`, `04019410503`, `04019470400`, `04019470500`, `06037930401`, `36085008900`, and `51515050100`.
- The Census tract-code rationale for distinguishing these groups comes from the [Federal Register tract criteria](https://www2.census.gov/geo/pdfs/reference/fedreg/tract_criteria.pdf) and the [2010 Census PL 94-171 Technical Documentation](https://www2.census.gov/programs-surveys/decennial/2010/technical-documentation/complete-tech-docs/summary-file/pl94-171.pdf). In those sources, `94xx` codes are tied to American Indian area-associated tract coding, while `98xx` codes are the special land-use tract class and `99xx` codes are water-only tracts.
- The review-stage sidecar filenames retain the `_2010_2020_` stems for continuity, but the current retained sidecar contents stop at `2019`.

### Descriptive Scripts

- `1_code/1_1_descriptives/1_1_0_waivers/1_1_0_0_county_conferral_growth_rural_share.R`: Writes the county waiver-counts-over-time figure.
- `1_code/1_1_descriptives/1_1_0_waivers/1_1_0_1_ds_stock_trend_by_waiver.R`: Writes the dollar-store stock trend figure by ever-waived county status.
- `1_code/1_1_descriptives/1_1_0_waivers/1_1_0_2_ever_waived_county_map.R`: Writes the county map of ever-waived status and a companion `.csv`.
- `1_code/1_1_descriptives/1_1_0_waivers/1_1_0_3_tract_conferral_growth_rural_share.R`: Writes the tract waiver-counts-over-time figure from the tract waiver source.
- `1_code/1_1_descriptives/1_1_0_waivers/shared_us_analysis_helpers.R`: Waiver descriptive helper file used inside the waiver descriptive subdirectory.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_0_retailer_format_stock_index.R`: Writes the all-county retailer format stock-index figure.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_1_retailer_format_stock_index_rural.R`: Writes the rural-county retailer format stock-index figure.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_2_snap_retailer_composition_flipped.R`: Writes the flipped-layout SNAP retailer composition figure and companion `.csv`.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_3_snap_retailer_composition.R`: Writes the SNAP retailer composition figure and companion `.csv`.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_4_retail_format_pre_post.R`: Writes the treated-county pre/post retail-format growth figure.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_5_ds_stock_growth_by_treatment_status.R`: Writes the dollar-store stock-growth figure by treatment status and companion `.csv`.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_6_snap_retailer_composition_ever_treated.R`: Writes the SNAP retailer composition figure split by ever-treated status.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_7_ds_stock_change_map_2010_2019.R`: Writes the county map of 2010-2019 dollar-store stock change and companion `.csv`.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_8_retail_format_pre_post_single_series.R`: Writes the single-series treated-county pre/post retail-format growth figure.
- `1_code/1_1_descriptives/1_1_1_retailers/1_1_1_9_retailer_format_stock_index_tract.R`: Writes the tract retailer format stock-index figure.
- `1_code/1_1_descriptives/1_1_1_retailers/shared_us_analysis_helpers.R`: Retailer descriptive helper file used inside the retailer descriptive subdirectory.
- `1_code/1_1_descriptives/shared_us_analysis_helpers.R`: Shared descriptive helper file at the stage root.

### Reduced Form Scripts

- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/1_2_0_0_1_desc_stats_outcomes.R`: Writes the county reduced-form outcome summary-statistics table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_0_desc_stats/shared_reduced_form_helpers.R`: Shared helper file for the county reduced-form descriptive-statistics subdirectory.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_0_build_event_study_sample.R`: Writes the processed county event-study sample from the benchmark analysis panel.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_1_event_study_total_ds.R`: Writes the total-dollar-store event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_2_event_study_chain_super_market.R`: Writes the supermarket event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_3_event_study_chain_convenience_store.R`: Writes the convenience-store event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_4_event_study_chain_multi_category.R`: Writes the multi-category event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_5_event_study_chain_medium_grocery.R`: Writes the medium-grocery event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_6_event_study_chain_small_grocery.R`: Writes the small-grocery event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_7_event_study_chain_produce.R`: Writes the produce event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_8_event_study_chain_farmers_market.R`: Writes the farmers-market event-study figure and companion `.tex` table.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_9_event_study_all_table.R`: Writes the combined ATT table across the county reduced-form outcomes.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/1_2_11_event_study_all_table_image.R`: Writes image exports of the combined ATT table plus a companion `.csv`.
- `1_code/1_2_reduced_form/1_2_0_county/1_2_0_1_regs/shared_reduced_form_helpers.R`: Shared helper file for the county reduced-form regression subdirectory.
- `1_code/1_2_reduced_form/1_2_0_county/shared_reduced_form_helpers.R`: Shared helper file at the county reduced-form root.

### Output Files and Directories

- External processed-data root, as referenced by `2_processed_data/processed_root.txt`
  - `2_0_waivers/2_0_0_waiver_data_consolidated_generated.rds`
  - `2_0_waivers/2_0_2_waived_data_consolidated_long_generated.rds`
  - `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
  - `2_0_waivers/2_0_6_waiver_geography_to_tract_crosswalk.rds`
  - `2_0_waivers/2_0_7_waived_data_consolidated_long_tract.rds`
  - `2_0_waivers/2_0_8_waiver_tract_match_diagnostics.rds`
  - `2_1_acs/2_1_0_unemployment.rds`
  - `2_1_acs/2_1_1_acs_2012_2020.rds`
  - `2_1_acs/2_1_2_population.rds`
  - `2_1_acs/2_1_3_Append_CountyDP03.rds`
  - `2_1_acs/2_1_4_Append_CountyDP04.rds`
  - `2_1_acs/2_1_5_acs_tract_2010_raw.rds`
  - `2_1_acs/2_1_6_acs_tract_2010_covariates.rds`
  - `2_1_acs/2_1_7_acs_tract_match_summary.rds`
  - `2_1_acs/2_1_8_acs_tract_2010_2020_raw.rds`
  - `2_1_acs/2_1_9_acs_tract_2010_2020_covariates.rds`
  - `2_1_acs/2_1_10_acs_tract_2010_2020_match_summary.rds`
  - `2_5_SNAP/2_5_0_snap_clean.rds`
  - `2_5_SNAP/2_5_1_store_count.rds`
  - `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds`
  - `2_5_SNAP/2_5_3_store_count_tract.rds`
  - `2_5_SNAP/2_5_4_snap_tract_match_diagnostics.rds`
  - `2_9_analysis/2_9_0_us_analysis_panel.rds`
  - `2_9_analysis/2_9_1_us_analysis_panel_summary.rds`
  - `2_9_analysis/2_9_2_event_study_sample.rds`
  - `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`
  - `2_9_analysis/2_9_4_us_analysis_panel_tract.rds`
  - `2_9_analysis/2_9_5_us_analysis_panel_tract_summary.rds`
  - `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`
  - `2_9_analysis/2_9_7_us_analysis_panel_tract_timevarying_summary.rds`
- `3_outputs/3_1_descriptives/`
  - `3_1_0_waivers/`
  - `3_1_1_retailers/`
- `3_outputs/3_2_reduced_form/`
  - `3_2_0_county/3_2_0_0_desc_stats/`
  - `3_2_0_county/3_2_0_1_regs/`
  - `isolated/`
  - Reruns of reduced-form figure exports may append `_v01`, `_v02`, and so on to avoid overwriting existing files.
- `3_outputs/3_0_tables/`
  - `3_2_0_county/3_2_0_0_desc_stats/`
  - `3_2_0_county/3_2_0_1_regs/`
  - `isolated/`
  - Reruns of reduced-form table exports may append `_v01`, `_v02`, and so on to avoid overwriting existing files.

### TEMP/TEST Outputs

- `1_code/1_2_reduced_form/isolated/1_2_11_event_study_total_ds_never_treated_control.R`: Writes isolated never-treated-control sensitivity outputs under `3_outputs/3_2_reduced_form/isolated/` and `3_outputs/3_0_tables/isolated/` using the `3_2_11_event_study_ihs_total_ds_never_treated_control*` filename family.
- `1_code/1_2_reduced_form/isolated/1_2_12_compare_total_ds_control_groups.R`: Writes isolated control-group comparison outputs using the `3_2_12_event_study_ihs_total_ds_compare_controls*` filename family.
- `1_code/1_2_reduced_form/isolated/1_2_13_honestdid_total_ds_control_groups.R`: Writes isolated HonestDiD sensitivity outputs using the `3_2_13_honestdid_total_ds_*` filename family.
- `1_code/1_2_reduced_form/isolated/1_2_14_compare_total_ds_control_groups_table_image.R`: Writes isolated table-image comparison outputs using the `3_2_14_event_study_ihs_total_ds_compare_controls_table*` filename family.

## Versioning and Change Log

- `2026-03-21`: Updated the README mechanically to close out the current tract ExecPlan state: the tract ACS sidecar inventory now reflects the retained `2019` endpoint, the tract ACS exclusion note now matches the explicit exclusion set used in the retained sidecars, and the two initial tract descriptive scripts are now listed in the descriptive inventory.
- `2026-03-20`: Updated the README mechanically to reflect the segmented ingest/descriptive/reduced-form paths now checked into `1_code/`, added the tract ingest files and tract processed artifacts created in Milestone 1, and added the tract retailer matching note in `1_code/1_0_ingest/1_0_1_covariates/`.
- `2026-03-21`: Updated the README mechanically to add the tract ACS and tract final-panel scripts, the review-stage annual ACS tract sidecar artifacts, and the current documented annual-ACS tract exclusion set with the Census source URLs used to classify the `94xx` tract-code cases.
- `2026-03-19`: Updated the README mechanically to match the completed pipeline inventory, including the additional descriptive scripts, the `1_2_11` reduced-form table-image script, the processed-data artifacts written under `processed_root.txt`, and the separation of `isolated/` sensitivity scripts into `TEMP/TEST Outputs`.
- `2026-03-16`: Added a pipeline-runner preamble for `1_code/run_refactor_pipeline.R` and populated the README with mechanical inventory, pathing, pipeline-order, and output-directory documentation.
- `2026-03-16`: Expanded the script inventory with file-level descriptions based on code preambles and clarified the behavior of `--dry-run` in the pipeline runner section.
