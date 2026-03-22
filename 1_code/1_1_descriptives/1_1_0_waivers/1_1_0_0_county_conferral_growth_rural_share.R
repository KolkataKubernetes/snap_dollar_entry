#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_2_county_conferral_growth_rural_share.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 12, 2026
# Description:      Create the county waiver counts over time figure, split by
#                   rural, urban, and total counties.
# INPUTS:           `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, count county waivers by
#                   year and rural status, and save the figure.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_0_county_conferral_growth_rural_share.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)

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
ctx <- load_us_analysis_context()

#(1) Build the county-waiver time series --------------------------------------
waiver_year_ts <- ctx$waiver_county_raw |>
  left_join(ctx$rucc, by = "county_fips") |>
  mutate(is_rural = coalesce(is_rural, FALSE)) |>
  mutate(county_group = if_else(is_rural, "Rural counties", "Urban counties")) |>
  count(year, county_group, name = "waived_counties") |>
  bind_rows(
    ctx$waiver_county_raw |>
      count(year, name = "waived_counties") |>
      mutate(county_group = "Total counties")
  ) |>
  arrange(year, county_group)

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(
  waiver_year_ts,
  aes(x = year, y = waived_counties, color = county_group, group = county_group)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_color_manual(values = ctx$waiver_ts_colors) +
  scale_x_continuous(breaks = sort(unique(waiver_year_ts$year))) +
  labs(
    title = "County ABAWD Waivers by Year",
    subtitle = "Counts of counties with county-level waivers, split by rural vs urban",
    x = "Year",
    y = "Number of counties with waivers",
    color = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_0_0_county_conferral_growth_rural_share.jpeg"),
  plot = p,
  width = 9,
  height = 6,
  units = "in"
)
