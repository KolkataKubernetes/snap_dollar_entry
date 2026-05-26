#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0b_build_event_study_sample.R
# Description:      Build the county nonlinear reduced-form sample used by the
#                   Poisson ETWFE branch from the processed county analysis
#                   panel.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `2_9_analysis/2_9_3_county_poissonreg_sample.rds`
# DEPENDENCIES:     `dplyr`
# Review focus:     This script uses the full county universe, including all
#                   never-treated counties, while extending the year window
#                   back to 2013 so the earliest treated cohort has a genuine
#                   pre-period for the Python `diff-diff` estimator.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)

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

repo_root <- get_repo_root()
setwd(repo_root)
processed_root <- read_root_path("2_processed_data/processed_root.txt")

analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

poisson_sample <- analysis_panel |>
  mutate(
    rent = rent / 1000,
    meanInc = meanInc / 1000
  ) |>
  filter(
    year %in% 2013:2019
  ) |>
  mutate(
    g_first_treat = if_else(is.na(eventYear2), 0L, as.integer(eventYear2)),
    treated_group = g_first_treat > 0L
  ) |>
  filter(
    g_first_treat == 0L | year - g_first_treat >= -3
  ) |>
  filter(
    is.finite(g_first_treat),
    g_first_treat >= 0
  )

output_path <- file.path(processed_root, "2_9_analysis", "2_9_3_county_poissonreg_sample.rds")
saveRDS(poisson_sample, output_path)

cat("County Poisson sample written.\n")
cat(sprintf("Path: %s\n", output_path))
cat(sprintf("Rows: %s\n", nrow(poisson_sample)))
cat(sprintf("Counties: %s\n", dplyr::n_distinct(poisson_sample$county_fips)))
cat(sprintf("Never-treated counties: %s\n", dplyr::n_distinct(poisson_sample$county_fips[poisson_sample$g_first_treat == 0L])))
cat(sprintf("Years: %s-%s\n", min(poisson_sample$year), max(poisson_sample$year)))
cat(sprintf("Cohorts: %s\n", paste(sort(unique(poisson_sample$g_first_treat)), collapse = ", ")))
