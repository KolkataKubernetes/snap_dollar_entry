#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_2_11_event_study_all_table_image_poissonreg.R
# Description:      Estimate the county stock-Poisson ETWFE reduced form for every
#                   stock outcome and render a slide-ready image table of
#                   overall ATT and fit metadata.
# INPUTS:           `2_9_analysis/2_9_5_county_stockpoissonreg_sample.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_2_stockpoissonregs/3_2_0_2_11_event_study_all_table_stockpoissonreg*.png`
#                   `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_2_stockpoissonregs/3_2_0_2_11_event_study_all_table_stockpoissonreg*.jpeg`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_2_stockpoissonregs/3_2_0_2_11_event_study_all_table_stockpoissonreg*.csv`
# DEPENDENCIES:     `dplyr`, `grid`, `gridExtra`, `gtable`,
#                   `shared_reduced_form_helpers.R`
# Review focus:     This is a presentation script rather than a new estimation
#                   design. Reviewers should verify that the ATT values remain
#                   consistent with the underlying Poisson ETWFE output used by
#                   the single-outcome and combined-table scripts.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(grid)
library(gridExtra)
library(gtable)

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(active_path)) return(dirname(normalizePath(active_path)))
  }
  for (frame in rev(sys.frames())) if (!is.null(frame$ofile)) return(dirname(normalizePath(frame$ofile)))
  normalizePath(getwd())
})

source(file.path(script_dir, "shared_reduced_form_helpers.R"))

model_outputs <- lapply(event_study_outcomes, function(outcome_name) {
  collect_model_outputs(run_event_study_model(outcome_name))
})
names(model_outputs) <- event_study_outcomes

summary_df <- bind_rows(lapply(model_outputs, `[[`, "simple_df")) |>
  mutate(
    label = unname(event_study_labels[outcome]),
    att_display = format_att_value(att, p_value),
    se_display = format_se_value(se),
    p_display = format_p_value(p_value),
    ci_display = format_ci_value(conf_int_lo, conf_int_hi),
    obs_display = format(n_obs, big.mark = ",")
  )

column_labels <- c(
  "Model:",
  paste0(summary_df$label, "\n(", seq_len(nrow(summary_df)), ")")
)

table_df <- data.frame(
  row_label = c(
    "ATT",
    "",
    "p-value",
    "95% CI",
    "Observations",
    "Treated units",
    "Control units"
  ),
  stringsAsFactors = FALSE
)

for (row_index in seq_len(nrow(summary_df))) {
  row <- summary_df[row_index, ]
  table_df[[row$label]] <- c(
    row$att_display,
    row$se_display,
    row$p_display,
    row$ci_display,
    row$obs_display,
    format(row$n_treated_units, big.mark = ","),
    format(row$n_control_units, big.mark = ",")
  )
}

names(table_df) <- column_labels

cell_theme <- gridExtra::ttheme_minimal(
  base_size = 12,
  colhead = list(
    fg_params = list(fontface = "plain", cex = 0.95),
    bg_params = list(fill = "white", col = NA),
    padding = unit(c(5, 5), "pt")
  ),
  core = list(
    fg_params = list(cex = 0.92),
    bg_params = list(fill = "white", col = NA),
    padding = unit(c(4, 4), "pt")
  )
)

table_grob <- tableGrob(table_df, rows = NULL, theme = cell_theme)

table_grob$widths <- unit.c(
  unit(1.8, "in"),
  rep(unit(1.2, "in"), ncol(table_df) - 1)
)

left_align_rows <- seq_len(nrow(table_df)) + 1

for (row_i in left_align_rows) {
  idx <- which(table_grob$layout$t == row_i & table_grob$layout$l == 1 & table_grob$layout$name == "core-fg")
  if (length(idx) == 1) {
    table_grob$grobs[[idx]]$hjust <- 0
    table_grob$grobs[[idx]]$x <- unit(0.02, "npc")
  }
}

separator_rows <- c(1, nrow(table_df) + 1)

for (row_i in separator_rows) {
  table_grob <- gtable::gtable_add_grob(
    table_grob,
    grobs = segmentsGrob(
      x0 = unit(0, "npc"),
      x1 = unit(1, "npc"),
      y0 = unit(1, "npc"),
      y1 = unit(1, "npc"),
      gp = gpar(col = "#7f7f7f", lwd = 1.0)
    ),
    t = row_i,
    l = 1,
    r = ncol(table_df)
  )
}

footnote_grob <- textGrob(
  paste0(
    "diff-diff WooldridgeDiD(method = poisson) with ",
    control_group_display_label(),
    " controls\nClustered (county_fips) standard-errors; Signif. Codes: ***: 0.01, **: 0.05, *: 0.1"
  ),
  x = unit(0, "npc"),
  hjust = 0,
  gp = gpar(fontsize = 10.5, col = "#444444", fontface = "italic")
)

full_grob <- arrangeGrob(
  table_grob,
  footnote_grob,
  ncol = 1,
  heights = unit.c(unit(1, "npc") - unit(0.7, "in"), unit(0.7, "in"))
)

png_path <- reduced_form_plot_path("3_2_0_2_11_event_study_all_table_stockpoissonreg.png")
jpeg_path <- reduced_form_plot_path("3_2_0_2_11_event_study_all_table_stockpoissonreg.jpeg")
csv_path <- reduced_form_table_path("3_2_0_2_11_event_study_all_table_stockpoissonreg.csv")

grDevices::png(filename = png_path, width = 3400, height = 1050, res = 240)
grid.newpage()
grid.draw(full_grob)
dev.off()

grDevices::jpeg(filename = jpeg_path, width = 3400, height = 1050, res = 240, quality = 100)
grid.newpage()
grid.draw(full_grob)
dev.off()

write.csv(table_df, csv_path, row.names = FALSE)
