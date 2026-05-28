#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_2_5_below_125_fpl_format_trends.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Compare the below-1.25x-FPL weighted nearest distance
#                   metric over time, with one line per retailer format.
# INPUTS:           `2_10_retail_access/2_10_2_county_retail_access_weighted_summary.rds`
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_5_below_125_fpl_format_trends.csv`
#                   `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_5_below_125_fpl_format_trends.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(readr)

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

source(file.path(script_dir, "shared_retail_access_descriptive_helpers.R"))

safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}

ctx <- load_retail_access_context()

fpl_format_trend <- ctx$county_summary |>
  filter(weight_type == "Below 1.25x FPL") |>
  group_by(year, format) |>
  summarise(
    mean_county_weighted_distance_miles = safe_mean(county_weighted_distance_miles),
    n_counties = sum(!is.na(county_weighted_distance_miles)),
    .groups = "drop"
  ) |>
  mutate(
    format = factor(format, levels = ctx$format_levels)
  )

readr::write_csv(
  fpl_format_trend,
  retail_access_output_path("3_1_2_5_below_125_fpl_format_trends.csv")
)

p <- ggplot(
  fpl_format_trend,
  aes(
    x = year,
    y = mean_county_weighted_distance_miles,
    color = format,
    group = format
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_color_manual(values = ctx$format_colors, breaks = ctx$format_levels) +
  scale_x_continuous(breaks = 2014:2019) +
  labs(
    title = "Below-1.25x-FPL Weighted Nearest Distance by Retailer Format",
    subtitle = "Mean county weighted distance in miles. One line per retailer format.",
    x = "Year",
    y = "Weighted nearest distance (miles)",
    color = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = retail_access_output_path("3_1_2_5_below_125_fpl_format_trends.jpeg"),
  plot = p,
  width = 9,
  height = 6,
  units = "in"
)
