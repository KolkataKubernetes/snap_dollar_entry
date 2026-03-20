library(dplyr)
library(grid)
library(gridExtra)
library(gtable)
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

source(file.path(script_dir, "shared_reduced_form_helpers.R"))

signif_stars <- function(p_value) {
  case_when(
    is.na(p_value) ~ "",
    p_value <= 0.01 ~ "***",
    p_value <= 0.05 ~ "**",
    p_value <= 0.10 ~ "*",
    TRUE ~ ""
  )
}

format_att_cell <- function(estimate, p_value) {
  paste0(sprintf("%.4f", estimate), signif_stars(p_value))
}

extract_model_summary <- function(model) {
  att_summary <- summary(model, agg = "att")
  att_row <- as.data.frame(coeftable(att_summary)) |>
    tibble::rownames_to_column("term") |>
    filter(term == "ATT")

  fit_stats <- fitstat(model, c("n", "r2", "wr2"))
  fit_values <- unclass(fit_stats)

  list(
    att = format_att_cell(att_row$Estimate[[1]], att_row$`Pr(>|t|)`[[1]]),
    att_se = paste0("(", sprintf("%.4f", att_row$`Std. Error`[[1]]), ")"),
    observations = format(as.integer(fit_values$n), big.mark = ","),
    r2 = sprintf("%.5f", fit_values$r2),
    within_r2 = sprintf("%.5f", fit_values$wr2)
  )
}

models <- lapply(event_study_outcomes, run_event_study_model)
names(models) <- event_study_outcomes

model_summaries <- lapply(models, extract_model_summary)

column_labels <- c(
  "Model:",
  paste0(unname(event_study_labels), "\n(", seq_along(event_study_labels), ")")
)

table_df <- data.frame(
  row_label = c(
    "ATT",
    "",
    "Fixed-effects",
    "county_fips",
    "year",
    "Fit statistics",
    "Observations",
    "R2",
    "Within R2"
  ),
  stringsAsFactors = FALSE
)

for (outcome in event_study_outcomes) {
  summary_i <- model_summaries[[outcome]]

  table_df[[event_study_labels[[outcome]]]] <- c(
    summary_i$att,
    summary_i$att_se,
    "",
    "Yes",
    "Yes",
    "",
    summary_i$observations,
    summary_i$r2,
    summary_i$within_r2
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

table_grob <- tableGrob(
  table_df,
  rows = NULL,
  theme = cell_theme
)

table_grob$widths <- unit.c(
  unit(1.8, "in"),
  unit(1.25, "in"),
  unit(1.25, "in"),
  unit(1.55, "in"),
  unit(1.25, "in"),
  unit(1.25, "in"),
  unit(1.25, "in"),
  unit(1.05, "in"),
  unit(1.25, "in")
)

left_align_rows <- seq_len(nrow(table_df)) + 1
left_align_cols <- 1

for (row_i in left_align_rows) {
  for (col_i in left_align_cols) {
    idx <- which(table_grob$layout$t == row_i & table_grob$layout$l == col_i & table_grob$layout$name == "core-fg")
    if (length(idx) == 1) {
      table_grob$grobs[[idx]]$hjust <- 0
      table_grob$grobs[[idx]]$x <- unit(0.02, "npc")
    }
  }
}

section_rows <- c(4, 7)

for (row_i in section_rows) {
  idx <- which(table_grob$layout$t == row_i & table_grob$layout$l == 1 & table_grob$layout$name == "core-fg")
  if (length(idx) == 1) {
    table_grob$grobs[[idx]]$gp <- gpar(fontface = "italic", col = "#444444")
  }
}

separator_rows <- c(1, 3, 6, nrow(table_df) + 1)

for (row_i in separator_rows) {
  table_grob <- gtable::gtable_add_grob(
    table_grob,
    grobs = segmentsGrob(
      x0 = unit(0, "npc"),
      x1 = unit(1, "npc"),
      y0 = unit(1, "npc"),
      y1 = unit(1, "npc"),
      gp = gpar(col = "#7f7f7f", lwd = ifelse(row_i %in% c(1, nrow(table_df) + 1), 1.2, 0.8))
    ),
    t = row_i,
    l = 1,
    r = ncol(table_df)
  )
}

footnote_grob <- textGrob(
  "Clustered (county_fips) standard-errors in parentheses\nSignif. Codes: ***: 0.01, **: 0.05, *: 0.1",
  x = unit(0, "npc"),
  hjust = 0,
  gp = gpar(fontsize = 10.5, col = "#444444", fontface = "italic")
)

full_grob <- arrangeGrob(
  table_grob,
  footnote_grob,
  ncol = 1,
  heights = unit.c(unit(1, "npc") - unit(0.55, "in"), unit(0.55, "in"))
)

png_path <- reduced_form_plot_path("3_2_11_event_study_ihs_all_table.png")
jpeg_path <- reduced_form_plot_path("3_2_11_event_study_ihs_all_table.jpeg")
csv_path <- reduced_form_table_path("3_2_11_event_study_ihs_all_table.csv")

grDevices::png(
  filename = png_path,
  width = 3400,
  height = 950,
  res = 240
)
grid.newpage()
grid.draw(full_grob)
dev.off()

grDevices::jpeg(
  filename = jpeg_path,
  width = 3400,
  height = 950,
  res = 240,
  quality = 100
)
grid.newpage()
grid.draw(full_grob)
dev.off()

readr::write_csv(table_df, csv_path)
