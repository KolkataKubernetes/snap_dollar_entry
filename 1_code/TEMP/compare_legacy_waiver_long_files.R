library(dplyr)
library(readr)
library(stringr)
library(tibble)

repo_root <- normalizePath(getwd())

normalize_fips <- function(x) {
  digits <- str_extract(as.character(x), "\\d+")
  digits <- ifelse(is.na(digits) | digits == "", NA_character_, digits)
  ifelse(is.na(digits), NA_character_, str_pad(digits, width = 5, side = "left", pad = "0"))
}

read_waiver_long <- function(path) {
  readr::read_csv(path, col_types = cols(FIPS = col_character()), show_col_types = FALSE) |>
    mutate(
      DATE_START = as.Date(DATE_START),
      DATE_END = as.Date(DATE_END),
      MONTH_DATE = as.Date(MONTH_DATE),
      YEAR = as.integer(YEAR),
      ENTIRE_STATE = as.integer(ENTIRE_STATE),
      FIPS = normalize_fips(FIPS)
    )
}

legacy_box_path <- file.path(
  repo_root,
  "legacy",
  "Box",
  "data",
  "waivers",
  "waived_data_consolidated_long.csv"
)

legacy_processed_path <- file.path(
  repo_root,
  "legacy",
  "2_processed_data",
  "waiver_data_consolidated_long.csv"
)

output_path <- file.path(
  repo_root,
  "1_code",
  "TEMP",
  "compare_legacy_waiver_long_files_diff.rds"
)

legacy_box <- read_waiver_long(legacy_box_path)
legacy_processed <- read_waiver_long(legacy_processed_path)

key_cols <- c(
  "STATE",
  "STATE_ABBREV",
  "ENTIRE_STATE",
  "LOC",
  "LOC_TYPE",
  "SOURCE_DOC",
  "DATE_START",
  "DATE_END",
  "MONTH_DATE",
  "YEAR",
  "FIPS"
)

box_counts <- legacy_box |>
  count(across(all_of(key_cols)), name = "legacy_box_n")

processed_counts <- legacy_processed |>
  count(across(all_of(key_cols)), name = "legacy_processed_n")

key_comparison <- full_join(box_counts, processed_counts, by = key_cols) |>
  mutate(
    legacy_box_n = coalesce(legacy_box_n, 0L),
    legacy_processed_n = coalesce(legacy_processed_n, 0L),
    match_flag = legacy_box_n == legacy_processed_n
  )

diff_object <- list(
  paths = tibble(
    artifact = c("legacy_box", "legacy_processed"),
    path = c(legacy_box_path, legacy_processed_path)
  ),
  summary = tibble(
    legacy_box_rows = nrow(legacy_box),
    legacy_processed_rows = nrow(legacy_processed),
    legacy_box_unique_keys = nrow(box_counts),
    legacy_processed_unique_keys = nrow(processed_counts),
    mismatched_key_counts = sum(!key_comparison$match_flag),
    box_only_key_counts = sum(key_comparison$legacy_box_n > 0 & key_comparison$legacy_processed_n == 0),
    processed_only_key_counts = sum(key_comparison$legacy_box_n == 0 & key_comparison$legacy_processed_n > 0)
  ),
  key_comparison = key_comparison,
  box_only_states = key_comparison |>
    filter(legacy_box_n > 0, legacy_processed_n == 0) |>
    distinct(STATE_ABBREV, STATE) |>
    arrange(STATE_ABBREV),
  processed_only_states = key_comparison |>
    filter(legacy_box_n == 0, legacy_processed_n > 0) |>
    distinct(STATE_ABBREV, STATE) |>
    arrange(STATE_ABBREV)
)

saveRDS(diff_object, output_path)

print(diff_object$summary)
cat(sprintf("\nSaved diff object to %s\n", output_path))
