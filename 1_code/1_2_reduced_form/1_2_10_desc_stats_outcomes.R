library(dplyr)
library(stargazer)
source("1_code/1_2_reduced_form/shared_reduced_form_helpers.R")

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
  out = reduced_form_table_path("3_2_10_desc_stats_outcomes.tex")
)
