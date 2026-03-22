#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_1_4_ACS_tract_prep.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 21, 2026
# Description:      Pull tract-scope ACS 5-year controls for each year
#                   `2010:2019`, build a year-specific tract covariate file on
#                   the full `2000:2019` tract-year grid, backfill `2000:2009`
#                   with the `2010` ACS 5-year values, and write review-stage
#                   annual-ACS sidecar diagnostics.
# INPUTS:           `0_inputs/input_root.txt`
#                   `0_inputs/census_apikey.md`
#                   `2_processed_data/processed_root.txt`
#                   local tract shapefiles under `0_8_geographies/`
# OUTPUTS:          `2_1_acs/2_1_8_acs_tract_2010_2020_raw.rds`
#                   `2_1_acs/2_1_9_acs_tract_2010_2020_covariates.rds`
#                   `2_1_acs/2_1_10_acs_tract_2010_2020_match_summary.rds`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

library(dplyr)
library(purrr)
library(readr)
library(sf)
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

# -----------------------------
# 1) Helper functions
# -----------------------------

# --- Read the local Census API key without embedding it in script source

read_census_api_key <- function(path) {
  key <- readLines(path, warn = FALSE) |>
    trimws()

  key <- key[key != ""]

  if (!length(key)) {
    stop("`0_inputs/census_apikey.md` is empty.")
  }

  key[[1]]
}

# --- Avoid dividing by zero when tract numerators and denominators are merged

safe_ratio <- function(num, den) {
  if_else(is.na(den) | den == 0, NA_real_, as.numeric(num) / as.numeric(den))
}

# --- Keep the reviewed annual-ACS exclusion set explicit rather than relying on
# aggregate unmatched counts alone.

annual_acs_explicit_exclusions <- bind_rows(
  tibble(
    tract_fips = c(
      "36053940101", "36053940102", "36053940103", "36053940200",
      "36053940300", "36053940401", "36053940403", "36053940600",
      "36053940700", "36065940000", "36065940100", "36065940200",
      "46113940500", "46113940800", "46113940900"
    ),
    annual_acs_exclusion_group = "94xx_ai_area_associated",
    annual_acs_exclusion_reason = paste(
      "Reviewed 2011:2019 mismatch case. The tract code falls in the Census",
      "`94xx` class associated with American Indian area tract coding rather",
      "than ordinary county-based tract numbering."
    )
  ),
  tibble(
    tract_fips = c(
      "02270000100", "04019002701", "04019002903", "04019410501",
      "04019410502", "04019410503", "04019470400", "04019470500",
      "06037930401", "36085008900", "51515050100"
    ),
    annual_acs_exclusion_group = "other_acs_nonreturn",
    annual_acs_exclusion_reason = paste(
      "Reviewed 2011:2019 mismatch case. This 2010-scope tract ID is not",
      "returned by the annual ACS tract pull and is carried as an explicit",
      "ACS non-return rather than being force-matched."
    )
  )
) |>
  mutate(
    annual_acs_exclusion_source_1 =
      "https://www2.census.gov/geo/pdfs/reference/fedreg/tract_criteria.pdf",
    annual_acs_exclusion_source_2 = paste0(
      "https://www2.census.gov/programs-surveys/decennial/2010/",
      "technical-documentation/complete-tech-docs/summary-file/pl94-171.pdf"
    )
  )

# --- Pull one ACS product state by state so the tract query remains tractable

pull_state_acs <- function(states, variables, year, survey) {
  map_dfr(
    states,
    function(state_abbrev) {
      tidycensus::get_acs(
        geography = "tract",
        variables = variables,
        year = year,
        survey = survey,
        state = state_abbrev,
        geometry = FALSE,
        output = "wide",
        cache_table = TRUE
      )
    }
  )
}

# --- Derive tract unemployment from `B23025` when available and otherwise
# fall back to tract-available `B23001` cells.

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
      "Could not identify tract-available `B23001` employment-status variables for %s ACS.",
      year
    ))
  }

  list(
    method = "B23001",
    denominator_variables = employment_denominator_variables,
    numerator_variables = employment_numerator_variables
  )
}

# --- Pull one ACS year, restrict it to tract scope, and build tract controls

