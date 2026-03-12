#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_4_ds_stock_trend_by_waiver.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 12, 2026
# Description:      Create the dollar-store stock trend figure by ever-waived
#                   county status.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
# PROCEDURES:       Load the shared descriptive context, compute mean county
#                   dollar-store stock by waiver status, and save the figure.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_4_ds_stock_trend_by_waiver.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)

source("1_code/shared_us_analysis_helpers.R")
ctx <- load_us_analysis_context()

#(1) Build the dollar-store stock trend ---------------------------------------
stock_trend_group <- ctx$ds_stock |>
  filter(year %in% 2010:2020) |>
  group_by(year, ever_county_waived) |>
  summarise(mean_ds_stock = mean(ds_stock_count, na.rm = TRUE), .groups = "drop") |>
  mutate(
    waiver_group = if_else(ever_county_waived, "Ever county-waived", "Never county-waived")
  )

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(
  stock_trend_group,
  aes(x = year, y = mean_ds_stock, color = waiver_group, group = waiver_group)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_color_manual(values = ctx$waiver_colors) +
  scale_x_continuous(breaks = 2010:2020) +
  labs(
    title = "01 Dollar Store Stock Trend by Waiver Status",
    subtitle = "County-average dollar-store stock",
    x = "Year",
    y = "Average stock per county",
    color = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_4_ds_stock_trend_by_waiver.jpeg"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)
