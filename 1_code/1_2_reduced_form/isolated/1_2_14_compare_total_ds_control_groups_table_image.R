#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_14_compare_total_ds_control_groups_table_image.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Render a slide-ready image table comparing the Dollar
#                   Stores reduced-form estimates under eventually-treated and
#                   all-never-treated control groups.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
# PROCEDURES:       Rebuild both control-group samples, estimate both reduced-
#                   form models, extract ATT and fit statistics, and save a
#                   PNG/JPEG comparison table.
# OUTPUTS:          `3_outputs/3_2_reduced_form/isolated/3_2_14_event_study_ihs_total_ds_compare_controls_table*.png`
#                   `3_outputs/3_2_reduced_form/isolated/3_2_14_event_study_ihs_total_ds_compare_controls_table*.jpeg`
#                   `3_outputs/3_0_tables/isolated/3_2_14_event_study_ihs_total_ds_compare_controls_table*.csv`
# DEPENDENCIES:     `dplyr`, `fixest`, `grid`, `gridExtra`, `gtable`, `readr`,
#                   `tibble`
# Review focus:     This is a presentation-oriented companion to the control-
#                   group comparison scripts. Reviewers should verify that the
#                   displayed ATT and fit statistics match the underlying models
#                   rather than treating this as an independent estimation file.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(fixest)
library(grid)
library(gridExtra)
library(gtable)
library(readr)
library(tibble)

# Resolve the script directory so this standalone file can find the repository root.
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

repo_root <- normalizePath(file.path(script_dir, "..", "..", ".."))
setwd(repo_root)

# Purpose: read a one-line root-path pointer file used elsewhere in the repo.
# Inputs: `path_file`, a repository-relative text file containing one path.
# Returns: trimmed path string with surrounding quotes removed.
# Side effects: reads from disk.
read_root_path <- function(path_file) {
  path_value <- readLines(path_file, warn = FALSE)[[1]]
  path_value <- trimws(path_value)
  path_value <- sub("^'", "", path_value)
  sub("'$", "", path_value)
}

