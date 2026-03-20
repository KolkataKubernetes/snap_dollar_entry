library(dplyr)
library(stargazer)
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

aba1 <- load_event_study_sample()
outcomes_df <- as.data.frame(aba1[, event_study_outcomes, drop = FALSE])
names(outcomes_df) <- unname(event_study_labels)

stargazer::stargazer(
  outcomes_df,
  type = "latex",
  summary = TRUE,
  title = "Descriptive Statistics: Retail Outlets",
  label = "tab:desc_stats",
  digits = 2,
  out = reduced_form_table_path("3_2_0_0_1_desc_stats_outcomes.tex")
)
