#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_3_retail_format_pre_post.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 12, 2026
# Description:      Create the treated-county pre/post retail format growth
#                   figure split by rural versus non-rural counties.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, compute pre/post
#                   treatment growth by format and rural status, and save the
#                   figure.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_3_retail_format_pre_post.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)

source("1_code/shared_us_analysis_helpers.R")
ctx <- load_us_analysis_context()

#(1) Build the pre/post growth summary ----------------------------------------
format_growth_summary <- ctx$format_stock |>
  inner_join(ctx$event2, by = "county_fips") |>
  mutate(tau = year - eventYear2) |>
  filter(tau %in% -3:3) |>
  left_join(ctx$rucc, by = "county_fips") |>
  mutate(
    is_rural = coalesce(is_rural, FALSE),
    county_group = if_else(is_rural, "Rural counties", "Non-rural counties")
  ) |>
  group_by(county_fips, format, county_group) |>
  summarise(
    pre_stock = mean(stock[tau %in% -3:-1], na.rm = TRUE),
    post_stock = mean(stock[tau %in% 0:3], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(log_growth = log1p(post_stock) - log1p(pre_stock)) |>
  group_by(format, county_group) |>
  summarise(
    approx_pct_growth = 100 * (exp(mean(log_growth, na.rm = TRUE)) - 1),
    .groups = "drop"
  ) |>
  mutate(
    format = factor(format, levels = names(ctx$format_colors)),
    county_group = factor(county_group, levels = c("Rural counties", "Non-rural counties"))
  )

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(
  format_growth_summary,
  aes(x = format, y = approx_pct_growth, fill = county_group)
) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.75)) +
  scale_fill_manual(values = ctx$rural_split_colors) +
  labs(
    title = "06 Retail Format Pre/Post Conferral Growth",
    subtitle = "Treated counties, approximate percent growth from tau -3:-1 to tau 0:3, by rural status",
    x = NULL,
    y = "Approx. percent growth",
    fill = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_3_retail_format_pre_post.jpeg"),
  plot = p,
  width = 9,
  height = 6,
  units = "in"
)