# Purpose: create the isolated output folders for figures and tables.
# Inputs: none.
# Returns: no explicit return value.
# Side effects: creates directories when missing.
ensure_output_dirs <- function() {
  dir.create(file.path("3_outputs", "3_2_reduced_form", "isolated"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path("3_outputs", "3_0_tables", "isolated"), recursive = TRUE, showWarnings = FALSE)
}

# Purpose: version output filenames instead of overwriting prior artifacts.
# Inputs: `path`, the preferred output path.
# Returns: `path` itself or the next `_vNN` variant.
# Side effects: checks the filesystem for existing outputs.
next_available_path <- function(path) {
  if (!file.exists(path)) {
    return(path)
  }

  base <- tools::file_path_sans_ext(path)
  ext <- tools::file_ext(path)
  index <- 1
  candidate <- sprintf("%s_v%02d.%s", base, index, ext)

  while (file.exists(candidate)) {
    index <- index + 1
    candidate <- sprintf("%s_v%02d.%s", base, index, ext)
  }

  candidate
}

# Purpose: convert p-values into the significance star convention used in the image table.
# Inputs: scalar `p_value`.
# Returns: character star code.
# Side effects: none.
signif_stars <- function(p_value) {
  dplyr::case_when(
    is.na(p_value) ~ "",
    p_value <= 0.01 ~ "***",
    p_value <= 0.05 ~ "**",
    p_value <= 0.10 ~ "*",
    TRUE ~ ""
  )
}

# Purpose: combine the ATT estimate and significance markers into one display cell.
# Inputs: numeric `estimate` and `p_value`.
# Returns: formatted ATT string.
# Side effects: none.
format_att_cell <- function(estimate, p_value) {
  paste0(sprintf("%.4f", estimate), signif_stars(p_value))
}

# Purpose: reduce a fitted model to the ATT and fit statistics shown in the image table.
# Inputs: `model`, a fitted reduced-form model.
# Returns: named list of formatted display values.
# Side effects: none.
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

# Purpose: estimate the benchmark Dollar Stores reduced form on a supplied sample.
# Inputs: `data`, an already-filtered county-year sample.
# Returns: `fixest` model object.
# Side effects: none.
estimate_model <- function(data) {
  feols(
    log(total_ds + sqrt(total_ds^2 + 1)) ~
      sunab(eventYear2, year, ref.p = 0) +
      population + wage + meanInc + rent + urate |
      county_fips + year,
    data = data,
    vcov = ~county_fips
  )
}

# Load the county analysis panel that will be split into two alternative control-group samples.
processed_root <- read_root_path("2_processed_data/processed_root.txt")
analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

# Rebuild the common base panel before defining the two competing control-group samples.
base_panel <- analysis_panel |>
  mutate(
    rent = rent / 1000,
    meanInc = meanInc / 1000,
    state_fips = county_fips %/% 1000
  ) |>
  filter(year %in% 2014:2019) |>
  mutate(
    tau2 = if_else(is.na(tau2), -1000, tau2),
    eventYear2 = if_else(is.na(eventYear2), 10000, eventYear2),
    treated_group = eventYear2 != 10000,
    never_treated = eventYear2 == 10000
  ) |>
  group_by(county_fips) |>
  mutate(treated_county = sum(treated_group) > 0) |>
  ungroup()

# Benchmark sample: eventually-treated counties only, with the benchmark event-time window.
eventually_treated_sample <- base_panel |>
  filter(year - eventYear2 >= -3, treated_county)

# Alternative sample: keep all never-treated counties in addition to the treated event-time window.
never_treated_sample <- base_panel |>
  filter(never_treated | year - eventYear2 >= -3)

# Estimate both control-group specifications and summarize them for display.
eventually_treated_model <- estimate_model(eventually_treated_sample)
never_treated_model <- estimate_model(never_treated_sample)

eventually_treated_summary <- extract_model_summary(eventually_treated_model)
never_treated_summary <- extract_model_summary(never_treated_model)

# Assemble the slide-ready table after both model summaries are available.
table_df <- data.frame(
  `Spec:` = c(
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
  `Eventually-treated controls\n(1)` = c(
    eventually_treated_summary$att,
    eventually_treated_summary$att_se,
    "",
    "Yes",
    "Yes",
    "",
    eventually_treated_summary$observations,
    eventually_treated_summary$r2,
    eventually_treated_summary$within_r2
  ),
  `Never-treated controls\n(2)` = c(
    never_treated_summary$att,
    never_treated_summary$att_se,
    "",
    "Yes",
    "Yes",
    "",
    never_treated_summary$observations,
    never_treated_summary$r2,
    never_treated_summary$within_r2
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Build the image-table grob used for both PNG and JPEG exports.
cell_theme <- gridExtra::ttheme_minimal(
  base_size = 14,
  colhead = list(
    fg_params = list(fontface = "plain", cex = 0.95),
    bg_params = list(fill = "white", col = NA),
    padding = unit(c(6, 6), "pt")
  ),
  core = list(
    fg_params = list(cex = 0.95),
    bg_params = list(fill = "white", col = NA),
    padding = unit(c(5, 5), "pt")
  )
)

table_grob <- tableGrob(
  table_df,
  rows = NULL,
  theme = cell_theme
)

table_grob$widths <- unit.c(
  unit(2.15, "in"),
  unit(2.55, "in"),
  unit(2.35, "in")
)

for (row_i in seq_len(nrow(table_df)) + 1) {
  idx <- which(table_grob$layout$t == row_i & table_grob$layout$l == 1 & table_grob$layout$name == "core-fg")
  if (length(idx) == 1) {
    table_grob$grobs[[idx]]$hjust <- 0
    table_grob$grobs[[idx]]$x <- unit(0.02, "npc")
  }
}

for (row_i in c(4, 7)) {
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

# Add a title so the exported image can stand alone in slides or notes.
title_grob <- textGrob(
  "Dollar Stores Reduced Form: Control Group Comparison",
  x = unit(0, "npc"),
  hjust = 0,
  gp = gpar(fontsize = 16, fontface = "bold")
)

footnote_grob <- textGrob(
  "Clustered (county_fips) standard-errors in parentheses\nSignif. Codes: ***: 0.01, **: 0.05, *: 0.1",
  x = unit(0, "npc"),
  hjust = 0,
  gp = gpar(fontsize = 11, col = "#444444", fontface = "italic")
)

full_grob <- arrangeGrob(
  title_grob,
  table_grob,
  footnote_grob,
  ncol = 1,
  heights = unit.c(unit(0.42, "in"), unit(1, "npc") - unit(1.0, "in"), unit(0.58, "in"))
)

# Create the isolated output folders and version all exported artifact names.
ensure_output_dirs()

png_path <- next_available_path(
  file.path("3_outputs", "3_2_reduced_form", "isolated", "3_2_14_event_study_ihs_total_ds_compare_controls_table.png")
)
jpeg_path <- next_available_path(
  file.path("3_outputs", "3_2_reduced_form", "isolated", "3_2_14_event_study_ihs_total_ds_compare_controls_table.jpeg")
)
csv_path <- next_available_path(
  file.path("3_outputs", "3_0_tables", "isolated", "3_2_14_event_study_ihs_total_ds_compare_controls_table.csv")
)

grDevices::png(
  filename = png_path,
  width = 1900,
  height = 980,
  res = 220
)
grid.newpage()
grid.draw(full_grob)
dev.off()

grDevices::jpeg(
  filename = jpeg_path,
  width = 1900,
  height = 980,
  res = 220,
  quality = 100
)
grid.newpage()
grid.draw(full_grob)
dev.off()

readr::write_csv(table_df, csv_path)

cat("Control-group comparison image table completed.\n")
cat(sprintf("PNG: %s\n", png_path))
cat(sprintf("JPEG: %s\n", jpeg_path))
cat(sprintf("CSV: %s\n", csv_path))
