#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0b_build_event_study_sample.R
# Description:      Build the county stock-Poisson reduced-form sample from
#                   the processed county analysis panel and active-store stock
#                   counts.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `2_9_analysis/2_9_5_county_stockpoissonreg_sample.rds`
# DEPENDENCIES:     `dplyr`, `tidyr`, `shared_reduced_form_helpers.R`
# Review focus:     Verify that the branch preserves the current Poisson
#                   sample restrictions while rebuilding the outcome family
#                   from active stock counts rather than authorization-year
#                   entry flows.
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

stock_poisson_sample <- analysis_panel |>
  select(-any_of(stock_outcome_columns)) |>
  left_join(stock_panel, by = c("county_fips", "year")) |>
  mutate(
    rent = rent / 1000,
    meanInc = meanInc / 1000
  ) |>
  filter(year %in% 2013:2019) |>
  mutate(
    g_first_treat = if_else(is.na(eventYear2), 0L, as.integer(eventYear2)),
    treated_group = g_first_treat > 0L
  ) |>
  filter(
    g_first_treat == 0L | year - g_first_treat >= -3
  ) |>
  filter(
    is.finite(g_first_treat),
    g_first_treat >= 0
  )

output_path <- file.path(processed_root, "2_9_analysis", "2_9_5_county_stockpoissonreg_sample.rds")
saveRDS(stock_poisson_sample, output_path)

cat("County stock-Poisson sample written.\n")
cat(sprintf("Path: %s\n", output_path))
cat(sprintf("Rows: %s\n", nrow(stock_poisson_sample)))
cat(sprintf("Counties: %s\n", dplyr::n_distinct(stock_poisson_sample$county_fips)))
cat(sprintf("Never-treated counties: %s\n", dplyr::n_distinct(stock_poisson_sample$county_fips[stock_poisson_sample$g_first_treat == 0L])))
cat(sprintf("Years: %s-%s\n", min(stock_poisson_sample$year), max(stock_poisson_sample$year)))
cat(sprintf("Cohorts: %s\n", paste(sort(unique(stock_poisson_sample$g_first_treat)), collapse = ", ")))
