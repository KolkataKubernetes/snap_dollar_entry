#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_build_event_study_sample.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 12, 2026
# Description:      Build the event-study estimation sample from the processed
#                   benchmark analysis panel.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
# PROCEDURES:       Apply the benchmark event-study sample restrictions and save
#                   the estimation sample as a processed `.rds`.
# OUTPUTS:          `2_9_analysis/2_9_2_event_study_sample.rds`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(stringr)

source("1_code/1_2_reduced_form/shared_reduced_form_helpers.R")

repo_root <- get_repo_root()
setwd(repo_root)
processed_root <- read_root_path("2_processed_data/processed_root.txt")

analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

aba1 <- analysis_panel |>
  mutate(
    lowq = total_ds + chain_convenience_store,
    rent = rent / 1000,
    meanInc = meanInc / 1000,
    zl = dplyr::lag(urate),
    z = urate,
    no_stores = (total_ds + chain_super_market + chain_convenience_store + chain_multi_category) == 0,
    state_fips = county_fips %/% 1000
  ) |>
  filter(year %in% 2014:2019) |>
  mutate(
    tau2 = if_else(is.na(tau2), -1000, tau2),
    eventYear2 = if_else(is.na(eventYear2), 10000, eventYear2),
    treated_group = eventYear2 != 10000
  ) |>
  group_by(state_fips) |>
  mutate(treated_state = sum(treated_group) > 0) |>
  group_by(county_fips) |>
  mutate(treated_county = sum(treated_group) > 0) |>
  ungroup() |>
  filter(year - eventYear2 >= -3, treated_state, treated_county) |>
  mutate(state_year = paste(state, year))

saveRDS(aba1, file.path(processed_root, "2_9_analysis", "2_9_2_event_study_sample.rds"))
