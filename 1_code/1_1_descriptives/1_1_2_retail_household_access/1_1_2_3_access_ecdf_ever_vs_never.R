#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_2_3_access_ecdf_ever_vs_never.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Build weighted ECDF comparisons of tract nearest-retailer
#                   access between ever-treated and never-treated counties.
# INPUTS:           `2_10_retail_access/2_10_3_retail_access_ecdf_source.rds`
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_3_weighted_ecdf_<format_slug>_<weight_slug>.csv`
#                   `3_outputs/3_1_descriptives/3_1_2_retail_access/3_1_2_3_weighted_ecdf_<format_slug>_<weight_slug>.jpeg`
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

build_weighted_ecdf <- function(df) {
  valid <- df |>
    filter(!is.na(nearest_distance_miles), !is.na(raw_weight), raw_weight > 0)

  if (!nrow(valid)) {
    return(tibble::tibble(
      nearest_distance_miles = numeric(),
      plot_weight = numeric(),
      ecdf = numeric()
    ))
  }

  valid |>
    group_by(nearest_distance_miles) |>
    summarise(raw_weight = sum(raw_weight), .groups = "drop") |>
    arrange(nearest_distance_miles) |>
    mutate(
      plot_weight = raw_weight / sum(raw_weight),
      ecdf = cumsum(plot_weight)
    ) |>
    select(nearest_distance_miles, plot_weight, ecdf)
}

ctx <- load_retail_access_context()

for (current_format in ctx$format_levels) {
  for (current_weight in ctx$weight_levels) {
    ecdf_points <- ctx$ecdf_source |>
      filter(format == current_format, weight_type == current_weight) |>
      group_by(rural_status, year_label, treatment_group) |>
      group_modify(~ build_weighted_ecdf(.x)) |>
      ungroup()

    format_slug <- slugify_label(current_format)
    weight_slug <- slugify_label(current_weight)

    readr::write_csv(
      ecdf_points,
      retail_access_output_path(
        sprintf("3_1_2_3_weighted_ecdf_%s_%s.csv", format_slug, weight_slug)
      )
    )

    p <- ggplot(
      ecdf_points,
      aes(
        x = nearest_distance_miles,
        y = ecdf,
        color = treatment_group,
        group = treatment_group
      )
    ) +
      geom_step(linewidth = 1) +
      facet_grid(rural_status ~ year_label) +
      scale_color_manual(values = ctx$treatment_colors) +
      labs(
        title = sprintf("Weighted ECDF of Nearest Distance: %s", current_format),
        subtitle = sprintf("Weight regime: %s", current_weight),
        x = "Nearest retailer distance (miles)",
        y = "Weighted ECDF",
        color = NULL
      ) +
      ctx$theme_im(base_size = 13)

    ggsave(
      filename = retail_access_output_path(
        sprintf("3_1_2_3_weighted_ecdf_%s_%s.jpeg", format_slug, weight_slug)
      ),
      plot = p,
      width = 10,
      height = 7,
      units = "in"
    )
  }
}
