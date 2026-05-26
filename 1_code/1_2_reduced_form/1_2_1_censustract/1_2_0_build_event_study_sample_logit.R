#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_build_event_study_sample_logit.R
# Description:      Build the tract nonlinear reduced-form sample used by the
#                   census-tract binary ETWFE branch from the processed tract
#                   analysis panel with time-varying covariates.
# INPUTS:           `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `2_9_analysis/2_9_8_censustract_logit_sample.rds`
# DEPENDENCIES:     `dplyr`
# Review focus:     Verify that the tract sample uses the county-aligned
#                   treatment cohort (`eventYear2`), retains never-treated
#                   tracts, and translates the tract-year dollar-store entry
#                   count into a binary outcome before the Python `diff-diff`
#                   estimator consumes the panel.
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

get_script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)

  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]])))
  }

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    script_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(script_path)) {
      return(normalizePath(script_path))
    }
  }

  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) {
      return(normalizePath(frame$ofile))
    }
  }

  NA_character_
}

find_repo_root <- function(start_path) {
  candidate <- normalizePath(start_path, winslash = "/", mustWork = FALSE)

  if (!dir.exists(candidate)) {
    candidate <- dirname(candidate)
  }

  repeat {
    if (file.exists(file.path(candidate, "AGENTS.md")) && dir.exists(file.path(candidate, "1_code"))) {
      return(candidate)
    }

    parent <- dirname(candidate)
    if (identical(parent, candidate)) {
      stop(sprintf("Could not locate repository root from '%s'.", start_path))
    }

    candidate <- parent
  }
}

get_repo_root <- function() {
  script_path <- get_script_path()
  start_path <- if (!is.na(script_path)) script_path else getwd()
  find_repo_root(start_path)
}

read_root_path <- function(path_file) {
  path_value <- readLines(path_file, warn = FALSE)[[1]]
  path_value <- trimws(path_value)
  gsub("^['\"]|['\"]$", "", path_value)
}

repo_root <- get_repo_root()
setwd(repo_root)
processed_root <- read_root_path("2_processed_data/processed_root.txt")

analysis_panel <- readRDS(
  file.path(processed_root, "2_9_analysis", "2_9_6_us_analysis_panel_tract_timevarying_covariates.rds")
)

tract_logit_sample <- analysis_panel |>
  mutate(
    rent = rent / 1000,
    meanInc = meanInc / 1000
  ) |>
  filter(year %in% 2013:2019) |>
  mutate(
    g_first_treat = if_else(is.na(eventYear2), 0L, as.integer(eventYear2)),
    treated_group = g_first_treat > 0L,
    total_ds_entry = as.integer(total_ds > 0)
  ) |>
  filter(
    g_first_treat == 0L | year - g_first_treat >= -3
  ) |>
  filter(
    is.finite(g_first_treat),
    g_first_treat >= 0
  )

output_path <- file.path(processed_root, "2_9_analysis", "2_9_8_censustract_logit_sample.rds")
saveRDS(tract_logit_sample, output_path)

cat("Census-tract logit sample written.\n")
cat(sprintf("Path: %s\n", output_path))
cat(sprintf("Rows: %s\n", nrow(tract_logit_sample)))
cat(sprintf("Tracts: %s\n", dplyr::n_distinct(tract_logit_sample$tract_fips)))
cat(sprintf("Treated tracts: %s\n", dplyr::n_distinct(tract_logit_sample$tract_fips[tract_logit_sample$g_first_treat > 0L])))
cat(sprintf("Never-treated tracts: %s\n", dplyr::n_distinct(tract_logit_sample$tract_fips[tract_logit_sample$g_first_treat == 0L])))
cat(sprintf("Years: %s-%s\n", min(tract_logit_sample$year), max(tract_logit_sample$year)))
cat(sprintf("Entry share: %.6f\n", mean(tract_logit_sample$total_ds_entry, na.rm = TRUE)))
cat(sprintf("Cohorts: %s\n", paste(sort(unique(tract_logit_sample$g_first_treat)), collapse = ", ")))
