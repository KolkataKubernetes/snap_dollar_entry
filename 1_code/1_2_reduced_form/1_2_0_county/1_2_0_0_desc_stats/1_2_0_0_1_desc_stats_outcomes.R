#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_0_1_desc_stats_outcomes.R
# Description:      Summarize the benchmark county event-study sample for the
#                   reduced-form outlet outcomes and export a LaTeX descriptive
#                   statistics table.
# INPUTS:           `2_9_analysis/2_9_2_event_study_sample.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `3_outputs/3_0_tables/3_2_0_county/3_2_0_0_desc_stats/3_2_0_0_1_desc_stats_outcomes*.tex`
# DEPENDENCIES:     `dplyr`, `stargazer`, `shared_reduced_form_helpers.R`
# Review focus:     This script summarizes the saved benchmark event-study
#                   sample rather than the full analysis panel, so reviewers
#                   should confirm that `event_study_outcomes` and
#                   `event_study_labels` still match the intended benchmark
#                   outcome list.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(stargazer)

# Resolve the script directory so the local helper copy can be sourced
# regardless of whether the script is run from the command line or an editor.
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

# Load the benchmark helper functions used to find the saved event-study sample
# and to version the exported LaTeX output path.
source(file.path(script_dir, "shared_reduced_form_helpers.R"))

# Read the benchmark event-study sample that already incorporates the reduced-form sample restrictions.
aba1 <- load_event_study_sample()

# Restrict the descriptive table to the benchmark outcome registry.
# Review focus: the displayed column labels come from `event_study_labels`, so
#               label order and outcome order need to remain synchronized.
outcomes_df <- as.data.frame(aba1[, event_study_outcomes, drop = FALSE])
names(outcomes_df) <- unname(event_study_labels)

# Export a LaTeX summary table using a versioned table path so prior outputs are preserved.
stargazer::stargazer(
  outcomes_df,
  type = "latex",
  summary = TRUE,
  title = "Descriptive Statistics: Retail Outlets",
  label = "tab:desc_stats",
  digits = 2,
  out = reduced_form_table_path("3_2_0_0_1_desc_stats_outcomes.tex")
)
