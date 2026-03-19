#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_11_ds_stock_growth_by_treatment_status.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 18, 2026
# Description:      Create a dollar-store stock growth figure comparing ever-
#                   treated and never-treated counties.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, compute a 2010-based
#                   county-average dollar-store stock index by treatment
#                   status, and save the figure and supporting table.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_11_ds_stock_growth_by_treatment_status.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_11_ds_stock_growth_by_treatment_status.csv`
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

source(file.path(script_dir, "shared_us_analysis_helpers.R"))
ctx <- load_us_analysis_context()

treatment_colors <- c(
  "Ever treated counties" = "#c5050c",
  "Never treated counties" = "#0072B2"
)

#(1) Build the dollar-store stock growth series -------------------------------
stock_growth <- ctx$ds_stock |>
  filter(year %in% 2010:2020) |>
  group_by(year, ever_county_waived) |>
  summarise(mean_ds_stock = mean(ds_stock_count, na.rm = TRUE), .groups = "drop") |>
  mutate(
    treatment_group = if_else(
      ever_county_waived,
      "Ever treated counties",
      "Never treated counties"
    )
  ) |>
  group_by(treatment_group) |>
  mutate(
    base_2010 = mean_ds_stock[year == 2010],
    stock_index_2010 = if_else(base_2010 == 0, NA_real_, 100 * mean_ds_stock / base_2010)
  ) |>
  ungroup()

#(2) Save the figure ----------------------------------------------------------
p <- ggplot(
  stock_growth,
  aes(x = year, y = stock_index_2010, color = treatment_group, group = treatment_group)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_color_manual(values = treatment_colors, breaks = names(treatment_colors)) +
  scale_x_continuous(breaks = 2010:2020) +
  labs(
    title = "Dollar Store Stock Growth by Treatment Status",
    subtitle = "County-average stock index (2010 = 100)",
    x = "Year",
    y = "Stock index (2010 = 100)",
    color = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_11_ds_stock_growth_by_treatment_status.jpeg"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)

readr::write_csv(
  stock_growth,
  descriptive_output_path("3_1_11_ds_stock_growth_by_treatment_status.csv")
)
