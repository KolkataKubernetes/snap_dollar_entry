#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_1_retailer_format_stock_index_rural.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 12, 2026
# Description:      Create the rural-county retailer format stock index figure.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, compute the 2010-based
#                   format stock index for rural counties, and save the figure.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_1_retailer_format_stock_index_rural.jpeg`
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

#(1) Build the rural retailer format stock index -------------------------------
format_trend_rural <- ctx$format_stock |>
  left_join(ctx$rucc, by = "county_fips") |>
  mutate(is_rural = coalesce(is_rural, FALSE)) |>
  filter(is_rural, year %in% 2010:2020) |>
  group_by(year, format) |>
  summarise(mean_stock = mean(stock, na.rm = TRUE), .groups = "drop") |>
  group_by(format) |>
  mutate(
    base_2010 = mean_stock[year == 2010],
    stock_index_2010 = if_else(base_2010 == 0, NA_real_, 100 * mean_stock / base_2010)
  ) |>
  ungroup()

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(format_trend_rural, aes(x = year, y = stock_index_2010, color = format, group = format)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_color_manual(values = ctx$format_colors, breaks = names(ctx$format_colors)) +
  scale_x_continuous(breaks = 2010:2020) +
  labs(
    title = "Retailer Format Stock Index - Rural Counties",
    subtitle = "County-average stock index (2010 = 100), RUCC 4-9 counties",
    x = "Year",
    y = "Stock index (2010 = 100)",
    color = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_1_1_retailer_format_stock_index_rural.jpeg"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)
