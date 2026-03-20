#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_10_retail_format_pre_post_single_series.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Create the treated-county pre/post retail format growth
#                   figure as a single-series summary across all treated
#                   counties.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, compute county-level
#                   average annual stock in the pre window (tau = -3:-1) and
#                   post window (tau = 0:3), average the county-level log
#                   changes within each format, and save the figure and summary
#                   table.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_8_retail_format_pre_post_single_series.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_8_retail_format_pre_post_single_series.csv`
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

#(1) Build the single-series pre/post growth summary ---------------------------
format_growth_county <- ctx$format_stock |>
  inner_join(ctx$event2, by = "county_fips") |>
  mutate(tau = year - eventYear2) |>
  filter(tau %in% -3:3) |>
  group_by(county_fips, format) |>
  summarise(
    pre_stock = mean(stock[tau %in% -3:-1], na.rm = TRUE),
    post_stock = mean(stock[tau %in% 0:3], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(log_growth = log1p(post_stock) - log1p(pre_stock))

format_growth_summary <- format_growth_county |>
  group_by(format) |>
  summarise(
    mean_pre_stock = mean(pre_stock, na.rm = TRUE),
    mean_post_stock = mean(post_stock, na.rm = TRUE),
    approx_pct_growth = 100 * (exp(mean(log_growth, na.rm = TRUE)) - 1),
    treated_counties = n_distinct(county_fips),
    .groups = "drop"
  ) |>
  arrange(desc(approx_pct_growth)) |>
  mutate(
    format = factor(format, levels = format),
    label = sprintf("%.1f%%", approx_pct_growth),
    label_position = if_else(approx_pct_growth >= 0, approx_pct_growth + 0.15, 0.15)
  )

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(
  format_growth_summary,
  aes(x = format, y = approx_pct_growth, fill = format)
) +
  geom_col(width = 0.65, alpha = 0.95, show.legend = TRUE) +
  geom_text(
    aes(
      y = label_position,
      label = label,
    ),
    hjust = 0,
    size = 4
  ) +
  coord_flip(clip = "off") +
  scale_fill_manual(values = ctx$format_colors, breaks = names(ctx$format_colors)) +
  labs(
    title = "Retail Format Pre/Post Conferral Growth",
    subtitle = "Treated counties. Change from average annual stock in tau = -3:-1 to tau = 0:3.",
    x = NULL,
    y = "Approx. percent growth",
    fill = NULL
  ) +
  ctx$theme_im(base_size = 13) +
  theme(
    legend.position = "top",
    plot.margin = margin(10, 24, 10, 10)
  )

ggsave(
  filename = descriptive_output_path("3_1_1_8_retail_format_pre_post_single_series.jpeg"),
  plot = p,
  width = 9,
  height = 6,
  units = "in"
)

readr::write_csv(
  format_growth_summary,
  descriptive_output_path("3_1_1_8_retail_format_pre_post_single_series.csv")
)
