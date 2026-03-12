#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_4_build_analysis_panel.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 12, 2026
# Description:      Reproduce the benchmark county-year analysis panel used by
#                   the legacy U.S. descriptives and reduced-form script.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `2_0_waivers/2_0_4_waived_data_consolidated_long_selected.rds`
#                   `2_5_SNAP/2_5_0_snap_clean.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `2_1_acs/2_1_0_unemployment.rds`
#                   `2_1_acs/2_1_2_population.rds`
#                   `2_1_acs/2_1_3_Append_CountyDP03.rds`
#                   `0_4_prices/0_4_1_Wages_V2.csv`
#                   `0_4_prices/0_4_2_Prices.csv`
# PROCEDURES:       Load the processed ingest artifacts and raw prices inputs;
#                   rebuild the benchmark entry counts, store stock counts,
#                   treatment timing, and covariate merges; save the final
#                   analysis-ready county-year panel as a processed `.rds`.
# OUTPUTS:          `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_9_analysis/2_9_1_us_analysis_panel_summary.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file:
# - legacy/Box/code/02 - Descriptives & Motivation US.R

# Setup ------------------------------------------------------------------------
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(tibble)

get_repo_root <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)

  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[[1]]))
    return(normalizePath(file.path(dirname(script_path), "..", "..")))
  }

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    script_path <- rstudioapi::getActiveDocumentContext()$path
    return(normalizePath(file.path(dirname(script_path), "..", "..")))
  }

  normalizePath(getwd())
}

read_root_path <- function(path_file) {
  readLines(path_file, warn = FALSE)[[1]] |>
    str_trim() |>
    str_remove_all("^['\"]|['\"]$")
}

ensure_columns <- function(df, columns, fill_value = 0L) {
  missing_cols <- setdiff(columns, names(df))

  if (length(missing_cols)) {
    df[missing_cols] <- fill_value
  }

  df
}

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

waiver_path <- file.path(processed_root, "2_0_waivers", "2_0_4_waived_data_consolidated_long_selected.rds")
snap_clean_path <- file.path(processed_root, "2_5_SNAP", "2_5_0_snap_clean.rds")
store_count_path <- file.path(processed_root, "2_5_SNAP", "2_5_1_store_count.rds")
unemployment_path <- file.path(processed_root, "2_1_acs", "2_1_0_unemployment.rds")
population_path <- file.path(processed_root, "2_1_acs", "2_1_2_population.rds")
acs03_path <- file.path(processed_root, "2_1_acs", "2_1_3_Append_CountyDP03.rds")

wages_path <- file.path(input_root, "0_4_prices", "0_4_1_Wages_V2.csv")
prices_path <- file.path(input_root, "0_4_prices", "0_4_2_Prices.csv")

processed_analysis_dir <- file.path(processed_root, "2_9_analysis")
dir.create(processed_analysis_dir, recursive = TRUE, showWarnings = FALSE)

supermarket_chains <- c(
  "chain_ingles_markets",
  "chain_winn-dixie",
  "chain_stop_&_shop",
  "chain_albertsons",
  "chain_fred_meyer",
  "chain_trader_joes",
  "chain_trader_joe_s",
  "chain_whole_foods",
  "chain_save_a_lot",
  "chain_aldi",
  "chain_save_mart",
  "chain_safeway",
  "chain_kroger",
  "chain_giant_food",
  "chain_weis_markets",
  "chain_publix",
  "chain_supervalu",
  "chain_raleys",
  "chain_raley_s",
  "chain_smart_&_final",
  "chain_wild_oats",
  "chain_meijer",
  "chain_giant_eagle",
  "chain_he_butt",
  "chain_stater_bros",
  "chain_roundys",
  "chain_roundy_s"
)

club_store_chains <- c("chain_costco", "chain_sams_club", "chain_sam_s_club", "chain_bjs")
convenience_chains <- c("chain_seven_eleven", "chain_circle_k", "chain_speedway")
multi_category_chains <- c("chain_wal-mart", "chain_target")

