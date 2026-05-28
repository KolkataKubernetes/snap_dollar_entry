#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_6_10_event_study_total_ds_het.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 4, 2026
# Description:      Standalone Sun-Abraham LPM event study for the Dollar Store
#                   annual entry indicator that interacts treatment timing with
#                   grouped 2013 Rural-Urban Continuum Code (RUCC) categories
#                   and uses the benchmark reduced-form covariates.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
#                   `0_inputs/input_root.txt`
#                   `0_7_Ruralurbancontinuumcodes2013.xls`
# PROCEDURES:       Rebuild the benchmark 2014-2019 event-study sample, derive
#                   the Dollar Store annual entry indicator, merge county-level
#                   RUCC codes, estimate grouped heterogeneity Sun-Abraham
#                   specifications under two RUCC groupings, and save
#                   event-study / ATT outputs without sourcing reduced-form
#                   helper scripts.
# OUTPUTS:          `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_6_lpm_entryindicator_regs/3_2_0_6_10_event_study_lpm_total_ds_entry_het*.pdf`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_6_lpm_entryindicator_regs/3_2_0_6_10_event_study_lpm_total_ds_entry_het*.tex`
#                   `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_6_lpm_entryindicator_regs/3_2_0_6_10_event_study_lpm_total_ds_entry_het_metro_nonmetro*.pdf`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_6_lpm_entryindicator_regs/3_2_0_6_10_event_study_lpm_total_ds_entry_het_metro_nonmetro*.tex`
# DEPENDENCIES:     `dplyr`, `fixest`, `ggplot2`, `readxl`
# Review focus:     This script intentionally rebuilds the benchmark sample and
#                   path/output helpers inline rather than sourcing the shared
#                   helper file. Reviewers should verify the benchmark sample
#                   logic, the RUCC merge, and the two RUCC grouping schemes.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(fixest)
library(ggplot2)
library(readxl)

#(0) Resolve paths -------------------------------------------------------------
# This script is standalone by design, so it recreates the path and output
# helpers locally rather than depending on `shared_reduced_form_helpers.R`.

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

repo_root <- normalizePath(file.path(script_dir, "..", "..", "..", ".."))
setwd(repo_root)

# Purpose: read a one-line root-path pointer file used elsewhere in the repo.
# Inputs: `path_file`, a repository-relative text file containing one path.
# Returns: trimmed path string with surrounding quotes removed.
# Side effects: reads from disk.
read_root_path <- function(path_file) {
  path_value <- readLines(path_file, warn = FALSE)[[1]]
  path_value <- trimws(path_value)
  path_value <- sub("^['\"]", "", path_value)
  sub("['\"]$", "", path_value)
}

# Purpose: create the fixed output folders used by this heterogeneity script.
# Inputs: none.
# Returns: list with `plot_dir` and `table_dir`.
# Side effects: creates directories when missing.
ensure_output_dirs <- function() {
  plot_dir <- file.path("3_outputs", "3_2_reduced_form", "3_2_0_county", "3_2_0_6_lpm_entryindicator_regs")
  table_dir <- file.path("3_outputs", "3_0_tables", "3_2_0_county", "3_2_0_6_lpm_entryindicator_regs")

  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

  list(plot_dir = plot_dir, table_dir = table_dir)
}

# Purpose: version output filenames instead of overwriting prior analytical artifacts.
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

# Purpose: define the plot theme used by both RUCC heterogeneity figures.
# Inputs: `base_size`, the theme base text size.
# Returns: a ggplot theme object.
# Side effects: none.
theme_im <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(linewidth = 0.3),
      panel.grid.major.y = element_line(linewidth = 0.3),
      legend.position = "none",
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold")
    )
}

# Purpose: format p-values for the ATT LaTeX tables.
# Inputs: scalar `p_value`.
# Returns: string representation with `<0.001` for very small values.
# Side effects: none.
format_p_value <- function(p_value) {
  ifelse(p_value < 0.001, "<0.001", sprintf("%.3f", p_value))
}

# Purpose: map p-values into the star convention shown in the ATT tables.
# Inputs: scalar `p_value`.
# Returns: significance-star string.
# Side effects: none.
significance_stars <- function(p_value) {
  ifelse(
    p_value < 0.01,
    "***",
    ifelse(p_value < 0.05, "**", ifelse(p_value < 0.1, "*", ""))
  )
}

