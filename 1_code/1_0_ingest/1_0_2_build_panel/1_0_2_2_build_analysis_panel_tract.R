#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_2_2_build_analysis_panel_tract.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 21, 2026
# Description:      Merge the review-stage annual ACS tract controls and county
#                   wages onto the tract-year pre-covariate panel through
#                   `2019` and write the review-stage tract analysis panel plus
#                   a summary artifact.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`
#                   `2_1_acs/2_1_9_acs_tract_2010_2020_covariates.rds`
# OUTPUTS:          `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`
#                   `2_9_analysis/2_9_7_us_analysis_panel_tract_timevarying_summary.rds`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

library(dplyr)
library(tibble)

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)

  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))))
  }

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(active_path)) {
      return(dirname(normalizePath(active_path)))
    }
  }

  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) {
      return(dirname(normalizePath(frame$ofile)))
    }
  }

  normalizePath(getwd())
})

source(file.path(script_dir, "shared_ingest_helpers.R"))

# -----------------------------
# 1) Read paths and processed inputs
# -----------------------------

repo_root <- get_repo_root()
setwd(repo_root)

processed_root <- read_root_path("2_processed_data/processed_root.txt")
processed_analysis_dir <- ensure_dir(file.path(processed_root, "2_9_analysis"))

tract_pre_cov_path <- file.path(processed_root, "2_9_analysis", "2_9_3_us_analysis_panel_tract_pre_covariates.rds")
tract_covariate_path <- file.path(processed_root, "2_1_acs", "2_1_9_acs_tract_2010_2020_covariates.rds")
county_panel_path <- file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds")

tract_pre_cov_panel <- readRDS(tract_pre_cov_path)
tract_covariates <- readRDS(tract_covariate_path)
county_panel <- readRDS(county_panel_path)

# -----------------------------
# 2) Prepare the county wage input and merge tract controls
# -----------------------------

# --- Reuse the benchmark county wage series so tract and county panels align

county_wages <- county_panel |>
  transmute(
    county_fips = normalize_fips(county_fips),
    year = as.integer(year),
    wage = as.numeric(wage),
    wage_st = as.numeric(wage_st)
  ) |>
  distinct()

# --- Keep the reviewed annual-ACS exclusion list explicit and remove those
# tracts from the Milestone 2 tract panel rather than counting them as generic
# covariate missingness.

annual_acs_exclusion_table <- tract_covariates |>
  filter(annual_acs_explicit_exclusion %in% TRUE) |>
  distinct(
    tract_fips,
    county_fips,
    annual_acs_exclusion_group,
    annual_acs_exclusion_reason
  )

tract_pre_cov_panel_included <- tract_pre_cov_panel |>
  mutate(
    tract_fips = stringr::str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
    year = as.integer(year)
  ) |>
  filter(year <= 2019L) |>
  filter(!(tract_fips %in% annual_acs_exclusion_table$tract_fips))

# --- Extend the tract pre-covariate panel with annual tract controls and wages

analysis_panel_tract <- tract_pre_cov_panel_included |>
  left_join(
    tract_covariates |>
      mutate(
        tract_fips = stringr::str_pad(tract_fips, width = 11, side = "left", pad = "0"),
        county_fips = normalize_fips(county_fips),
        year = as.integer(year),
        acs_source_year = as.integer(acs_source_year),
        acs_2010_backfill = as.logical(acs_2010_backfill)
      ),
    by = c("tract_fips", "county_fips", "year")
  ) |>
  left_join(county_wages, by = c("county_fips", "year")) |>
  mutate(
    state = as.integer(substr(county_fips, 1, 2))
  ) |>
  arrange(tract_fips, year)

# -----------------------------
# 3) Build the review-stage tract panel summary
# -----------------------------

# --- Summarize the annual ACS merge and the documented `2010` backfill on the
# curtailed `2000:2019` tract-year panel.

