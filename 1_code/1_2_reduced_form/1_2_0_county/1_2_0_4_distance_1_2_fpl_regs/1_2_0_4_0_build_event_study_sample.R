library(dplyr)
library(tidyr)

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(active_path)) return(dirname(normalizePath(active_path)))
  }
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) return(dirname(normalizePath(frame$ofile)))
  }
  normalizePath(getwd())
})

source(file.path(script_dir, "shared_reduced_form_helpers.R"))

repo_root <- get_repo_root()
setwd(repo_root)
processed_root <- read_root_path("2_processed_data/processed_root.txt")

analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))
baseline_controls <- analysis_panel |>
  transmute(
    county_fips = as.integer(county_fips),
    year = as.integer(year),
    population,
    wage,
    meanInc,
    rent,
    urate
  ) |>
  filter(year == 2010) |>
  select(-year) |>
  rename(
    population_2010 = population,
    wage_2010 = wage,
    meanInc_2010 = meanInc,
    rent_2010 = rent,
    urate_2010 = urate
  )

county_distance <- readRDS(file.path(processed_root, "2_10_retail_access", "2_10_2_county_retail_access_weighted_summary.rds")) |>
  filter(weight_type == "Below 1.25x FPL") |>
  transmute(
    county_fips = as.integer(county_fips),
    year = as.integer(year),
    outcome = dplyr::case_when(
      as.character(format) == "Dollar stores" ~ "distance_dollar_stores",
      as.character(format) == "Supermarkets" ~ "distance_supermarkets",
      as.character(format) == "Convenience stores" ~ "distance_convenience_stores",
      as.character(format) == "Multi-category" ~ "distance_multi_category",
      TRUE ~ NA_character_
    ),
    county_weighted_distance_miles = as.numeric(county_weighted_distance_miles)
  ) |>
  filter(!is.na(outcome)) |>
  pivot_wider(names_from = outcome, values_from = county_weighted_distance_miles)

aba1 <- analysis_panel |>
  mutate(county_fips = as.integer(county_fips)) |>
  left_join(baseline_controls, by = "county_fips") |>
  left_join(county_distance, by = c("county_fips", "year")) |>
  mutate(
    lowq = total_ds + chain_convenience_store,
    population = population_2010,
    wage = wage_2010,
    rent = rent_2010 / 1000,
    meanInc = meanInc_2010 / 1000,
    urate = urate_2010,
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

saveRDS(aba1, file.path(processed_root, "2_10_retail_access", "2_10_5_event_study_sample_distance_1_2_fpl.rds"))