entry_outcome_columns <- c(
  "chain_dollar_general",
  "chain_dollar_tree",
  "chain_family_dollar",
  "chain_super_market",
  "chain_convenience_store",
  "chain_multi_category",
  "chain_medium_grocery",
  "chain_small_grocery",
  "chain_produce",
  "chain_farmers_market"
)

stock_outcome_columns <- c(
  "chain_dollar_general_count",
  "chain_dollar_tree_count",
  "chain_family_dollar_count",
  "chain_nods_count"
)

#(1) Load processed ingest artifacts and raw prices inputs ---------------------
waiver_long <- readRDS(waiver_path)
snap_clean <- readRDS(snap_clean_path)
store_count <- readRDS(store_count_path)
unemployment_panel <- readRDS(unemployment_path)
population_panel <- readRDS(population_path)
acs03_panel <- readRDS(acs03_path)

wages <- readr::read_csv(wages_path, show_col_types = FALSE) |>
  transmute(
    county_fips = as.integer(county_fips),
    year = as.integer(year),
    wage = as.numeric(wage)
  )

prices <- readr::read_csv(prices_path, show_col_types = FALSE) |>
  rename(income = B20002_001) |>
  transmute(
    county_fips = as.integer(GEOID),
    year = as.integer(year),
    income = as.numeric(income),
    rent = as.numeric(rent)
  )

#(2) Rebuild benchmark entry and store stock panels ----------------------------
snap_grouped <- snap_clean |>
  mutate(
    county_fips = as.integer(county_fips),
    authorization_year = as.integer(authorization_year),
    chain = case_when(
      chain %in% supermarket_chains ~ "chain_super_market",
      chain %in% club_store_chains ~ "chain_club_store",
      chain %in% convenience_chains ~ "chain_convenience_store",
      chain %in% multi_category_chains ~ "chain_multi_category",
      TRUE ~ chain
    )
  )

entry_panel <- snap_grouped |>
  filter(!is.na(county_fips), !is.na(authorization_year)) |>
  count(authorization_year, county_fips, chain, name = "entry") |>
  rename(year = authorization_year) |>
  pivot_wider(names_from = chain, values_from = entry, values_fill = 0) |>
  ensure_columns(entry_outcome_columns, fill_value = 0L) |>
  mutate(
    total_ds = chain_dollar_general + chain_dollar_tree + chain_family_dollar,
    state = county_fips %/% 1000
  )

county_year_grid <- tidyr::crossing(
  county_fips = as.integer(unique(acs03_panel$GEOID_COUNTY)),
  year = 2000:2020
)

entry_panel <- county_year_grid |>
  left_join(entry_panel, by = c("county_fips", "year"))

entry_fill_columns <- c(entry_outcome_columns, "total_ds")
entry_panel <- entry_panel |>
  mutate(across(any_of(entry_fill_columns), ~ coalesce(.x, 0L)))

store_stock_panel <- store_count |>
  transmute(
    county_fips = as.integer(county_fips),
    year = as.integer(year),
    chain = paste0(chain, "_count"),
    count = as.integer(count)
  ) |>
  mutate(
    chain = case_when(
      chain %in% c("chain_family_dollar_count", "chain_dollar_general_count", "chain_dollar_tree_count") ~ chain,
      TRUE ~ "chain_nods_count"
    )
  ) |>
  group_by(county_fips, year, chain) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = chain, values_from = count, values_fill = 0) |>
  ensure_columns(stock_outcome_columns, fill_value = 0L) |>
  mutate(
    total_count = chain_dollar_general_count + chain_dollar_tree_count + chain_family_dollar_count
  )

#(3) Rebuild treatment timing and merge outcomes -------------------------------
waiver_county_fips <- if ("FIPS" %in% names(waiver_long)) {
  waiver_long$FIPS
} else if ("county_fips" %in% names(waiver_long)) {
  waiver_long$county_fips
} else {
  stop("Selected waiver panel is missing both `FIPS` and `county_fips`.")
}

