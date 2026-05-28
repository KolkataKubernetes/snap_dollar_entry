#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_6_0_build_event_study_sample.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 12, 2026
# Description:      Build the county LPM entry-indicator event-study sample
#                   from the processed benchmark analysis panel.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
# PROCEDURES:       Apply the benchmark event-study sample restrictions, derive
#                   outlet-specific annual entry indicators, and save the
#                   estimation sample as a processed `.rds`.
# OUTPUTS:          `2_9_analysis/2_9_9_event_study_sample_lpm_entryindicator.rds`
# DEPENDENCIES:     `dplyr`, `stringr`, `shared_reduced_form_helpers.R`
# Review focus:     Verify the sample restrictions, especially the 2014-2019
#                   window, the sentinel replacements for missing event timing,
#                   the outlet-specific entry-indicator derivations, and the
#                   requirement that retained counties come from states and
#                   counties that ever enter the treated universe.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(stringr)

# Resolve the script directory so the local helper copy can be sourced
# regardless of the execution environment.
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

# Load shared path helpers used to find the repository root and processed-data pointer file.
source(file.path(script_dir, "shared_reduced_form_helpers.R"))

# Resolve the processed-data root before reading the benchmark county analysis panel.
repo_root <- get_repo_root()
setwd(repo_root)
processed_root <- read_root_path("2_processed_data/processed_root.txt")

analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

# Rebuild the benchmark reduced-form sample from the county analysis panel.
# Review focus: this block creates derived covariates and flags that are later
#               treated as fixed benchmark conventions across many scripts.
aba1 <- analysis_panel |>
  mutate(
    # `lowq`, `zl`, `z`, and `no_stores` are benchmark helper variables carried
    # forward from the legacy sample-building logic even when not all are used
    # directly in the downstream regression scripts.
    lowq = total_ds + chain_convenience_store,
    # Rescale these monetary variables before estimation so the benchmark model
    # uses units of thousands rather than raw dollars.
    rent = rent / 1000,
    meanInc = meanInc / 1000,
    zl = dplyr::lag(urate),
    z = urate,
    # This zero-store flag summarizes whether the county lacks the main outlet
    # types used in the benchmark retail environment.
    no_stores = (total_ds + chain_super_market + chain_convenience_store + chain_multi_category) == 0,
    # State FIPS is used to determine whether a county belongs to a state that
    # ever enters the treated sample universe.
    state_fips = county_fips %/% 1000,
    # The LPM branch keeps the benchmark sample but replaces each count outcome
    # with a same-year entry indicator for the matched outlet type.
    total_ds_entry = as.integer(total_ds > 0),
    chain_super_market_entry = as.integer(chain_super_market > 0),
    chain_convenience_store_entry = as.integer(chain_convenience_store > 0),
    chain_multi_category_entry = as.integer(chain_multi_category > 0),
    chain_medium_grocery_entry = as.integer(chain_medium_grocery > 0),
    chain_small_grocery_entry = as.integer(chain_small_grocery > 0),
    chain_produce_entry = as.integer(chain_produce > 0),
    chain_farmers_market_entry = as.integer(chain_farmers_market > 0)
  ) |>
  # The benchmark event-study window is restricted to 2014 through 2019.
  filter(year %in% 2014:2019) |>
  mutate(
    # These sentinels replace missing timing values so never-treated units can
    # remain in the sample while still passing through the event-time logic.
    tau2 = if_else(is.na(tau2), -1000, tau2),
    eventYear2 = if_else(is.na(eventYear2), 10000, eventYear2),
    treated_group = eventYear2 != 10000
  ) |>
  group_by(state_fips) |>
  mutate(treated_state = sum(treated_group) > 0) |>
  group_by(county_fips) |>
  mutate(treated_county = sum(treated_group) > 0) |>
  ungroup() |>
  # Retain observations from the benchmark pre/post window and drop states or
  # counties that never participate in the treated universe.
  filter(year - eventYear2 >= -3, treated_state, treated_county) |>
  mutate(state_year = paste(state, year))

# Save the benchmark event-study sample that the helper-driven reduced-form
# scripts consume directly.
saveRDS(aba1, file.path(processed_root, "2_9_analysis", "2_9_9_event_study_sample_lpm_entryindicator.rds"))
