#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        shared_retail_access_helpers.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Shared helper functions for the retail-access ingest branch.
#                   These helpers keep pathing, tract geometry loading, retailer
#                   format grouping, and county treatment / RUCC metadata
#                   consistent across the study-period access scripts.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   local tract shapefiles under `0_8_geographies/`
# OUTPUTS:          helper functions only
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(readxl)
library(sf)
library(stringr)

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

source(file.path(dirname(script_dir), "1_0_1_covariates", "shared_ingest_helpers.R"))
source(file.path(dirname(script_dir), "tract_ingest_helpers.R"))

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

convenience_chains <- c(
  "chain_seven_eleven",
  "chain_circle_k",
  "chain_speedway",
  "chain_convenience_store"
)

multi_category_chains <- c(
  "chain_wal-mart",
  "chain_target",
  "chain_multi_category"
)

dollar_store_chains <- c(
  "chain_dollar_general",
  "chain_dollar_tree",
  "chain_family_dollar"
)

access_format_levels <- c(
  "Dollar stores",
  "Convenience stores",
  "Supermarkets",
  "Multi-category"
)

access_weight_levels <- c(
  "Total population",
  "Below 1.25x FPL",
  "SNAP recipient households"
)

access_format_colors <- c(
  "Dollar stores" = "#c5050c",
  "Convenience stores" = "#0072B2",
  "Supermarkets" = "grey60",
  "Multi-category" = "black"
)

get_access_paths <- function() {
  repo_root <- get_repo_root()
  input_root <- read_root_path(file.path(repo_root, "0_inputs", "input_root.txt"))
  processed_root <- read_root_path(file.path(repo_root, "2_processed_data", "processed_root.txt"))
  processed_access_dir <- ensure_dir(file.path(processed_root, "2_10_retail_access"))

  list(
    repo_root = repo_root,
    input_root = input_root,
    processed_root = processed_root,
    processed_access_dir = processed_access_dir
  )
}

classify_access_format <- function(chain) {
  dplyr::case_when(
    chain %in% dollar_store_chains ~ "Dollar stores",
    chain %in% convenience_chains ~ "Convenience stores",
    chain %in% supermarket_chains | chain == "chain_super_market" ~ "Supermarkets",
    chain %in% multi_category_chains ~ "Multi-category",
    TRUE ~ NA_character_
  )
}

load_scope_tract_centroids <- function(paths = get_access_paths(), tract_ids = NULL) {
  tracts <- load_scope_tracts(paths$input_root, paths$processed_root) |>
    mutate(
      tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
      county_fips = normalize_fips(county_fips)
    ) |>
    select(tract_fips, county_fips, geometry)

  if (!is.null(tract_ids)) {
    tracts <- tracts |>
      filter(tract_fips %in% tract_ids)
  }

  suppressWarnings(
    tracts |>
      st_transform(5070) |>
      st_centroid()
  )
}

load_county_access_metadata <- function(paths = get_access_paths()) {
  analysis_panel <- readRDS(file.path(paths$processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds")) |>
    transmute(
      county_fips = normalize_fips(county_fips),
      year = as.integer(year),
      treatment = as.integer(treatment),
      type = as.character(type)
    )

  event2 <- analysis_panel |>
    filter(treatment == 1L, year >= 2014L, type == "County") |>
    group_by(county_fips) |>
    summarise(eventYear2 = min(year), .groups = "drop")

  rucc <- readxl::read_excel(file.path(paths$input_root, "0_7_Ruralurbancontinuumcodes2023.xlsx")) |>
    transmute(
      county_fips = normalize_fips(FIPS),
      rural_status = if_else(RUCC_2023 >= 4, "Rural counties", "Urban counties")
    ) |>
    distinct()

  analysis_panel |>
    distinct(county_fips, year) |>
    left_join(event2, by = "county_fips") |>
    mutate(
      ever_treated_county = county_fips %in% event2$county_fips,
      treatment_group = if_else(
        ever_treated_county,
        "Ever-treated counties",
        "Never-treated counties"
      )
    ) |>
    left_join(rucc, by = "county_fips") |>
    mutate(
      rural_status = coalesce(rural_status, "Urban counties"),
      rural_status = factor(rural_status, levels = c("Urban counties", "Rural counties")),
      treatment_group = factor(
        treatment_group,
        levels = c("Ever-treated counties", "Never-treated counties")
      )
    )
}