# Purpose: write the grouped ATT results into a compact LaTeX table.
# Inputs: `att_results`, a grouped ATT summary table, and `output_path`.
# Returns: no explicit return value.
# Side effects: writes a `.tex` file to disk.
write_att_table <- function(att_results, output_path) {
  table_lines <- c(
    "\\begingroup",
    "\\centering",
    "\\begin{tabular}{lccc}",
    "   \\tabularnewline \\midrule \\midrule",
    "   RUCC Group & ATT & Std. Error & p-value\\\\",
    "   \\midrule"
  )

  for (row_index in seq_len(nrow(att_results))) {
    table_lines <- c(
      table_lines,
      sprintf(
        "   %s & %s%s & (%s) & %s\\\\",
        att_results$group_label[[row_index]],
        sprintf("%.4f", att_results$Estimate[[row_index]]),
        att_results$stars[[row_index]],
        sprintf("%.4f", att_results$`Std. Error`[[row_index]]),
        att_results$p_value_label[[row_index]]
      )
    )
  }

  table_lines <- c(
    table_lines,
    "   \\midrule \\midrule",
    "   \\multicolumn{4}{l}{\\emph{Dependent variable: 1(total\\_ds > 0)}}\\\\",
    "   \\multicolumn{4}{l}{\\emph{County and year fixed effects included; county-clustered standard errors}}\\\\",
    "   \\multicolumn{4}{l}{\\emph{Signif. Codes: ***: 0.01, **: 0.05, *: 0.1}}\\\\",
    "\\end{tabular}",
    "\\par\\endgroup"
  )

  writeLines(table_lines, con = output_path)
}

#(1) Load the benchmark analysis panel and rebuild the event-study sample ------
# Review focus: this should mirror the benchmark reduced-form sample logic so
# the only new design choice in this script is the RUCC interaction.

processed_root <- read_root_path("2_processed_data/processed_root.txt")
analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

event_study_sample <- analysis_panel |>
  mutate(
    # These benchmark helper variables are rebuilt inline because this file
    # does not source the shared reduced-form helper script.
    lowq = total_ds + chain_convenience_store,
    # Monetary covariates are scaled to thousands to match the benchmark model.
    rent = rent / 1000,
    meanInc = meanInc / 1000,
    zl = dplyr::lag(urate),
    z = urate,
    no_stores = (total_ds + chain_super_market + chain_convenience_store + chain_multi_category) == 0,
    state_fips = county_fips %/% 1000,
    total_ds_entry = as.integer(total_ds > 0)
  ) |>
  filter(year %in% 2014:2019) |>
  mutate(
    # These sentinel values keep never-treated units in the sample while
    # preserving the benchmark event-time filtering logic.
    tau2 = if_else(is.na(tau2), -1000, tau2),
    eventYear2 = if_else(is.na(eventYear2), 10000, eventYear2),
    treated_group = eventYear2 != 10000
  ) |>
  group_by(state_fips) |>
  mutate(treated_state = sum(treated_group) > 0) |>
  group_by(county_fips) |>
  mutate(treated_county = sum(treated_group) > 0) |>
  ungroup() |>
  filter(year - eventYear2 >= -3, treated_state, treated_county) |>
  mutate(
    state_year = paste(state, year),
    # RUCC FIPS codes arrive as strings in the external workbook.
    county_fips_chr = sprintf("%05d", county_fips)
  )

#(2) Load and merge the 2013 RUCC county codes --------------------------------
# Review focus: this external workbook is the only non-benchmark input that
# changes the analysis, so the join key and grouping definitions matter.

input_root <- read_root_path("0_inputs/input_root.txt")
rucc_path <- file.path(input_root, "0_7_Ruralurbancontinuumcodes2013.xls")

rucc_lookup <- read_excel(rucc_path, sheet = "Rural-urban Continuum Code 2013") |>
  transmute(
    county_fips_chr = as.character(FIPS),
    rucc_2013 = as.integer(RUCC_2013),
    rucc_description = as.character(Description)
  ) |>
  distinct()

event_study_sample <- event_study_sample |>
  left_join(rucc_lookup, by = "county_fips_chr") |>
  filter(!is.na(rucc_2013)) |>
  mutate(
    # The three-group scheme separates metro, adjacent non-metro, and
    # non-adjacent non-metro counties.
    rucc_group_code_three = dplyr::case_when(
      rucc_2013 %in% 1:3 ~ 1L,
      rucc_2013 %in% c(4L, 6L, 8L) ~ 2L,
      rucc_2013 %in% c(5L, 7L, 9L) ~ 3L,
      TRUE ~ NA_integer_
    ),
    rucc_group_label_three = dplyr::case_when(
      rucc_group_code_three == 1L ~ "Metro counties (RUCC 1-3)",
      rucc_group_code_three == 2L ~ "Non-metro adjacent (RUCC 4, 6, 8)",
      rucc_group_code_three == 3L ~ "Non-metro non-adjacent (RUCC 5, 7, 9)",
      TRUE ~ NA_character_
    ),
    # The two-group scheme collapses all non-metro counties into one category.
    rucc_group_code_two = dplyr::case_when(
      rucc_2013 %in% 1:3 ~ 1L,
      rucc_2013 %in% 4:9 ~ 2L,
      TRUE ~ NA_integer_
    ),
    rucc_group_label_two = dplyr::case_when(
      rucc_group_code_two == 1L ~ "Metro counties (RUCC 1-3)",
      rucc_group_code_two == 2L ~ "Non-metro counties (RUCC 4-9)",
      TRUE ~ NA_character_
    )
  ) |>
  filter(!is.na(rucc_group_code_three), !is.na(rucc_group_code_two))

