library(dplyr)
library(tidyr)
library(readxl)
library(ggplot2)
library(stringr)

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

theme_im <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(linewidth = 0.3),
      panel.grid.major.y = element_line(linewidth = 0.3),
      legend.position = "top",
      legend.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold")
    )
}

format_colors <- c(
  "Dollar stores" = "#c5050c",
  "Convenience stores" = "#0072B2",
  "Supermarkets" = "grey60",
  "Multi-category" = "black"
)

waiver_colors <- c(
  "Ever county-waived" = "#c5050c",
  "Never county-waived" = "#0072B2"
)

rural_split_colors <- c(
  "Rural counties" = "#0072B2",
  "Non-rural counties" = "grey60"
)

waiver_ts_colors <- c(
  "Rural counties" = "#0072B2",
  "Urban counties" = "grey60",
  "Total counties" = "black"
)

ensure_output_dir <- function() {
  dir.create(file.path("3_outputs", "3_1_descriptives"), recursive = TRUE, showWarnings = FALSE)
}

descriptive_output_path <- function(filename) {
  ensure_output_dir()
  file.path("3_outputs", "3_1_descriptives", filename)
}

load_us_analysis_context <- function() {
  repo_root <- get_repo_root()
  setwd(repo_root)

  input_root <- read_root_path("0_inputs/input_root.txt")
  processed_root <- read_root_path("2_processed_data/processed_root.txt")

  analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))
  store_count <- readRDS(file.path(processed_root, "2_5_SNAP", "2_5_1_store_count.rds")) |>
    mutate(
      county_fips = as.integer(county_fips),
      year = as.integer(year)
    )
  waiver_long <- readRDS(file.path(processed_root, "2_0_waivers", "2_0_4_waived_data_consolidated_long_selected.rds"))

  rucc <- readxl::read_excel(file.path(input_root, "0_7_Ruralurbancontinuumcodes2023.xlsx")) |>
    transmute(
      county_fips = as.integer(FIPS),
      is_rural = RUCC_2023 >= 4
    ) |>
    distinct()

  event2 <- analysis_panel |>
    filter(treatment == 1, year >= 2014, type == "County") |>
    group_by(county_fips) |>
    summarise(eventYear2 = min(year), .groups = "drop")

  county_panel <- analysis_panel |>
    distinct(county_fips, year, total_ds) |>
    left_join(event2, by = "county_fips") |>
    mutate(ever_county_waived = county_fips %in% event2$county_fips)

  ds_chains <- c("chain_dollar_general", "chain_dollar_tree", "chain_family_dollar")

  ds_stock_raw <- store_count |>
    filter(chain %in% ds_chains) |>
    group_by(county_fips, year) |>
    summarise(ds_stock_count = sum(count, na.rm = TRUE), .groups = "drop")

  ds_stock <- county_panel |>
    select(county_fips, year, ever_county_waived, eventYear2) |>
    left_join(ds_stock_raw, by = c("county_fips", "year")) |>
    mutate(ds_stock_count = coalesce(ds_stock_count, 0L))

  multi_category_chains <- if ("chain_multi_category" %in% store_count$chain) {
    "chain_multi_category"
  } else {
    c("chain_wal-mart", "chain_target")
  }

  format_groups <- list(
    "Dollar stores" = ds_chains,
    "Convenience stores" = c("chain_convenience_store"),
    "Supermarkets" = c("chain_super_market"),
    "Multi-category" = multi_category_chains
  )

  format_stock <- purrr::map_dfr(
    names(format_groups),
    function(fmt) {
      store_count |>
        filter(chain %in% format_groups[[fmt]]) |>
        group_by(county_fips, year) |>
        summarise(stock = sum(count, na.rm = TRUE), .groups = "drop") |>
        mutate(format = fmt)
    }
  )

  format_grid <- tidyr::crossing(
    county_fips = unique(county_panel$county_fips),
    year = 2000:2020,
    format = names(format_groups)
  )

  format_stock <- format_grid |>
    left_join(format_stock, by = c("county_fips", "year", "format")) |>
    mutate(stock = coalesce(stock, 0L))

  waiver_county_raw <- waiver_long |>
    mutate(
      county_fips = if ("FIPS" %in% names(waiver_long)) as.integer(FIPS) else as.integer(county_fips),
      year = if ("YEAR" %in% names(waiver_long)) as.integer(YEAR) else as.integer(year)
    ) |>
    filter(!is.na(county_fips), LOC_TYPE == "County") |>
    distinct(county_fips, year)

  list(
    analysis_panel = analysis_panel,
    county_panel = county_panel,
    event2 = event2,
    ds_stock = ds_stock,
    format_stock = format_stock,
    waiver_county_raw = waiver_county_raw,
    rucc = rucc,
    format_colors = format_colors,
    waiver_colors = waiver_colors,
    rural_split_colors = rural_split_colors,
    waiver_ts_colors = waiver_ts_colors,
    theme_im = theme_im
  )
}
