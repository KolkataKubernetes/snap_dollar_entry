#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_7_snap_retailer_composition_flipped.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Create the 2010 vs 2019 SNAP retailer composition figure
#                   with raw stock counts on the y-axis and share labels.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, aggregate retailer
#                   stock across the four benchmark format groups, compute each
#                   format's share in 2010 and 2019, and save the chart and the
#                   plotted data.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_2_snap_retailer_composition_flipped.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_2_snap_retailer_composition_flipped.csv`
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

composition_data <- ctx$format_stock |>
  filter(year %in% c(2010, 2019)) |>
  group_by(year, format) |>
  summarise(total_stock = sum(stock, na.rm = TRUE), .groups = "drop") |>
  group_by(year) |>
  mutate(
    share = total_stock / sum(total_stock),
    share_label = scales::percent(share, accuracy = 0.1)
  ) |>
  ungroup() |>
  mutate(
    format = factor(format, levels = names(ctx$format_colors)),
    year = factor(year, levels = c(2010, 2019))
  )

p <- ggplot(
  composition_data,
  aes(x = format, y = total_stock, fill = year)
) +
  geom_col(position = position_dodge(width = 0.72), width = 0.62) +
  geom_text(
    aes(label = share_label),
    position = position_dodge(width = 0.72),
    vjust = -0.4,
    size = 3.8
  ) +
  scale_fill_manual(values = c("2010" = "grey60", "2019" = "#c5050c")) +
  scale_y_continuous(
    labels = scales::label_comma(),
    expand = expansion(mult = c(0, 0.12))
  ) +
  labs(
    title = "SNAP Retailer Composition",
    subtitle = "Raw retailer stock by format, with within-year share labels, 2010 vs 2019",
    x = NULL,
    y = "Retailer stock count",
    fill = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_1_2_snap_retailer_composition_flipped.jpeg"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)

write.csv(
  composition_data,
  descriptive_output_path("3_1_1_2_snap_retailer_composition_flipped.csv"),
  row.names = FALSE
)