#(3) Estimate the three-group RUCC-interacted Sun-Abraham model ----------------
# Review focus: `no_agg = TRUE` keeps cohort-by-event-time coefficients so they
# can later be aggregated within each RUCC group.

heterogeneity_model_three <- feols(
  total_ds_entry ~
    sunab(eventYear2, year, ref.p = -1, no_agg = TRUE):factor(rucc_group_code_three) +
    population + wage + meanInc + rent + urate |
    county_fips + year,
  data = event_study_sample,
  vcov = ~county_fips
)

#(4) Aggregate the three-group coefficients to event-time and ATT summaries ----
# Aggregate the interacted event-study coefficients into group-specific event
# profiles and group-specific ATT summaries for reporting.

event_profile_results_three <- as.data.frame(
  aggregate(heterogeneity_model_three, "year::(-?[0-9]+).*factor\\(rucc_group_code_three\\)([0-9]+)$")
)
event_profile_results_three$term <- row.names(event_profile_results_three)

event_profile_results_three <- event_profile_results_three |>
  select(term, everything()) |>
  mutate(
    event_time = as.integer(sub("::.*$", "", term)),
    group_code = as.integer(sub("^.*::", "", term)),
    conf_low = Estimate - stats::qnorm(0.975) * `Std. Error`,
    conf_high = Estimate + stats::qnorm(0.975) * `Std. Error`
  ) |>
  left_join(
    event_study_sample |>
      distinct(group_code = rucc_group_code_three, group_label = rucc_group_label_three),
    by = "group_code"
  ) |>
  arrange(group_code, event_time)

att_results_three <- as.data.frame(
  aggregate(heterogeneity_model_three, c(ATT = "year::[0-9]+.*factor\\(rucc_group_code_three\\)([0-9]+)$"))
)
att_results_three$term <- row.names(att_results_three)

att_results_three <- att_results_three |>
  select(term, everything()) |>
  mutate(
    group_code = as.integer(sub("^.*::", "", term))
  ) |>
  left_join(
    event_study_sample |>
      distinct(group_code = rucc_group_code_three, group_label = rucc_group_label_three),
    by = "group_code"
  ) |>
  mutate(
    p_value_label = format_p_value(`Pr(>|t|)`),
    stars = significance_stars(`Pr(>|t|)`)
  ) |>
  arrange(group_code)

#(5) Build the three-group faceted event-study plot ----------------------------
# This figure keeps the three RUCC groups in separate panels so reviewers can
# compare event-time patterns without changing the underlying benchmark scales.

event_plot_three <- ggplot(
  event_profile_results_three,
  aes(x = event_time, y = Estimate)
) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
  geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.4, color = "#1B4F72") +
  geom_line(linewidth = 0.7, color = "#1B4F72") +
  geom_point(size = 1.8, color = "#1B4F72") +
  facet_wrap(~group_label, ncol = 3) +
  scale_x_continuous(breaks = sort(unique(event_profile_results_three$event_time))) +
  labs(
    title = "Dollar Store Entry Indicator by Grouped 2013 RUCC Category",
    subtitle = "Linear-probability Sun-Abraham event-study coefficients with benchmark reduced-form covariates",
    x = "Event time",
    y = "Coefficient"
  ) +
  theme_im(base_size = 12)

#(6) Estimate the metro-vs-non-metro RUCC-interacted model --------------------
# This second specification tests whether the finer three-group split matters
# relative to a simpler metro versus non-metro partition.

heterogeneity_model_two <- feols(
  total_ds_entry ~
    sunab(eventYear2, year, ref.p = -1, no_agg = TRUE):factor(rucc_group_code_two) +
    population + wage + meanInc + rent + urate |
    county_fips + year,
  data = event_study_sample,
  vcov = ~county_fips
)

#(7) Aggregate the metro-vs-non-metro coefficients ----------------------------
# Aggregate the interacted coefficients into the reporting format used for the
# second comparison figure and ATT table.

