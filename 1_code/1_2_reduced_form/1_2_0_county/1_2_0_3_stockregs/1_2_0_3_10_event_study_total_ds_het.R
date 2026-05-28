#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_3_10_event_study_total_ds_het.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 26, 2026
# Description:      Standalone Sun-Abraham event study for Dollar Store stock
#                   that interacts treatment timing with grouped 2013 Rural-
#                   Urban Continuum Code (RUCC) categories and uses the county
#                   stock-regression benchmark sample.
# INPUTS:           `2_9_analysis/2_9_4_county_stockreg_sample.rds`
#                   `2_processed_data/processed_root.txt`
#                   `0_inputs/input_root.txt`
#                   `0_7_Ruralurbancontinuumcodes2013.xls`
# PROCEDURES:       Load the county stock-regression benchmark sample, merge
#                   county-level RUCC codes, estimate grouped heterogeneity
#                   Sun-Abraham specifications under two RUCC groupings, and
#                   save event-study / ATT outputs.
# OUTPUTS:          `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_3_stockregs/3_2_0_3_10_event_study_ihs_total_ds_stock_het*.pdf`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_3_stockregs/3_2_0_3_10_event_study_ihs_total_ds_stock_het*.tex`
#                   `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_3_stockregs/3_2_0_3_10_event_study_ihs_total_ds_stock_het_metro_nonmetro*.pdf`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_3_stockregs/3_2_0_3_10_event_study_ihs_total_ds_stock_het_metro_nonmetro*.tex`
# DEPENDENCIES:     `dplyr`, `fixest`, `ggplot2`, `readxl`,
#                   `shared_reduced_form_helpers.R`
# Review focus:     Verify that the RUCC merge and grouped interaction logic
#                   match the existing heterogeneity branch, with Dollar Store
#                   stock replacing Dollar Store entry counts as the outcome.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(fixest)
library(ggplot2)
library(readxl)

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

format_p_value <- function(p_value) {
  ifelse(p_value < 0.001, "<0.001", sprintf("%.3f", p_value))
}

significance_stars <- function(p_value) {
  ifelse(
    p_value < 0.01,
    "***",
    ifelse(p_value < 0.05, "**", ifelse(p_value < 0.1, "*", ""))
  )
}

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
    "   \\multicolumn{4}{l}{\\emph{Dependent variable: log(total\\_ds\\_stock + sqrt(total\\_ds\\_stock\\^2 + 1))}}\\\\",
    "   \\multicolumn{4}{l}{\\emph{County and year fixed effects included; county-clustered standard errors}}\\\\",
    "   \\multicolumn{4}{l}{\\emph{Signif. Codes: ***: 0.01, **: 0.05, *: 0.1}}\\\\",
    "\\end{tabular}",
    "\\par\\endgroup"
  )

  writeLines(table_lines, con = output_path)
}

repo_root <- get_repo_root()
setwd(repo_root)

event_study_sample <- load_event_study_sample() |>
  mutate(
    county_fips_chr = sprintf("%05d", county_fips)
  )

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

heterogeneity_model_three <- feols(
  log(total_ds_stock + sqrt(total_ds_stock^2 + 1)) ~
    sunab(eventYear2, year, ref.p = -1, no_agg = TRUE):factor(rucc_group_code_three) +
    population + wage + meanInc + rent + urate |
    county_fips + year,
  data = event_study_sample,
  vcov = ~county_fips
)

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
    title = "IHS(Dollar Store Stock) by Grouped 2013 RUCC Category",
    subtitle = "Sun-Abraham event-study coefficients with benchmark stock-regression covariates",
    x = "Event time",
    y = "Coefficient"
  ) +
  theme_im(base_size = 12)

heterogeneity_model_two <- feols(
  log(total_ds_stock + sqrt(total_ds_stock^2 + 1)) ~
    sunab(eventYear2, year, ref.p = -1, no_agg = TRUE):factor(rucc_group_code_two) +
    population + wage + meanInc + rent + urate |
    county_fips + year,
  data = event_study_sample,
  vcov = ~county_fips
)

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
    title = "IHS(Dollar Store Stock) by Metro vs Non-Metro RUCC Category",
    subtitle = "Sun-Abraham event-study coefficients with benchmark stock-regression covariates",
    x = "Event time",
    y = "Coefficient"
  ) +
  theme_im(base_size = 12)

plot_path_three <- reduced_form_plot_path("3_2_0_3_10_event_study_ihs_total_ds_stock_het.pdf")
table_path_three <- reduced_form_table_path("3_2_0_3_10_event_study_ihs_total_ds_stock_het.tex")
plot_path_two <- reduced_form_plot_path("3_2_0_3_10_event_study_ihs_total_ds_stock_het_metro_nonmetro.pdf")
table_path_two <- reduced_form_table_path("3_2_0_3_10_event_study_ihs_total_ds_stock_het_metro_nonmetro.tex")

ggsave(plot_path_three, event_plot_three, width = 11, height = 8.5, units = "in")
write_att_table(att_results_three, table_path_three)

ggsave(plot_path_two, event_plot_two, width = 10, height = 6.5, units = "in")
write_att_table(att_results_two, table_path_two)

cat("RUCC stock heterogeneity event study completed.\n")
cat(sprintf("Sample rows: %s\n", nrow(event_study_sample)))
cat(sprintf("Sample counties: %s\n", dplyr::n_distinct(event_study_sample$county_fips)))
cat(sprintf("Three-group RUCC groups in sample: %s\n", paste(unique(att_results_three$group_label), collapse = "; ")))
cat(sprintf("Three-group plot: %s\n", plot_path_three))
cat(sprintf("Three-group ATT table: %s\n", table_path_three))
cat(sprintf("Two-group RUCC groups in sample: %s\n", paste(unique(att_results_two$group_label), collapse = "; ")))
cat(sprintf("Two-group plot: %s\n", plot_path_two))
cat(sprintf("Two-group ATT table: %s\n", table_path_two))
