#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_2_1_build_analysis_panel_tract_pre_covariates.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 19, 2026
# Description:      Build the tract-year analysis panel through the outcome and
#                   treatment layers, before ACS covariates are merged.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `2_0_waivers/2_0_7_waived_data_consolidated_long_tract.rds`
#                   `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds`
#                   `2_5_SNAP/2_5_3_store_count_tract.rds`
#                   local tract shapefiles under `0_8_geographies/`
# OUTPUTS:          `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

library(dplyr)
library(tidyr)
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
source(file.path(dirname(script_dir), "tract_ingest_helpers.R"))

# -----------------------------
# 1) Helper functions
# -----------------------------

# --- Guarantee that wide tract panels still include every benchmark outcome column

ensure_columns <- function(df, columns, fill_value = 0L) {
  missing_cols <- setdiff(columns, names(df))

  if (length(missing_cols)) {
    df[missing_cols] <- fill_value
  }

  df
}

# -----------------------------
# 2) Read paths, processed inputs, and tract outcome definitions
# -----------------------------

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

waiver_path <- file.path(processed_root, "2_0_waivers", "2_0_7_waived_data_consolidated_long_tract.rds")
snap_clean_path <- file.path(processed_root, "2_5_SNAP", "2_5_2_snap_clean_with_tracts.rds")
store_count_path <- file.path(processed_root, "2_5_SNAP", "2_5_3_store_count_tract.rds")

processed_analysis_dir <- ensure_dir(file.path(processed_root, "2_9_analysis"))

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

# -----------------------------
# 3) Read tract inputs and rebuild tract-year outcome panels
# -----------------------------

waiver_long_tract <- readRDS(waiver_path)
snap_clean <- readRDS(snap_clean_path)
store_count_tract <- readRDS(store_count_path)
tract_universe <- load_scope_tracts(input_root, processed_root) |>
  st_drop_geometry() |>
  distinct(tract_fips, county_fips)

# --- Rebuild tract-year entry outcomes using the same chain grouping logic as county

snap_grouped <- snap_clean |>
  mutate(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
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
  filter(!is.na(tract_fips), !is.na(authorization_year)) |>
  count(authorization_year, tract_fips, county_fips, chain, name = "entry") |>
  rename(year = authorization_year) |>
  pivot_wider(names_from = chain, values_from = entry, values_fill = 0) |>
  ensure_columns(entry_outcome_columns, fill_value = 0L) |>
  mutate(
    total_ds = chain_dollar_general + chain_dollar_tree + chain_family_dollar
  )

# --- Zero-fill the tract-year entry panel over the full tract universe

tract_year_grid <- tidyr::crossing(
  tract_universe,
  year = 2000:2019
)

entry_panel <- tract_year_grid |>
  left_join(entry_panel, by = c("tract_fips", "county_fips", "year")) |>
  mutate(across(any_of(c(entry_outcome_columns, "total_ds")), ~ coalesce(.x, 0L)))

# --- Rebuild tract-year dollar-store stock counts from the tract store-count file

store_stock_panel <- store_count_tract |>
  transmute(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
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
  group_by(tract_fips, county_fips, year, chain) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = chain, values_from = count, values_fill = 0) |>
  ensure_columns(stock_outcome_columns, fill_value = 0L) |>
  mutate(total_count = chain_dollar_general_count + chain_dollar_tree_count + chain_family_dollar_count)

# -----------------------------
# 4) Collapse tract treatment timing to one tract-year row
# -----------------------------

# --- A tract can inherit more than one waiver geography in a year, so rank and collapse

waiver_treatment <- waiver_long_tract |>
  transmute(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
    year = as.integer(YEAR),
    countyname = LOC,
    type = LOC_TYPE
  ) |>
  filter(!is.na(tract_fips), !is.na(year)) |>
  mutate(
    type_rank = case_when(
      type == "County" ~ 1L,
      type == "State" ~ 2L,
      TRUE ~ 3L
    )
  ) |>
  arrange(tract_fips, year, type_rank, countyname) |>
  group_by(tract_fips, county_fips, year) |>
  summarise(
    countyname = first(countyname),
    type = first(type),
    treatment = 1L,
    treated_geography_n = n_distinct(paste(type, countyname, sep = "::")),
    .groups = "drop"
  )

treated_tracts <- sort(unique(waiver_treatment$tract_fips))

# -----------------------------
# 5) Assemble the tract pre-covariate analysis panel
# -----------------------------

# --- Join tract treatment timing to tract outcomes on the complete tract-year grid

analysis_panel <- waiver_treatment |>
  right_join(entry_panel, by = c("tract_fips", "county_fips", "year")) |>
  mutate(treatment = coalesce(treatment, 0L)) |>
  left_join(store_stock_panel, by = c("tract_fips", "county_fips", "year")) |>
  mutate(
    across(
      any_of(c(entry_outcome_columns, "total_ds", stock_outcome_columns, "total_count")),
      ~ coalesce(.x, 0L)
    ),
    treated_geography_n = coalesce(treated_geography_n, 0L)
  )

# --- Mirror the county event-time fields at the tract level

event1 <- analysis_panel |>
  filter(treatment == 1) |>
  group_by(tract_fips) |>
  summarise(eventYear1 = min(year), .groups = "drop")

event2 <- analysis_panel |>
  filter(treatment == 1, year >= 2014, type == "County") |>
  group_by(tract_fips) |>
  summarise(eventYear2 = min(year), .groups = "drop")

analysis_panel <- analysis_panel |>
  left_join(event1, by = "tract_fips") |>
  mutate(
    eventYear1 = if_else(!(tract_fips %in% treated_tracts), 2010L, eventYear1),
    tau1 = year - eventYear1
  ) |>
  left_join(event2, by = "tract_fips") |>
  mutate(
    tau2 = year - eventYear2,
    treated = tract_fips %in% treated_tracts
  ) |>
  arrange(tract_fips, year)

# -----------------------------
# 6) Save, close out
# -----------------------------

saveRDS(analysis_panel, file.path(processed_analysis_dir, "2_9_3_us_analysis_panel_tract_pre_covariates.rds"))

print(
  tibble(
    rows = nrow(analysis_panel),
    treated_tracts = n_distinct(analysis_panel$tract_fips[analysis_panel$treated]),
    min_year = min(analysis_panel$year, na.rm = TRUE),
    max_year = max(analysis_panel$year, na.rm = TRUE)
  )
)