event_profile_results_two <- as.data.frame(
  aggregate(heterogeneity_model_two, "year::(-?[0-9]+).*factor\\(rucc_group_code_two\\)([0-9]+)$")
)
event_profile_results_two$term <- row.names(event_profile_results_two)

event_profile_results_two <- event_profile_results_two |>
  select(term, everything()) |>
  mutate(
    event_time = as.integer(sub("::.*$", "", term)),
    group_code = as.integer(sub("^.*::", "", term)),
    conf_low = Estimate - stats::qnorm(0.975) * `Std. Error`,
    conf_high = Estimate + stats::qnorm(0.975) * `Std. Error`
  ) |>
  left_join(
    event_study_sample |>
      distinct(group_code = rucc_group_code_two, group_label = rucc_group_label_two),
    by = "group_code"
  ) |>
  arrange(group_code, event_time)

att_results_two <- as.data.frame(
  aggregate(heterogeneity_model_two, c(ATT = "year::[0-9]+.*factor\\(rucc_group_code_two\\)([0-9]+)$"))
)
att_results_two$term <- row.names(att_results_two)

att_results_two <- att_results_two |>
  select(term, everything()) |>
  mutate(
    group_code = as.integer(sub("^.*::", "", term))
  ) |>
  left_join(
    event_study_sample |>
      distinct(group_code = rucc_group_code_two, group_label = rucc_group_label_two),
    by = "group_code"
  ) |>
  mutate(
    p_value_label = format_p_value(`Pr(>|t|)`),
    stars = significance_stars(`Pr(>|t|)`)
  ) |>
  arrange(group_code)

#(8) Build the metro-vs-non-metro faceted event-study plot --------------------
# The plotting logic mirrors the three-group figure so visual differences come
# from the grouping choice rather than from display conventions.

event_plot_two <- ggplot(
  event_profile_results_two,
  aes(x = event_time, y = Estimate)
) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
  geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.4, color = "#1B4F72") +
  geom_line(linewidth = 0.7, color = "#1B4F72") +
  geom_point(size = 1.8, color = "#1B4F72") +
  facet_wrap(~group_label, ncol = 2) +
  scale_x_continuous(breaks = sort(unique(event_profile_results_two$event_time))) +
  labs(
    title = "Dollar Store Entry Indicator by Metro vs Non-Metro RUCC Category",
    subtitle = "Linear-probability Sun-Abraham event-study coefficients with benchmark reduced-form covariates",
    x = "Event time",
    y = "Coefficient"
  ) +
  theme_im(base_size = 12)

#(9) Save both plots and both ATT tables --------------------------------------
# Review focus: outputs are versioned, so repeated runs should add suffixes
# rather than overwrite earlier heterogeneity artifacts.

output_dirs <- ensure_output_dirs()

plot_path_three <- next_available_path(
  file.path(output_dirs$plot_dir, "3_2_0_6_10_event_study_lpm_total_ds_entry_het.pdf")
)
table_path_three <- next_available_path(
  file.path(output_dirs$table_dir, "3_2_0_6_10_event_study_lpm_total_ds_entry_het.tex")
)

plot_path_two <- next_available_path(
  file.path(output_dirs$plot_dir, "3_2_0_6_10_event_study_lpm_total_ds_entry_het_metro_nonmetro.pdf")
)
table_path_two <- next_available_path(
  file.path(output_dirs$table_dir, "3_2_0_6_10_event_study_lpm_total_ds_entry_het_metro_nonmetro.tex")
)

ggsave(plot_path_three, event_plot_three, width = 11, height = 8.5, units = "in")
write_att_table(att_results_three, table_path_three)

ggsave(plot_path_two, event_plot_two, width = 10, height = 6.5, units = "in")
write_att_table(att_results_two, table_path_two)

#(10) Print a compact run summary ----------------------------------------------

cat("RUCC heterogeneity event study completed.\n")
cat(sprintf("Sample rows: %s\n", nrow(event_study_sample)))
cat(sprintf("Sample counties: %s\n", dplyr::n_distinct(event_study_sample$county_fips)))
cat(sprintf("Three-group RUCC groups in sample: %s\n", paste(unique(att_results_three$group_label), collapse = "; ")))
cat(sprintf("Three-group plot: %s\n", plot_path_three))
cat(sprintf("Three-group ATT table: %s\n", table_path_three))
cat(sprintf("Two-group RUCC groups in sample: %s\n", paste(unique(att_results_two$group_label), collapse = "; ")))
cat(sprintf("Two-group plot: %s\n", plot_path_two))
cat(sprintf("Two-group ATT table: %s\n", table_path_two))
