#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_1_2_ACS_prep.R
# Previous author:  Alejandro Herrera
# Current author:   Alejandro Herrera + Codex
# Last Updated:     March 22, 2026
# Description:      Pull county-scope ACS 5-year controls for each year
#                   `2010:2019`, build a year-specific county covariate file on
#                   the full `2000:2019` county-year grid, backfill `2000:2009`
#                   with the `2010` ACS 5-year values, and write county ACS
#                   diagnostics for the contiguous U.S. plus Washington, D.C.
# INPUTS:           `0_inputs/input_root.txt`
#                   `0_inputs/census_apikey.md`
#                   `2_processed_data/processed_root.txt`
#                   `0_3_county_list/national_county.txt`
# OUTPUTS:          `2_1_acs/2_1_11_acs_county_2010_2019_raw.rds`
#                   `2_1_acs/2_1_12_acs_county_2000_2019_covariates.rds`
#                   `2_1_acs/2_1_13_acs_county_2000_2019_summary.rds`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(tibble)
library(tidyr)
library(tidycensus)

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
source(file.path(dirname(script_dir), "tract_ingest_helpers.R"))

read_census_api_key <- function(path) {
  key <- readLines(path, warn = FALSE) |>
    trimws()

  key <- key[key != ""]

  if (!length(key)) {
    stop("`0_inputs/census_apikey.md` is empty.")
  }

  key[[1]]
}

safe_ratio <- function(num, den) {
  if_else(is.na(den) | den == 0, NA_real_, as.numeric(num) / as.numeric(den))
}

pull_county_acs <- function(variables, year, survey) {
  tidycensus::get_acs(
    geography = "county",
    variables = variables,
    year = year,
    survey = survey,
    geometry = FALSE,
    output = "wide",
    cache_table = TRUE
  )
}

get_employment_variable_sets <- function(year) {
  acs_variable_catalog <- tidycensus::load_variables(year, "acs5", cache = TRUE)

  if (all(c("B23025_003", "B23025_005") %in% acs_variable_catalog$name)) {
    return(list(
      method = "B23025",
      denominator_variables = "B23025_003",
      numerator_variables = "B23025_005"
    ))
  }

  employment_denominator_variables <- acs_variable_catalog |>
    filter(
      str_starts(name, "B23001_"),
      str_detect(label, fixed("Civilian labor force")) |
        str_detect(label, fixed("In labor force!!Civilian"))
    ) |>
    filter(!str_detect(label, fixed("Employed")), !str_detect(label, fixed("Unemployed"))) |>
    pull(name)

  employment_numerator_variables <- acs_variable_catalog |>
    filter(
      str_starts(name, "B23001_"),
      str_detect(label, fixed("In labor force!!Civilian!!Unemployed"))
    ) |>
    pull(name)

  if (!length(employment_denominator_variables) || !length(employment_numerator_variables)) {
    stop(sprintf(
      "Could not identify county-available `B23001` employment-status variables for %s ACS.",
      year
    ))
  }

  list(
    method = "B23001",
    denominator_variables = employment_denominator_variables,
    numerator_variables = employment_numerator_variables
  )
}

