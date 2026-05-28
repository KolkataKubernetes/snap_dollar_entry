#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_10_event_study_distance_dollar_stores_urban_rural_het.R
# Description:      Metro versus non-metro heterogeneity Sun-Abraham event
#                   study for SNAP-recipient-weighted dollar-store distance.
# INPUTS:           `2_10_retail_access/2_10_6_event_study_sample_distance_snap_recipients.rds`
#                   `0_inputs/input_root.txt`
#                   `0_7_Ruralurbancontinuumcodes2013.xls`
# OUTPUTS:          `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_2c_distance_SNAP_recipients_regs/3_2_10_event_study_distance_dollar_stores_urban_rural_het.pdf`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_2c_distance_SNAP_recipients_regs/3_2_10_event_study_distance_dollar_stores_urban_rural_het.tex`
# DEPENDENCIES:     `dplyr`, `fixest`, `ggplot2`, `readxl`,
#                   `shared_reduced_form_helpers.R`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(fixest)
library(ggplot2)
library(readxl)

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(active_path)) return(dirname(normalizePath(active_path)))
  }
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) return(dirname(normalizePath(frame$ofile)))
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
    "   Urban/Rural Group & ATT & Std. Error & p-value\\\\",
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
    "   \\multicolumn{4}{l}{\\emph{Dependent variable: Dollar Stores Distance}}\\\\",
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
  mutate(county_fips_chr = sprintf("%05d", county_fips))

input_root <- read_root_path("0_inputs/input_root.txt")
rucc_path <- file.path(input_root, "0_7_Ruralurbancontinuumcodes2013.xls")

rucc_lookup <- read_excel(rucc_path, sheet = "Rural-urban Continuum Code 2013") |>
  transmute(
    county_fips_chr = as.character(FIPS),
    rucc_2013 = as.integer(RUCC_2013)
  ) |>
  distinct()

event_study_sample <- event_study_sample |>
  left_join(rucc_lookup, by = "county_fips_chr") |>
  filter(!is.na(rucc_2013), !is.na(distance_dollar_stores)) |>
  mutate(
    rucc_group_code_two = dplyr::case_when(
      rucc_2013 %in% 1:3 ~ 1L,
      rucc_2013 %in% 4:9 ~ 2L,
      TRUE ~ NA_integer_
    ),
    group_label = dplyr::case_when(
      rucc_group_code_two == 1L ~ "Metro counties (RUCC 1-3)",
      rucc_group_code_two == 2L ~ "Non-metro counties (RUCC 4-9)",
      TRUE ~ NA_character_
    )
  ) |>
  filter(!is.na(rucc_group_code_two))

heterogeneity_model <- feols(
  distance_dollar_stores ~
    sunab(eventYear2, year, ref.p = 0, no_agg = TRUE):factor(rucc_group_code_two) +
    population + wage + meanInc + rent + urate |
    county_fips + year,
  data = event_study_sample,
  vcov = ~county_fips
)

event_profile_results <- as.data.frame(
  aggregate(heterogeneity_model, "year::(-?[0-9]+).*factor\\(rucc_group_code_two\\)([0-9]+)$")
)
event_profile_results$term <- row.names(event_profile_results)

event_profile_results <- event_profile_results |>
  select(term, everything()) |>
  mutate(
    event_time = as.integer(sub("::.*$", "", term)),
    group_code = as.integer(sub("^.*::", "", term)),
    conf_low = Estimate - stats::qnorm(0.975) * `Std. Error`,
    conf_high = Estimate + stats::qnorm(0.975) * `Std. Error`
  ) |>
  left_join(
    event_study_sample |>
      distinct(group_code = rucc_group_code_two, group_label),
    by = "group_code"
  ) |>
  arrange(group_code, event_time)

att_results <- as.data.frame(
  aggregate(heterogeneity_model, c(ATT = "year::[0-9]+.*factor\\(rucc_group_code_two\\)([0-9]+)$"))
)
att_results$term <- row.names(att_results)

att_results <- att_results |>
  select(term, everything()) |>
  mutate(group_code = as.integer(sub("^.*::", "", term))) |>
  left_join(
    event_study_sample |>
      distinct(group_code = rucc_group_code_two, group_label),
    by = "group_code"
  ) |>
  mutate(
    p_value_label = format_p_value(`Pr(>|t|)`),
    stars = significance_stars(`Pr(>|t|)`)
  ) |>
  arrange(group_code)

event_plot <- ggplot(
  event_profile_results,
  aes(x = event_time, y = Estimate)
) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
  geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.4, color = "#1B4F72") +
  geom_line(linewidth = 0.7, color = "#1B4F72") +
  geom_point(size = 1.8, color = "#1B4F72") +
  facet_wrap(~group_label, ncol = 2) +
  scale_x_continuous(breaks = sort(unique(event_profile_results$event_time))) +
  labs(
    title = "Dollar Stores Distance by Metro vs Non-Metro RUCC Category",
    subtitle = "SNAP-recipient-weighted outcome",
    x = "Event time",
    y = "Coefficient"
  ) +
  theme_im(base_size = 12)

plot_path <- reduced_form_plot_path("3_2_10_event_study_distance_dollar_stores_urban_rural_het.pdf")
table_path <- reduced_form_table_path("3_2_10_event_study_distance_dollar_stores_urban_rural_het.tex")

ggsave(plot_path, event_plot, width = 10, height = 6.5, units = "in")
write_att_table(att_results, table_path)

cat("Urban/rural heterogeneity event study completed.\n")
cat(sprintf("Sample rows: %s\n", nrow(event_study_sample)))
cat(sprintf("Sample counties: %s\n", dplyr::n_distinct(event_study_sample$county_fips)))
cat(sprintf("Plot: %s\n", plot_path))
cat(sprintf("ATT table: %s\n", table_path))
