#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        shared_retail_access_descriptive_helpers.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Shared helper functions for retail-access descriptive
#                   outputs.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `2_10_retail_access/*.rds`
# OUTPUTS:          helper functions only
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(stringr)

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

source(file.path(dirname(script_dir), "shared_us_analysis_helpers.R"))

weight_colors <- c(
  "Total population" = "black",
  "Below 1.25x FPL" = "#0072B2",
  "SNAP recipient households" = "#c5050c"
)

treatment_colors <- c(
  "Ever-treated counties" = "#c5050c",
  "Never-treated counties" = "#0072B2"
)

retail_access_weight_levels <- c(
  "Total population",
  "Below 1.25x FPL",
  "SNAP recipient households"
)

retail_access_rural_levels <- c(
  "Urban counties",
  "Rural counties"
)

slugify_label <- function(x) {
  x |>
    str_to_lower() |>
    str_replace_all("[^a-z0-9]+", "_") |>
    str_replace_all("^_+|_+$", "")
}

load_retail_access_context <- function() {
  repo_root <- get_repo_root()
  setwd(repo_root)

  processed_root <- read_root_path("2_processed_data/processed_root.txt")

  county_summary <- readRDS(
    file.path(processed_root, "2_10_retail_access", "2_10_2_county_retail_access_weighted_summary.rds")
  )
  ecdf_source <- readRDS(
    file.path(processed_root, "2_10_retail_access", "2_10_3_retail_access_ecdf_source.rds")
  )

  list(
    county_summary = county_summary,
    ecdf_source = ecdf_source,
    format_colors = format_colors,
    weight_colors = weight_colors,
    treatment_colors = treatment_colors,
    theme_im = theme_im,
    format_levels = names(format_colors),
    weight_levels = retail_access_weight_levels,
    rural_levels = retail_access_rural_levels
  )
}

retail_access_output_path <- function(filename) {
  output_dir <- file.path("3_outputs", "3_1_descriptives", "3_1_2_retail_access")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  file.path(output_dir, filename)
}
