#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_2_6_snap_dollar_store_supermarket_threshold_trends.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Plot SNAP-recipient-weighted dollar-store distance over
#                   time for counties with low SNAP-recipient-weighted
#                   supermarket distance, using year-specific median, bottom
#                   quartile, and bottom decile supermarket-distance cutoffs.
# INPUTS:           `2_10_retail_access/2_10_2_county_retail_access_weighted_summary.rds`
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_6_snap_dollar_store_supermarket_threshold_trends.csv`
#                   `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_6_snap_dollar_store_supermarket_threshold_trends.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(readr)
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

source(file.path(script_dir, "shared_retail_access_descriptive_helpers.R"))

safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}

safe_quantile <- function(x, prob) {
  valid <- x[!is.na(x)]

  if (!length(valid)) {
    return(NA_real_)
  }

  as.numeric(stats::quantile(valid, probs = prob, names = FALSE, type = 7))
}

ctx <- load_retail_access_context()

snap_county_panel <- ctx$county_summary |>
  filter(weight_type == "SNAP recipient households") |>
  select(year, county_fips, format, county_weighted_distance_miles)

supermarket_thresholds <- snap_county_panel |>
  filter(format == "Supermarkets") |>
  group_by(year) |>
  summarise(
    median_cutoff_miles = safe_quantile(county_weighted_distance_miles, 0.50),
    bottom_quartile_cutoff_miles = safe_quantile(county_weighted_distance_miles, 0.25),
    bottom_decile_cutoff_miles = safe_quantile(county_weighted_distance_miles, 0.10),
    .groups = "drop"
  ) |>
  pivot_longer(
    cols = c(
      median_cutoff_miles,
      bottom_quartile_cutoff_miles,
      bottom_decile_cutoff_miles
    ),
    names_to = "threshold_type",
    values_to = "supermarket_cutoff_miles"
  ) |>
  mutate(
    threshold_type = factor(
      threshold_type,
      levels = c(
        "median_cutoff_miles",
        "bottom_quartile_cutoff_miles",
        "bottom_decile_cutoff_miles"
      ),
      labels = c(
        "At or below median supermarket distance",
        "At or below bottom quartile supermarket distance",
        "At or below bottom decile supermarket distance"
      )
    )
  )

eligible_counties <- snap_county_panel |>
  filter(format == "Supermarkets") |>
  left_join(supermarket_thresholds, by = "year", relationship = "many-to-many") |>
  filter(
    !is.na(county_weighted_distance_miles),
    !is.na(supermarket_cutoff_miles),
    county_weighted_distance_miles <= supermarket_cutoff_miles
  ) |>
  select(year, county_fips, threshold_type, supermarket_cutoff_miles)

trend_data <- snap_county_panel |>
  filter(format == "Dollar stores") |>
  inner_join(eligible_counties, by = c("year", "county_fips")) |>
  group_by(year, threshold_type, supermarket_cutoff_miles) |>
  summarise(
    mean_county_weighted_distance_miles = safe_mean(county_weighted_distance_miles),
    n_counties = sum(!is.na(county_weighted_distance_miles)),
    .groups = "drop"
  ) |>
  mutate(
    threshold_type = factor(
      threshold_type,
      levels = levels(supermarket_thresholds$threshold_type)
    )
  ) |>
  arrange(threshold_type, year)

readr::write_csv(
  trend_data,
  retail_access_output_path("3_1_2_6_snap_dollar_store_supermarket_threshold_trends.csv")
)

threshold_colors <- c(
  "At or below median supermarket distance" = "black",
  "At or below bottom quartile supermarket distance" = "#0072B2",
  "At or below bottom decile supermarket distance" = "#c5050c"
)

p <- ggplot(
  trend_data,
  aes(
    x = year,
    y = mean_county_weighted_distance_miles,
    color = threshold_type,
    group = threshold_type
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_color_manual(values = threshold_colors, breaks = names(threshold_colors)) +
  scale_x_continuous(breaks = 2014:2019) +
  labs(
    title = "SNAP-Weighted Dollar-Store Distance in Low-Supermarket-Distance Counties",
    subtitle = "Counties are grouped each year using SNAP-weighted supermarket-distance cutoffs.",
    x = "Year",
    y = "Weighted nearest dollar-store distance (miles)",
    color = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = retail_access_output_path("3_1_2_6_snap_dollar_store_supermarket_threshold_trends.jpeg"),
  plot = p,
  width = 9,
  height = 6,
  units = "in"
)
