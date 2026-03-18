#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_6_snap_retailer_composition_ever_treated.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Create the 2014 vs 2019 SNAP retailer composition figure
#                   for ever county-waived counties only.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, restrict to counties
#                   that ever receive a county-level waiver, aggregate retailer
#                   stock across the four benchmark format groups, compute each
#                   format's share in 2014 and 2019, and save the chart and the
#                   plotted data.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_6_snap_retailer_composition_ever_treated.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_6_snap_retailer_composition_ever_treated.csv`
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

#(1) Build the composition table -----------------------------------------------
ever_treated_counties <- unique(ctx$event2$county_fips)

composition_data <- ctx$format_stock |>
  filter(county_fips %in% ever_treated_counties, year %in% c(2014, 2019)) |>
  group_by(year, format) |>
  summarise(total_stock = sum(stock, na.rm = TRUE), .groups = "drop") |>
  group_by(year) |>
  mutate(share = total_stock / sum(total_stock)) |>
  ungroup() |>
  mutate(
    format = factor(format, levels = names(ctx$format_colors)),
    year = factor(year, levels = c(2014, 2019))
  )

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(
  composition_data,
  aes(x = format, y = share, fill = year)
) +
  geom_col(position = position_dodge(width = 0.72), width = 0.62) +
  scale_fill_manual(values = c("2014" = "grey60", "2019" = "#c5050c")) +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title = "SNAP Retailer Composition - Ever County-Waived Counties",
    subtitle = "Retailer stock shares across benchmark format groups, 2014 vs 2019",
    x = NULL,
    y = "Share of retailer stock",
    fill = NULL
  ) +
  ctx$theme_im(base_size = 13)

ggsave(
  filename = descriptive_output_path("3_1_6_snap_retailer_composition_ever_treated.jpeg"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)

write.csv(
  composition_data,
  descriptive_output_path("3_1_6_snap_retailer_composition_ever_treated.csv"),
  row.names = FALSE
)