waiver_year <- if ("YEAR" %in% names(waiver_long)) {
  waiver_long$YEAR
} else if ("year" %in% names(waiver_long)) {
  waiver_long$year
} else {
  stop("Selected waiver panel is missing both `YEAR` and `year`.")
}

waiver_treatment <- waiver_long |>
  mutate(
    county_fips = as.integer(waiver_county_fips),
    year = as.integer(waiver_year)
  ) |>
  filter(!is.na(county_fips), !is.na(year)) |>
  transmute(
    county_fips,
    year,
    countyname = LOC,
    type = LOC_TYPE,
    treatment = 1L
  ) |>
  distinct()

treated_counties <- sort(unique(waiver_treatment$county_fips))

analysis_panel <- waiver_treatment |>
  right_join(entry_panel, by = c("county_fips", "year")) |>
  mutate(treatment = coalesce(treatment, 0L)) |>
  left_join(store_stock_panel, by = c("county_fips", "year")) |>
  mutate(
    across(
      any_of(c(entry_outcome_columns, "total_ds", stock_outcome_columns, "total_count")),
      ~ coalesce(.x, 0L)
    )
  )

event1 <- analysis_panel |>
  filter(treatment == 1) |>
  group_by(county_fips) |>
  summarise(eventYear1 = min(year), .groups = "drop")

event2 <- analysis_panel |>
  filter(treatment == 1, year >= 2014, type == "County") |>
  group_by(county_fips) |>
  summarise(eventYear2 = min(year), .groups = "drop")

analysis_panel <- analysis_panel |>
  left_join(event1, by = "county_fips") |>
  mutate(
    treatment = if_else(year %in% 2010:2013, 1L, treatment),
    eventYear1 = if_else(!(county_fips %in% treated_counties), 2010L, eventYear1),
    tau1 = year - eventYear1
  ) |>
  left_join(event2, by = "county_fips") |>
  mutate(
    tau2 = year - eventYear2,
    treated = county_fips %in% treated_counties
  )

#(4) Merge benchmark covariates ------------------------------------------------
acs03_covariates <- acs03_panel |>
  transmute(
    county_fips = as.integer(GEOID_COUNTY),
    year = as.integer(year),
    totalHH = as.numeric(totalHH),
    meanInc = as.numeric(meanInc),
    medianInc = as.numeric(medianInc)
  )

population_covariates <- population_panel |>
  transmute(
    county_fips = as.integer(GEOID),
    year = as.integer(year),
    population = as.numeric(estimate)
  )

unemployment_covariates <- unemployment_panel |>
  transmute(
    county_fips = as.integer(GEOID),
    year = as.integer(year),
    urate = as.numeric(unemployment_rate)
  )

analysis_panel <- analysis_panel |>
  left_join(prices, by = c("county_fips", "year")) |>
  left_join(wages, by = c("county_fips", "year")) |>
  group_by(year) |>
  mutate(
    wage_st = mean(wage, na.rm = TRUE),
    wage = if_else(is.na(wage), wage_st, wage)
  ) |>
  ungroup() |>
  left_join(acs03_covariates, by = c("county_fips", "year")) |>
  left_join(population_covariates, by = c("county_fips", "year")) |>
  left_join(unemployment_covariates, by = c("county_fips", "year")) |>
  arrange(county_fips, year)

#(5) Save processed analysis panel --------------------------------------------
analysis_output_path <- file.path(processed_analysis_dir, "2_9_0_us_analysis_panel.rds")
summary_output_path <- file.path(processed_analysis_dir, "2_9_1_us_analysis_panel_summary.rds")

analysis_summary <- tibble(
  metric = c("rows", "treated_counties", "min_year", "max_year"),
  value = c(
    nrow(analysis_panel),
    dplyr::n_distinct(analysis_panel$county_fips[analysis_panel$treated]),
    min(analysis_panel$year, na.rm = TRUE),
    max(analysis_panel$year, na.rm = TRUE)
  )
)

saveRDS(analysis_panel, analysis_output_path)
saveRDS(analysis_summary, summary_output_path)

#(6) Print processing summary --------------------------------------------------
print(analysis_summary)
