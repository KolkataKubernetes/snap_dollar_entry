#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_9b_event_study_all_table_poissonreg.R
# Description:      Estimate the county stock-Poisson ETWFE reduced form for every
#                   stock outcome and export a combined overall ATT table.
# INPUTS:           `2_9_analysis/2_9_5_county_stockpoissonreg_sample.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `3_outputs/3_0_tables/3_2_0_county/3_2_0_1b_stockpoissonregs/3_2_9b_event_study_all_stockpoissonreg*.tex`
#                   matching summary CSV export
# DEPENDENCIES:     `dplyr`, `shared_reduced_form_helpers.R`
# Review focus:     The column order and labels are inherited from
#                   `event_study_outcomes` and `event_study_labels`, so any
#                   change to those registries changes the interpretation of
#                   this table as well as its formatting.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)

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
    label = unname(event_study_labels[outcome])
  )

tex_path <- reduced_form_table_path("3_2_9b_event_study_all_stockpoissonreg.tex")
csv_path <- reduced_form_table_path("3_2_9b_event_study_all_stockpoissonreg.csv")

table_lines <- c(
  "\\begingroup",
  "\\centering",
  "\\begin{tabular}{lcccccc}",
  "   \\tabularnewline \\midrule \\midrule",
  "   Outcome & ATT & Std. Error & p-value & 95\\% CI & Treated Units & Control Units\\\\",
  "   \\midrule"
)

for (row_index in seq_len(nrow(summary_df))) {
  row <- summary_df[row_index, ]
  table_lines <- c(
    table_lines,
    sprintf(
      "   %s & %s & %s & %s & %s & %s & %s\\\\",
      row$label,
      format_att_value(row$att, row$p_value),
      ifelse(is.na(row$se), "", sprintf("%.4f", row$se)),
      format_p_value(row$p_value),
      format_ci_value(row$conf_int_lo, row$conf_int_hi),
      format(row$n_treated_units, big.mark = ","),
      format(row$n_control_units, big.mark = ",")
    )
  )
}

table_lines <- c(
  table_lines,
  "   \\midrule \\midrule",
  "   \\multicolumn{7}{l}{\\emph{Estimator: diff-diff WooldridgeDiD(method = poisson)}}\\\\",
  sprintf(
    "   \\\\multicolumn{7}{l}{\\\\emph{Control group: %s; county-clustered standard errors}}\\\\\\\\",
    control_group_display_label()
  ),
  "   \\multicolumn{7}{l}{\\emph{Signif. Codes: ***: 0.01, **: 0.05, *: 0.1}}\\\\",
  "\\end{tabular}",
  "\\par\\endgroup"
)

writeLines(table_lines, con = tex_path)
write.csv(summary_df, csv_path, row.names = FALSE)
