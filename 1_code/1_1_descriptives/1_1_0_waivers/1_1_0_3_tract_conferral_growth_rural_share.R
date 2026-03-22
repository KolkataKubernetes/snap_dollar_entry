#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_0_3_tract_conferral_growth_rural_share.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 21, 2026
# Description:      Create the tract waiver counts over time figure, split by
#                   rural-county tracts, urban-county tracts, and total tracts.
# INPUTS:           `2_0_waivers/2_0_7_waived_data_consolidated_long_tract.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the tract-expanded waiver source directly, inherit
#                   rural status from county RUCC, count waived tracts by year
#                   and rural status, and save the figure into the existing
#                   waiver descriptive folder.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_3_tract_conferral_growth_rural_share.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(readxl)
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

source(file.path(script_dir, "shared_us_analysis_helpers.R"))

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

#(1) Load the tract waiver source and county rural-status lookup ---------------
waiver_long_tract <- readRDS(
  file.path(processed_root, "2_0_waivers", "2_0_7_waived_data_consolidated_long_tract.rds")
) |>
  transmute(
    tract_fips = str_pad(as.character(tract_fips), width = 11, side = "left", pad = "0"),
    county_fips = str_pad(as.character(county_fips), width = 5, side = "left", pad = "0"),
    year = as.integer(YEAR)
  ) |>
  distinct(tract_fips, county_fips, year)

rucc <- readxl::read_excel(file.path(input_root, "0_7_Ruralurbancontinuumcodes2023.xlsx")) |>
  transmute(
    county_fips = sprintf("%05d", as.integer(FIPS)),
    is_rural = RUCC_2023 >= 4
  ) |>
  distinct()

#(2) Build the tract-waiver time series ---------------------------------------
waiver_year_ts <- waiver_long_tract |>
  left_join(rucc, by = "county_fips") |>
  mutate(is_rural = coalesce(is_rural, FALSE)) |>
  mutate(tract_group = if_else(is_rural, "Rural-county tracts", "Urban-county tracts")) |>
  count(year, tract_group, name = "waived_tracts") |>
  bind_rows(
    waiver_long_tract |>
      count(year, name = "waived_tracts") |>
      mutate(tract_group = "Total tracts")
  ) |>
  arrange(year, tract_group)

waiver_ts_colors_tract <- c(
  "Rural-county tracts" = "#0072B2",
  "Urban-county tracts" = "grey60",
  "Total tracts" = "black"
)

#(3) Save the figure -----------------------------------------------------------
p <- ggplot(
  waiver_year_ts,
  aes(x = year, y = waived_tracts, color = tract_group, group = tract_group)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_color_manual(values = waiver_ts_colors_tract) +
  scale_x_continuous(breaks = sort(unique(waiver_year_ts$year))) +
  labs(
    title = "ABAWD Waiver Counts Over Time _tract",
    subtitle = "Counts of treated tracts, split by inherited county rural status",
    x = "Year",
    y = "Number of treated tracts",
    color = NULL
  ) +
  theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_0_3_tract_conferral_growth_rural_share.jpeg"),
  plot = p,
  width = 9,
  height = 6,
  units = "in"
)
