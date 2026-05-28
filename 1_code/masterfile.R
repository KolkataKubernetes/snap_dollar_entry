rm(list=ls())
# Directories
git_root <- dirname(dirname(rstudioapi::getActiveDocumentContext()$path))
code_root <- file.path(git_root, "1_code")
ingest_root <- file.path(code_root, "1_0_ingest")
descriptives_root <- file.path(code_root, "1_1_descriptives")
reduced_form_root <- file.path(code_root, "1_2_reduced_form")
setwd(git_root)
if (.Platform$OS.type == "windows") {
  box_root <- "C:/Users/aleja/Box/SNAP Dollar Entry/"
} else {
  box_root <- "/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry"
}

# 1. Ingest
source(file.path(ingest_root, "1_0_0_waivers", "1_0_0_0_SNAP_waiver_ingest.R"))
source(file.path(ingest_root, "1_0_0_waivers", "1_0_0_1_waiver_ingest.R"))
source(file.path(ingest_root, "1_0_0_waivers", "1_0_0_2_waiver_geographies_to_tracts.R")) 
source(file.path(ingest_root, "1_0_1_covariates", "1_0_1_0_SNAP_retailer_ingest.R"))
source(file.path(ingest_root, "1_0_1_covariates", "1_0_1_1_unemployment_rates.R"))
source(file.path(ingest_root, "1_0_1_covariates", "1_0_1_2_ACS_prep.R"))
source(file.path(ingest_root, "1_0_1_covariates", "1_0_1_3_SNAP_retailer_tract_panel.R"))
source(file.path(ingest_root, "1_0_1_covariates", "1_0_1_4_ACS_tract_prep.R"))
source(file.path(ingest_root, "1_0_2_build_panel", "1_0_2_0_build_analysis_panel.R"))
source(file.path(ingest_root, "1_0_2_build_panel", "1_0_2_1_build_analysis_panel_tract_pre_covariates.R"))
source(file.path(ingest_root, "1_0_2_build_panel", "1_0_2_2_build_analysis_panel_tract.R"))

# 2. Descriptives
source(file.path(descriptives_root, "1_1_0_waivers", "1_1_0_0_county_conferral_growth_rural_share.R"))
source(file.path(descriptives_root, "1_1_0_waivers", "1_1_0_1_ds_stock_trend_by_waiver.R"))
source(file.path(descriptives_root, "1_1_0_waivers", "1_1_0_2_ever_waived_county_map.R"))
source(file.path(descriptives_root, "1_1_0_waivers", "1_1_0_3_tract_conferral_growth_rural_share.R"))
source(file.path(descriptives_root, "1_1_0_waivers", "1_1_0_4_ever_waived_tract_map_tract.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_0_retailer_format_stock_index.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_1_retailer_format_stock_index_rural.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_2_snap_retailer_composition_flipped.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_3_snap_retailer_composition.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_4_retail_format_pre_post.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_5_ds_stock_growth_by_treatment_status.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_6_snap_retailer_composition_ever_treated.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_7_ds_stock_change_map_2010_2019.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_8_retail_format_pre_post_single_series.R"))
source(file.path(descriptives_root, "1_1_1_retailers", "1_1_1_9_retailer_format_stock_index_tract.R"))
source(file.path(descriptives_root, "1_1_2_manuscript_tables", "1_1_2_0_descriptive_stats_table.R"))

# 3. Reduced Form
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_0_desc_stats", "1_2_0_0_1_desc_stats_outcomes.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_0_build_event_study_sample.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_1_event_study_total_ds.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_2_event_study_chain_super_market.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_3_event_study_chain_convenience_store.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_4_event_study_chain_multi_category.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_5_event_study_chain_medium_grocery.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_6_event_study_chain_small_grocery.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_7_event_study_chain_produce.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_8_event_study_chain_farmers_market.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_9_event_study_all_table.R"))
source(file.path(reduced_form_root, "1_2_0_county", "1_2_0_1_regs", "1_2_11_event_study_all_table_image.R"))
source(file.path(reduced_form_root, "isolated", "1_2_11_event_study_total_ds_never_treated_control.R"))
source(file.path(reduced_form_root, "isolated", "1_2_12_compare_total_ds_control_groups.R"))
#source(file.path(reduced_form_root, "isolated", "1_2_13_honestdid_total_ds_control_groups.R"))
source(file.path(reduced_form_root, "isolated", "1_2_14_compare_total_ds_control_groups_table_image.R"))
