#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_1_9_retailer_format_stock_index_tract.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 21, 2026
# Description:      Create the tract retailer format stock index figure.
# INPUTS:           `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`
# PROCEDURES:       Load the tract panel, compute the tract-average 2010-based
#                   retailer format stock index for `2010:2019`, and save the
#                   figure into the existing retailer descriptive folder.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_9_retailer_format_stock_index_tract.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
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

source(file.path(script_dir, "shared_us_analysis_helpers.R"))

repo_root <- get_repo_root()
setwd(repo_root)

processed_root <- read_root_path("2_processed_data/processed_root.txt")

#(1) Load the tract panel and reshape retailer formats -------------------------
tract_panel <- readRDS(
  file.path(processed_root, "2_9_analysis", "2_9_6_us_analysis_panel_tract_timevarying_covariates.rds")
) |>
  select(
    tract_fips,
    year,
    total_ds,
    chain_convenience_store,
    chain_super_market,
    chain_multi_category
  )

format_trend <- tract_panel |>
  filter(year %in% 2010:2019) |>
  transmute(
    tract_fips,
    year,
    `Dollar stores` = total_ds,
    `Convenience stores` = chain_convenience_store,
    `Supermarkets` = chain_super_market,
    `Multi-category` = chain_multi_category
  ) |>
  pivot_longer(
    cols = c(`Dollar stores`, `Convenience stores`, `Supermarkets`, `Multi-category`),
    names_to = "format",
    values_to = "stock"
  ) |>
  group_by(year, format) |>
  summarise(mean_stock = mean(stock, na.rm = TRUE), .groups = "drop") |>
  group_by(format) |>
  mutate(
    base_2010 = mean_stock[year == 2010],
    stock_index_2010 = if_else(base_2010 == 0, NA_real_, 100 * mean_stock / base_2010)
  ) |>
  ungroup()

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(
  format_trend,
  aes(x = year, y = stock_index_2010, color = format, group = format)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_color_manual(values = format_colors, breaks = names(format_colors)) +
  scale_x_continuous(breaks = 2010:2019) +
  labs(
    title = "Retailer Format Stock Index _tract",
    subtitle = "Tract-average stock index (2010 = 100), all retained tracts",
    x = "Year",
    y = "Stock index (2010 = 100)",
    color = NULL
  ) +
  theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_1_9_retailer_format_stock_index_tract.jpeg"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)
