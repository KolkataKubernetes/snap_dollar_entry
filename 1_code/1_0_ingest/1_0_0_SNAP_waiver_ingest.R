#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_0_SNAP_waiver_ingest.R
# Previous author:  Inder Majumdar
# Current author:   Inder Majumdar + Codex
# Last Updated:     March 16, 2026
# Description:      Rebuild the consolidated wide ABAWD waiver panel from the
#                   raw annual Excel workbooks.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `0_0_waivers/0_0_1_ABAWD_panels/*.xlsx`
#                   `0_0_waivers/0_0_2_consolidated_panels/waiver_data_consolidated.csv`
# OUTPUTS:          `2_0_waivers/2_0_0_waiver_data_consolidated_generated.rds`
#                   `2_0_waivers/2_0_1_waiver_data_consolidated_benchmark.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file:
# - legacy/1_code/1_0_0_SNAP_waiver_ingest.R

library(dplyr)
library(purrr)
library(readr)
library(readxl)
library(lubridate)
library(zoo)

source("1_code/1_0_ingest/shared_ingest_helpers.R")

month_labels_between <- function(start_date, end_date) {
  if (is.na(start_date) || is.na(end_date)) {
    return(character())
  }

  format(
    seq(from = as.yearmon(start_date), to = as.yearmon(end_date), by = 1 / 12),
    "%b_%Y"
  )
}

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

waiver_input_dir <- file.path(input_root, "0_0_waivers", "0_0_1_ABAWD_panels")
benchmark_wide_path <- file.path(
  input_root,
  "0_0_waivers",
  "0_0_2_consolidated_panels",
  "waiver_data_consolidated.csv"
)
waiver_output_dir <- ensure_dir(file.path(processed_root, "2_0_waivers"))

waiver_files <- list.files(
  waiver_input_dir,
  pattern = "\\.xlsx$",
  full.names = TRUE
) |>
  sort()

if (!length(waiver_files)) {
  stop(sprintf("No waiver workbooks found in %s", waiver_input_dir))
}

generated_wide <- waiver_files |>
  map(readxl::read_excel) |>
  bind_rows() |>
  mutate(
    DATE_START = as.Date(DATE_START),
    DATE_END = as.Date(DATE_END)
  ) |>
  filter(!is.na(DATE_START), !is.na(DATE_END))

month_columns <- month_labels_between(
  min(generated_wide$DATE_START, na.rm = TRUE),
  max(generated_wide$DATE_END, na.rm = TRUE)
)

for (month_column in month_columns) {
  generated_wide[[month_column]] <- 0L
}

for (row_index in seq_len(nrow(generated_wide))) {
  active_months <- month_labels_between(
    generated_wide$DATE_START[[row_index]],
    generated_wide$DATE_END[[row_index]]
  )

  if (length(active_months)) {
    generated_wide[row_index, active_months] <- 1L
  }
}

benchmark_wide <- readr::read_csv(benchmark_wide_path, show_col_types = FALSE) |>
  mutate(
    DATE_START = as.Date(DATE_START),
    DATE_END = as.Date(DATE_END)
  )

saveRDS(
  generated_wide,
  file.path(waiver_output_dir, "2_0_0_waiver_data_consolidated_generated.rds")
)
saveRDS(
  benchmark_wide,
  file.path(waiver_output_dir, "2_0_1_waiver_data_consolidated_benchmark.rds")
)

message(sprintf("Saved raw waiver ingest outputs to %s", waiver_output_dir))