build_annual_acs_outputs <- function(acs_year, tract_scope, scope_states) {
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

  acs_detailed_raw <- pull_state_acs(
    states = scope_states,
    variables = detailed_variables,
    year = acs_year,
    survey = "acs5"
  )

  acs_dp03_raw <- tryCatch(
    pull_state_acs(
      states = scope_states,
      variables = "DP03_0063",
      year = acs_year,
      survey = "acs5/profile"
    ),
    error = function(e) {
      warning(sprintf("DP03_0063 tract pull failed for %s: %s", acs_year, e$message))
      NULL
    }
  )

  acs_raw_scope_year <- tract_scope |>
    left_join(annual_acs_explicit_exclusions, by = "tract_fips") |>
    mutate(
      annual_acs_explicit_exclusion = !is.na(annual_acs_exclusion_group)
    ) |>
    left_join(
      acs_detailed_raw |>
        mutate(tract_fips = str_pad(GEOID, width = 11, side = "left", pad = "0")),
      by = "tract_fips"
    )

  if (!is.null(acs_dp03_raw)) {
    acs_raw_scope_year <- acs_raw_scope_year |>
      left_join(
        acs_dp03_raw |>
          mutate(tract_fips = str_pad(GEOID, width = 11, side = "left", pad = "0")) |>
          transmute(
            tract_fips,
            DP03_0063E = as.numeric(DP03_0063E),
            DP03_0063M = as.numeric(DP03_0063M)
          ),
        by = "tract_fips"
      )
  } else {
    acs_raw_scope_year <- acs_raw_scope_year |>
      mutate(
        DP03_0063E = NA_real_,
        DP03_0063M = NA_real_
      )
  }

  tract_covariates_year <- acs_raw_scope_year |>
    transmute(
      tract_fips,
      county_fips,
      state_fips,
      state_abbrev,
      year = as.integer(acs_year),
      acs_source_year = as.integer(acs_year),
      acs_2010_backfill = FALSE,
      annual_acs_explicit_exclusion,
      annual_acs_exclusion_group,
      annual_acs_exclusion_reason,
      annual_acs_exclusion_source_1,
      annual_acs_exclusion_source_2,
      B20002_001E = as.numeric(B20002_001E),
      B11001_001E = as.numeric(B11001_001E),
      B25064_001E = as.numeric(B25064_001E),
      CIVILIAN_LF_E = rowSums(across(all_of(employment_denominator_estimate_columns)), na.rm = TRUE),
      UNEMPLOYED_E = rowSums(across(all_of(employment_numerator_estimate_columns)), na.rm = TRUE),
      unemployment_source_method = employment_variables$method,
      DP03_0063E = as.numeric(DP03_0063E),
      meanInc = as.numeric(B20002_001E),
      income = as.numeric(B20002_001E),
      urate = safe_ratio(UNEMPLOYED_E, CIVILIAN_LF_E),
      population = as.numeric(B11001_001E),
      rent = as.numeric(B25064_001E),
      dp03_0063_available = !is.na(DP03_0063E)
    )

  tract_match_summary_year <- tibble(
    year = as.integer(acs_year),
    scope_tracts = n_distinct(tract_scope$tract_fips),
    explicitly_excluded_scope_tracts =
      sum(acs_raw_scope_year$annual_acs_explicit_exclusion, na.rm = TRUE),
    explicitly_excluded_94xx_ai_area_associated =
      sum(acs_raw_scope_year$annual_acs_exclusion_group == "94xx_ai_area_associated", na.rm = TRUE),
    explicitly_excluded_other_acs_nonreturn =
      sum(acs_raw_scope_year$annual_acs_exclusion_group == "other_acs_nonreturn", na.rm = TRUE),
    raw_pull_rows = nrow(acs_detailed_raw),
    joined_scope_tracts = sum(!is.na(acs_raw_scope_year$GEOID)),
    unjoined_scope_tracts = sum(is.na(acs_raw_scope_year$GEOID)),
    joined_nonexcluded_scope_tracts = sum(
      !is.na(acs_raw_scope_year$GEOID) & !acs_raw_scope_year$annual_acs_explicit_exclusion,
      na.rm = TRUE
    ),
    unjoined_nonexcluded_scope_tracts = sum(
      is.na(acs_raw_scope_year$GEOID) & !acs_raw_scope_year$annual_acs_explicit_exclusion,
      na.rm = TRUE
    ),
    tracts_with_nonmissing_meanInc_inputs = sum(!is.na(acs_raw_scope_year$B20002_001E)),
    tracts_with_missing_meanInc_inputs = sum(is.na(acs_raw_scope_year$B20002_001E)),
    unemployment_source_method = employment_variables$method,
    meanInc_definition = "B20002_001E",
    income_definition = "B20002_001E",
    rent_definition = "B25064_001E",
    dp03_0063_available_tracts = sum(tract_covariates_year$dp03_0063_available, na.rm = TRUE),
    missing_meanInc = sum(is.na(tract_covariates_year$meanInc)),
    missing_meanInc_nonexcluded = sum(
      is.na(tract_covariates_year$meanInc) & !tract_covariates_year$annual_acs_explicit_exclusion,
      na.rm = TRUE
    ),
    missing_income = sum(is.na(tract_covariates_year$income)),
    missing_income_nonexcluded = sum(
      is.na(tract_covariates_year$income) & !tract_covariates_year$annual_acs_explicit_exclusion,
      na.rm = TRUE
    ),
    missing_urate = sum(is.na(tract_covariates_year$urate)),
    missing_urate_nonexcluded = sum(
      is.na(tract_covariates_year$urate) & !tract_covariates_year$annual_acs_explicit_exclusion,
      na.rm = TRUE
    ),
    missing_population = sum(is.na(tract_covariates_year$population)),
    missing_population_nonexcluded = sum(
      is.na(tract_covariates_year$population) & !tract_covariates_year$annual_acs_explicit_exclusion,
      na.rm = TRUE
    ),
    missing_rent = sum(is.na(tract_covariates_year$rent)),
    missing_rent_nonexcluded = sum(
      is.na(tract_covariates_year$rent) & !tract_covariates_year$annual_acs_explicit_exclusion,
      na.rm = TRUE
    )
  )

  list(
    raw = acs_raw_scope_year |>
      mutate(
        year = as.integer(acs_year),
        acs_source_year = as.integer(acs_year)
      ),
    covariates = tract_covariates_year,
    summary = tract_match_summary_year
  )
}

