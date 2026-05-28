#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_2_2_weighted_distance_trends.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Build yearly weighted-distance trend figures for each
#                   benchmark retailer format.
# INPUTS:           `2_10_retail_access/2_10_2_county_retail_access_weighted_summary.rds`
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_2_weighted_distance_trend_<format_slug>.csv`
#                   `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_2_weighted_distance_trend_<format_slug>.jpeg`
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

trend_data <- ctx$county_summary |>
  group_by(rural_status, year, format, weight_type) |>
  summarise(
    mean_county_weighted_distance_miles = safe_mean(county_weighted_distance_miles),
    n_counties = sum(!is.na(county_weighted_distance_miles)),
    .groups = "drop"
  ) |>
  mutate(
    rural_status = factor(rural_status, levels = ctx$rural_levels),
    format = factor(format, levels = ctx$format_levels),
    weight_type = factor(weight_type, levels = ctx$weight_levels)
  )

for (current_format in ctx$format_levels) {
  format_trend <- trend_data |>
    filter(format == current_format)

  format_slug <- slugify_label(current_format)

  readr::write_csv(
    format_trend,
    retail_access_output_path(sprintf("3_1_2_2_weighted_distance_trend_%s.csv", format_slug))
  )

  p <- ggplot(
    format_trend,
    aes(
      x = year,
      y = mean_county_weighted_distance_miles,
      color = weight_type,
      group = weight_type
    )
  ) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    facet_wrap(~ rural_status, ncol = 1) +
    scale_color_manual(values = ctx$weight_colors, breaks = ctx$weight_levels) +
    scale_x_continuous(breaks = 2014:2019) +
    labs(
      title = sprintf("Weighted Nearest Distance Trends: %s", current_format),
      subtitle = "Mean county weighted distance in miles by rural status and weight regime.",
      x = "Year",
      y = "Weighted nearest distance (miles)",
      color = NULL
    ) +
    ctx$theme_im(base_size = 13)

  ggsave(
    filename = retail_access_output_path(sprintf("3_1_2_2_weighted_distance_trend_%s.jpeg", format_slug)),
    plot = p,
    width = 9,
    height = 7,
    units = "in"
  )
}
