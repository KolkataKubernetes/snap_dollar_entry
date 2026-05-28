#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_2_1_weighted_distance_snapshot_table.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Build the weighted-distance snapshot table for `2014` and
#                   `2019`, split by urban and rural counties.
# INPUTS:           `2_10_retail_access/2_10_2_county_retail_access_weighted_summary.rds`
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_1_weighted_distance_snapshot_table.csv`
#                   `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_1_weighted_distance_snapshot_table.jpeg`
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

ctx <- load_retail_access_context()

snapshot_table <- ctx$county_summary |>
  filter(year %in% c(2014L, 2019L)) |>
  group_by(rural_status, year, format, weight_type) |>
  summarise(
    mean_county_weighted_distance_miles = safe_mean(county_weighted_distance_miles),
    n_counties = sum(!is.na(county_weighted_distance_miles)),
    .groups = "drop"
  ) |>
  mutate(
    rural_status = factor(rural_status, levels = ctx$rural_levels),
    year = factor(as.character(year), levels = c("2014", "2019")),
    format = factor(format, levels = ctx$format_levels),
    weight_type = factor(weight_type, levels = ctx$weight_levels)
  ) |>
  arrange(rural_status, format, weight_type, year)

readr::write_csv(
  snapshot_table,
  retail_access_output_path("3_1_2_1_weighted_distance_snapshot_table.csv")
)

row_layout <- tidyr::expand_grid(
  format = factor(ctx$format_levels, levels = ctx$format_levels),
  weight_type = factor(ctx$weight_levels, levels = ctx$weight_levels)
) |>
  mutate(
    row_display = case_when(
      weight_type == "Total population" ~ paste0(as.character(format), " | Total population"),
      TRUE ~ paste0("  ", as.character(weight_type))
    ),
    row_key = sprintf("%02d__%s", row_number(), row_display),
    row_key = factor(row_key, levels = rev(row_key))
  )

table_plot_data <- row_layout |>
  left_join(snapshot_table, by = c("format", "weight_type")) |>
  mutate(
    cell_label = if_else(
      is.na(mean_county_weighted_distance_miles),
      "NA",
      sprintf("%.2f", mean_county_weighted_distance_miles)
    )
  )

p <- ggplot(
  table_plot_data,
  aes(x = year, y = row_key)
) +
  geom_tile(fill = "white", color = "grey85", linewidth = 0.4) +
  geom_text(aes(label = cell_label), size = 3.6) +
  facet_grid(rural_status ~ ., scales = "free_y", space = "free_y") +
  scale_y_discrete(labels = function(x) sub("^[0-9]+__", "", x)) +
  labs(
    title = "Weighted Nearest Retailer Distance Snapshots",
    subtitle = "Mean county weighted distance in miles, using 2014 and 2019 snapshots.",
    x = NULL,
    y = NULL
  ) +
  ctx$theme_im(base_size = 12) +
  theme(
    strip.text.y = element_text(face = "bold"),
    axis.text.y = element_text(hjust = 0),
    panel.grid = element_blank()
  )

ggsave(
  filename = retail_access_output_path("3_1_2_1_weighted_distance_snapshot_table.jpeg"),
  plot = p,
  width = 10,
  height = 9,
  units = "in"
)
