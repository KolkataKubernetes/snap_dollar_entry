#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_3_0_build_retail_access_weight_inputs.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Pull study-period tract ACS weights for the retail-access
#                   branch only, using the retained tract panel scope for
#                   years `2014:2019`.
# INPUTS:           `0_inputs/input_root.txt`
#                   `0_inputs/census_apikey.md`
#                   `2_processed_data/processed_root.txt`
#                   `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`
# OUTPUTS:          `2_10_retail_access/2_10_0_tract_access_weights_2014_2019.rds`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(purrr)
library(stringr)
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

source(file.path(script_dir, "shared_retail_access_helpers.R"))

read_census_api_key <- function(path) {
  key <- readLines(path, warn = FALSE) |>
    trimws()

  key <- key[key != ""]

  if (!length(key)) {
    stop("`0_inputs/census_apikey.md` is empty.")
  }

  key[[1]]
}

pull_state_acs <- function(states, variables, year) {
  purrr::map_dfr(
    states,
    function(state_abbrev) {
      tidycensus::get_acs(
        geography = "tract",
        variables = variables,
        year = year,
        survey = "acs5",
        state = state_abbrev,
        geometry = FALSE,
        output = "wide",
        cache_table = TRUE
      )
    }
  )
}

paths <- get_access_paths()
setwd(paths$repo_root)

tidycensus::census_api_key(
  key = read_census_api_key(file.path(paths$repo_root, "0_inputs", "census_apikey.md")),
  install = FALSE,
  overwrite = TRUE
)

tract_panel <- readRDS(
  file.path(paths$processed_root, "2_9_analysis", "2_9_6_us_analysis_panel_tract_timevarying_covariates.rds")
) |>
  transmute(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
    state_abbrev = as.character(state_abbrev),
    year = as.integer(year)
  ) |>
  filter(year %in% 2014:2019) |>
  distinct()

acs_variables <- c(
  "B01003_001",
  "C17002_002",
  "C17002_003",
  "C17002_004",
  "B22010_002"
)

tract_access_weights <- purrr::map_dfr(
  2014:2019,
  function(acs_year) {
    scope_year <- tract_panel |>
      filter(year == acs_year)

    acs_year_raw <- pull_state_acs(
      states = sort(unique(scope_year$state_abbrev)),
      variables = acs_variables,
      year = acs_year
    ) |>
      mutate(tract_fips = str_pad(GEOID, width = 11, side = "left", pad = "0")) |>
      transmute(
        tract_fips,
        B01003_001E = as.numeric(B01003_001E),
        C17002_002E = as.numeric(C17002_002E),
        C17002_003E = as.numeric(C17002_003E),
        C17002_004E = as.numeric(C17002_004E),
        B22010_002E = as.numeric(B22010_002E)
      )

    scope_year |>
      left_join(acs_year_raw, by = "tract_fips")
  }
)

saveRDS(
  tract_access_weights,
  file.path(paths$processed_access_dir, "2_10_0_tract_access_weights_2014_2019.rds")
)

print(
  tract_access_weights |>
    summarise(
      rows = n(),
      tracts = n_distinct(tract_fips),
      min_year = min(year, na.rm = TRUE),
      max_year = max(year, na.rm = TRUE),
      missing_B01003_001E = sum(is.na(B01003_001E)),
      missing_C17002_002E = sum(is.na(C17002_002E)),
      missing_C17002_003E = sum(is.na(C17002_003E)),
      missing_C17002_004E = sum(is.na(C17002_004E)),
      missing_B22010_002E = sum(is.na(B22010_002E))
    )
)

