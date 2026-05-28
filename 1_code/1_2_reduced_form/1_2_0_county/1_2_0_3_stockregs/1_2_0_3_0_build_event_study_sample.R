#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_3_0_build_event_study_sample.R
# Description:      Build the county stock-regression event-study sample from
#                   the processed benchmark county analysis panel and the
#                   active-store stock panel.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `2_9_analysis/2_9_4_county_stockreg_sample.rds`
# DEPENDENCIES:     `dplyr`, `tidyr`, `shared_reduced_form_helpers.R`
# Review focus:     Verify that the sample restrictions remain benchmark-
#                   identical while the outcome columns are rebuilt from active
#                   stock counts instead of authorization-year entry counts.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(tidyr)

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

source(file.path(script_dir, "shared_reduced_form_helpers.R"))

ensure_columns <- function(df, columns, fill_value = 0L) {
  missing_cols <- setdiff(columns, names(df))

  if (length(missing_cols)) {
    df[missing_cols] <- fill_value
  }

  df
}

repo_root <- get_repo_root()
setwd(repo_root)
processed_root <- read_root_path("2_processed_data/processed_root.txt")

analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))
store_count <- readRDS(file.path(processed_root, "2_5_SNAP", "2_5_1_store_count.rds"))

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

stock_outcome_columns <- c(
  "chain_dollar_general_stock",
  "chain_dollar_tree_stock",
  "chain_family_dollar_stock",
  "chain_super_market_stock",
  "chain_convenience_store_stock",
  "chain_multi_category_stock",
  "chain_medium_grocery_stock",
  "chain_small_grocery_stock",
  "chain_produce_stock",
  "chain_farmers_market_stock",
  "total_ds_stock"
)

stock_panel <- store_count |>
  transmute(
    county_fips = as.integer(county_fips),
    year = as.integer(year),
    chain = as.character(chain),
    count = as.integer(count)
  ) |>
  mutate(
    chain = case_when(
      chain %in% supermarket_chains ~ "chain_super_market",
      chain %in% club_store_chains ~ "chain_club_store",
      chain %in% convenience_chains ~ "chain_convenience_store",
      chain %in% multi_category_chains ~ "chain_multi_category",
      TRUE ~ chain
    )
  ) |>
  filter(
    chain %in% c(
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
  ) |>
  group_by(county_fips, year, chain) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop") |>
  mutate(chain = paste0(chain, "_stock")) |>
  pivot_wider(names_from = chain, values_from = count, values_fill = 0) |>
  ensure_columns(stock_outcome_columns, fill_value = 0L) |>
  mutate(
    total_ds_stock = chain_dollar_general_stock + chain_dollar_tree_stock + chain_family_dollar_stock
  )

stock_panel <- analysis_panel |>
  select(county_fips, year) |>
  distinct() |>
  left_join(stock_panel, by = c("county_fips", "year")) |>
  mutate(across(any_of(stock_outcome_columns), ~ coalesce(.x, 0L)))

stock_analysis_panel <- analysis_panel |>
  select(-any_of(stock_outcome_columns)) |>
  left_join(stock_panel, by = c("county_fips", "year"))

stock_sample <- stock_analysis_panel |>
  mutate(
    lowq = total_ds_stock + chain_convenience_store_stock,
    rent = rent / 1000,
    meanInc = meanInc / 1000,
    zl = dplyr::lag(urate),
    z = urate,
    no_stores = (
      total_ds_stock +
        chain_super_market_stock +
        chain_convenience_store_stock +
        chain_multi_category_stock
    ) == 0,
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

output_path <- file.path(processed_root, "2_9_analysis", "2_9_4_county_stockreg_sample.rds")
saveRDS(stock_sample, output_path)