build_annual_county_acs_outputs <- function(acs_year, county_scope) {
  employment_variables <- get_employment_variable_sets(acs_year)

  detailed_variables <- unique(c(
    "B20002_001",
    "B11001_001",
    "B25064_001",
    employment_variables$denominator_variables,
    employment_variables$numerator_variables
  ))

  employment_denominator_estimate_columns <- paste0(employment_variables$denominator_variables, "E")
  employment_numerator_estimate_columns <- paste0(employment_variables$numerator_variables, "E")

  acs_detailed_raw <- pull_county_acs(
    variables = detailed_variables,
    year = acs_year,
    survey = "acs5"
  )

  acs_raw_scope_year <- county_scope |>
    left_join(
      acs_detailed_raw |>
        mutate(county_fips = str_pad(GEOID, width = 5, side = "left", pad = "0")),
      by = "county_fips"
    )

  acs_raw_scope_year <- acs_raw_scope_year |>
    mutate(
      DP03_0063E = NA_real_,
      DP03_0063M = NA_real_
    )

  county_covariates_year <- acs_raw_scope_year |>
    transmute(
      county_fips,
      state_fips,
      state_abbrev,
      year = as.integer(acs_year),
      acs_source_year = as.integer(acs_year),
      acs_2010_backfill = FALSE,
      B20002_001E = as.numeric(B20002_001E),
      B11001_001E = as.numeric(B11001_001E),
      B25064_001E = as.numeric(B25064_001E),
      CIVILIAN_LF_E = rowSums(across(all_of(employment_denominator_estimate_columns)), na.rm = TRUE),
      UNEMPLOYED_E = rowSums(across(all_of(employment_numerator_estimate_columns)), na.rm = TRUE),
      unemployment_source_method = employment_variables$method,
      DP03_0063E = as.numeric(DP03_0063E),
      totalHH = as.numeric(B11001_001E),
      meanInc = as.numeric(B20002_001E),
      medianInc = NA_real_,
      income = as.numeric(B20002_001E),
      urate = safe_ratio(UNEMPLOYED_E, CIVILIAN_LF_E),
      population = as.numeric(B11001_001E),
      rent = as.numeric(B25064_001E),
      dp03_0063_available = !is.na(DP03_0063E)
    )

  county_match_summary_year <- tibble(
    year = as.integer(acs_year),
    scope_counties = n_distinct(county_scope$county_fips),
    raw_pull_rows = nrow(acs_detailed_raw),
    joined_scope_counties = sum(!is.na(acs_raw_scope_year$GEOID)),
    unjoined_scope_counties = sum(is.na(acs_raw_scope_year$GEOID)),
    counties_with_nonmissing_meanInc_inputs = sum(!is.na(acs_raw_scope_year$B20002_001E)),
    counties_with_missing_meanInc_inputs = sum(is.na(acs_raw_scope_year$B20002_001E)),
    unemployment_source_method = employment_variables$method,
    meanInc_definition = "B20002_001E",
    income_definition = "B20002_001E",
    rent_definition = "B25064_001E",
    population_definition = "B11001_001E",
    dp03_0063_available_counties = sum(county_covariates_year$dp03_0063_available, na.rm = TRUE),
    missing_meanInc = sum(is.na(county_covariates_year$meanInc)),
    missing_income = sum(is.na(county_covariates_year$income)),
    missing_urate = sum(is.na(county_covariates_year$urate)),
    missing_population = sum(is.na(county_covariates_year$population)),
    missing_rent = sum(is.na(county_covariates_year$rent))
  )

  list(
    raw = acs_raw_scope_year |>
      mutate(
        year = as.integer(acs_year),
        acs_source_year = as.integer(acs_year)
      ),
    covariates = county_covariates_year,
    summary = county_match_summary_year
  )
}

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

acs_output_dir <- ensure_dir(file.path(processed_root, "2_1_acs"))
api_key_path <- file.path(repo_root, "0_inputs", "census_apikey.md")
existing_county_panel_path <- file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds")

excluded_state_fips <- c("02", "15", "60", "66", "69", "72", "74", "78")

state_lookup <- prepare_county_crosswalk(input_root) |>
  make_state_lookup()

county_scope <- readRDS(existing_county_panel_path) |>
  transmute(
    county_fips = normalize_fips(county_fips),
    state_fips = substr(county_fips, 1, 2)
  ) |>
  distinct(county_fips, state_fips) |>
  filter(!(state_fips %in% excluded_state_fips)) |>
  left_join(state_lookup, by = "state_fips") |>
  arrange(county_fips)

if (any(is.na(county_scope$state_abbrev))) {
  stop("County ACS scope has missing `state_abbrev` values after joining the state lookup.")
}

acs_years <- 2010:2019
panel_years <- 2000:2019
backfill_years <- 2000:2009

Sys.setenv(CENSUS_API_KEY = read_census_api_key(api_key_path))

annual_acs_outputs <- map(
  acs_years,
  build_annual_county_acs_outputs,
  county_scope = county_scope
)

acs_raw_scope <- map_dfr(annual_acs_outputs, "raw") |>
  arrange(county_fips, year)

annual_county_covariates <- map_dfr(annual_acs_outputs, "covariates") |>
  arrange(county_fips, year)

annual_match_summary <- map_dfr(annual_acs_outputs, "summary") |>
  arrange(year)

county_covariates_backfill <- annual_county_covariates |>
  filter(year == 2010L) |>
  select(-year) |>
  tidyr::crossing(year = backfill_years) |>
  mutate(
    year = as.integer(year),
    acs_source_year = 2010L,
    acs_2010_backfill = TRUE
  )

county_covariates <- bind_rows(county_covariates_backfill, annual_county_covariates) |>
  arrange(county_fips, year)

county_match_summary <- annual_match_summary |>
  mutate(
    covariate_rows = nrow(county_covariates),
    pre_2010_backfill_rows = nrow(county_covariates_backfill),
    pre_2010_backfill_year_start = min(backfill_years),
    pre_2010_backfill_year_end = max(backfill_years),
    pre_2010_backfill_source_year = 2010L,
    panel_year_start = min(panel_years),
    panel_year_end = max(panel_years)
  )

saveRDS(acs_raw_scope, file.path(acs_output_dir, "2_1_11_acs_county_2010_2019_raw.rds"))
saveRDS(county_covariates, file.path(acs_output_dir, "2_1_12_acs_county_2000_2019_covariates.rds"))
saveRDS(county_match_summary, file.path(acs_output_dir, "2_1_13_acs_county_2000_2019_summary.rds"))

print(county_match_summary)
