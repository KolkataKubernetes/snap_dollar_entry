#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_2_unemployment_rates.R
# Previous author:  Alejandro Herrera
# Current author:   Alejandro Herrera + Codex
# Last Updated:     March 16, 2026
# Description:      Promote the benchmark unemployment panel into the processed
#                   ingest layout.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `0_1_acs/0_1_1_unemployment.csv`
# OUTPUTS:          `2_1_acs/2_1_0_unemployment.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file:
# - legacy/Box/code/00 - Unemployment Rates.r

library(readr)

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

source(file.path(script_dir, "shared_ingest_helpers.R"))

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

unemployment_path <- file.path(input_root, "0_1_acs", "0_1_1_unemployment.csv")
acs_output_dir <- ensure_dir(file.path(processed_root, "2_1_acs"))

unemployment_panel <- readr::read_csv(unemployment_path, show_col_types = FALSE)
saveRDS(unemployment_panel, file.path(acs_output_dir, "2_1_0_unemployment.rds"))

message(sprintf("Saved unemployment panel to %s", acs_output_dir))