analysis_panel_summary <- tibble(
  rows = nrow(analysis_panel_tract),
  panel_tracts = dplyr::n_distinct(analysis_panel_tract$tract_fips),
  treated_tracts = dplyr::n_distinct(analysis_panel_tract$tract_fips[analysis_panel_tract$treated]),
  excluded_tracts = nrow(annual_acs_exclusion_table),
  excluded_tracts_94xx_ai_area_associated =
    sum(annual_acs_exclusion_table$annual_acs_exclusion_group == "94xx_ai_area_associated", na.rm = TRUE),
  excluded_tracts_other_acs_nonreturn =
    sum(annual_acs_exclusion_table$annual_acs_exclusion_group == "other_acs_nonreturn", na.rm = TRUE),
  excluded_panel_rows = nrow(tract_pre_cov_panel) - nrow(analysis_panel_tract),
  min_year = min(analysis_panel_tract$year, na.rm = TRUE),
  max_year = max(analysis_panel_tract$year, na.rm = TRUE),
  acs_source_year_min = min(analysis_panel_tract$acs_source_year, na.rm = TRUE),
  acs_source_year_max = max(analysis_panel_tract$acs_source_year, na.rm = TRUE),
  pre_2010_backfill_rows = sum(analysis_panel_tract$acs_2010_backfill %in% TRUE, na.rm = TRUE),
  post_2010_timevarying_rows = sum(analysis_panel_tract$acs_2010_backfill %in% FALSE, na.rm = TRUE),
  missing_meanInc = sum(is.na(analysis_panel_tract$meanInc)),
  missing_income = sum(is.na(analysis_panel_tract$income)),
  missing_urate = sum(is.na(analysis_panel_tract$urate)),
  missing_population = sum(is.na(analysis_panel_tract$population)),
  missing_rent = sum(is.na(analysis_panel_tract$rent)),
  missing_wage = sum(is.na(analysis_panel_tract$wage)),
  missing_wage_st = sum(is.na(analysis_panel_tract$wage_st)),
  missing_meanInc_pre_2010 = sum(is.na(analysis_panel_tract$meanInc) & analysis_panel_tract$year < 2010),
  missing_meanInc_2010_2019 = sum(is.na(analysis_panel_tract$meanInc) & analysis_panel_tract$year >= 2010),
  missing_income_pre_2010 = sum(is.na(analysis_panel_tract$income) & analysis_panel_tract$year < 2010),
  missing_income_2010_2019 = sum(is.na(analysis_panel_tract$income) & analysis_panel_tract$year >= 2010),
  missing_urate_pre_2010 = sum(is.na(analysis_panel_tract$urate) & analysis_panel_tract$year < 2010),
  missing_urate_2010_2019 = sum(is.na(analysis_panel_tract$urate) & analysis_panel_tract$year >= 2010),
  missing_population_pre_2010 = sum(is.na(analysis_panel_tract$population) & analysis_panel_tract$year < 2010),
  missing_population_2010_2019 = sum(is.na(analysis_panel_tract$population) & analysis_panel_tract$year >= 2010),
  missing_rent_pre_2010 = sum(is.na(analysis_panel_tract$rent) & analysis_panel_tract$year < 2010),
  missing_rent_2010_2019 = sum(is.na(analysis_panel_tract$rent) & analysis_panel_tract$year >= 2010),
  missing_wage_pre_2010 = sum(is.na(analysis_panel_tract$wage) & analysis_panel_tract$year < 2010),
  missing_wage_2010_2019 = sum(is.na(analysis_panel_tract$wage) & analysis_panel_tract$year >= 2010)
)

# -----------------------------
# 4) Save, close out
# -----------------------------

saveRDS(
  analysis_panel_tract,
  file.path(processed_analysis_dir, "2_9_6_us_analysis_panel_tract_timevarying_covariates.rds")
)
saveRDS(
  analysis_panel_summary,
  file.path(processed_analysis_dir, "2_9_7_us_analysis_panel_tract_timevarying_summary.rds")
)

print(analysis_panel_summary)