# -----------------------------
# 2) Read paths, tract scope, and ACS year sets
# -----------------------------

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

acs_output_dir <- ensure_dir(file.path(processed_root, "2_1_acs"))
api_key_path <- file.path(repo_root, "0_inputs", "census_apikey.md")

tract_scope <- load_scope_tracts(input_root, processed_root) |>
  st_drop_geometry() |>
  mutate(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
    state_fips = substr(county_fips, 1, 2)
  ) |>
  distinct(tract_fips, county_fips, state_fips, state_abbrev)

scope_states <- sort(unique(tract_scope$state_abbrev))
acs_years <- 2010:2019
panel_years <- 2000:2019
backfill_years <- 2000:2009

# -----------------------------
# 3) Register the API key and pull annual tract ACS data
# -----------------------------

# --- Register the API key for this session before calling `tidycensus`

Sys.setenv(CENSUS_API_KEY = read_census_api_key(api_key_path))

# --- Pull each ACS year separately so tract controls vary from `2010:2019`.
# The tract review branch now stops at `2019` because the live reduced-form
# pipeline also stops at `2019`, so the 2020 tract redraw is not analytically
# relevant for the current tract build.

annual_acs_outputs <- map(
  acs_years,
  build_annual_acs_outputs,
  tract_scope = tract_scope,
  scope_states = scope_states
)

acs_raw_scope <- map_dfr(annual_acs_outputs, "raw") |>
  arrange(tract_fips, year)

annual_tract_covariates <- map_dfr(annual_acs_outputs, "covariates") |>
  arrange(tract_fips, year)

annual_match_summary <- map_dfr(annual_acs_outputs, "summary") |>
  arrange(year)

# -----------------------------
# 4) Backfill `2000:2009` from the `2010` ACS 5-year tract controls
# -----------------------------

# --- Keep the county-style year grid by repeating the `2010` tract covariates
# onto years before tract ACS 5-year estimates are available.

tract_covariates_backfill <- annual_tract_covariates |>
  filter(year == 2010L) |>
  select(-year) |>
  tidyr::crossing(year = backfill_years) |>
  mutate(
    year = as.integer(year),
    acs_source_year = 2010L,
    acs_2010_backfill = TRUE
  )

tract_covariates <- bind_rows(tract_covariates_backfill, annual_tract_covariates) |>
  arrange(tract_fips, year)

# -----------------------------
# 5) Build the annual tract ACS match summary
# -----------------------------

# --- Save one row per ACS year so annual join coverage and source gaps are
# visible, and include the review-stage backfill accounting on every row.

tract_match_summary <- annual_match_summary |>
  mutate(
    covariate_rows = nrow(tract_covariates),
    pre_2010_backfill_rows = nrow(tract_covariates_backfill),
    pre_2010_backfill_year_start = min(backfill_years),
    pre_2010_backfill_year_end = max(backfill_years),
    pre_2010_backfill_source_year = 2010L,
    panel_year_start = min(panel_years),
    panel_year_end = max(panel_years)
  )

# -----------------------------
# 6) Save, close out
# -----------------------------

saveRDS(acs_raw_scope, file.path(acs_output_dir, "2_1_8_acs_tract_2010_2020_raw.rds"))
saveRDS(tract_covariates, file.path(acs_output_dir, "2_1_9_acs_tract_2010_2020_covariates.rds"))
saveRDS(tract_match_summary, file.path(acs_output_dir, "2_1_10_acs_tract_2010_2020_match_summary.rds"))

print(tract_match_summary)
