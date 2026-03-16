library(dplyr)
library(readr)
library(stringr)

repo_root <- normalizePath(getwd())

read_root_path <- function(path_file) {
  readLines(path_file, warn = FALSE)[[1]] |>
    str_trim() |>
    str_remove_all("^['\"]|['\"]$")
}

state_targets <- c("MN", "VT", "WV")

processed_root <- read_root_path(file.path(repo_root, "2_processed_data", "processed_root.txt"))
temp_output_dir <- file.path(repo_root, "1_code", "TEMP", "waiver_state_diffs")
dir.create(temp_output_dir, recursive = TRUE, showWarnings = FALSE)

diff_path <- file.path(processed_root, "2_0_waivers", "2_0_5_waiver_panel_diff_summary.rds")
generated_path <- file.path(processed_root, "2_0_waivers", "2_0_4_waived_data_consolidated_long.rds")
benchmark_path <- file.path(repo_root, "legacy", "Box", "data", "waivers", "waived_data_consolidated_long.csv")

diff_obj <- readRDS(diff_path)
generated_long <- readRDS(generated_path)
benchmark_long <- readr::read_csv(
  benchmark_path,
  col_types = cols(FIPS = col_character()),
  show_col_types = FALSE
)

state_extracts <- lapply(state_targets, function(state_abbrev) {
  list(
    benchmark_only = diff_obj$long_key_comparison |>
      filter(STATE_ABBREV == state_abbrev, generated_n == 0, benchmark_n > 0),
    generated_only = diff_obj$long_key_comparison |>
      filter(STATE_ABBREV == state_abbrev, generated_n > 0, benchmark_n == 0),
    benchmark_rows = benchmark_long |>
      filter(STATE_ABBREV == state_abbrev),
    generated_rows = generated_long |>
      filter(STATE_ABBREV == state_abbrev)
  )
})

names(state_extracts) <- state_targets

summary_tbl <- bind_rows(lapply(names(state_extracts), function(state_abbrev) {
  extract <- state_extracts[[state_abbrev]]
  tibble(
    STATE_ABBREV = state_abbrev,
    benchmark_only_keys = nrow(extract$benchmark_only),
    generated_only_keys = nrow(extract$generated_only),
    benchmark_rows = nrow(extract$benchmark_rows),
    generated_rows = nrow(extract$generated_rows)
  )
}))

saveRDS(
  list(
    summary = summary_tbl,
    states = state_extracts,
    sources = list(
      diff_path = diff_path,
      generated_path = generated_path,
      benchmark_path = benchmark_path
    )
  ),
  file.path(temp_output_dir, "waiver_state_diff_extracts.rds")
)

readr::write_csv(summary_tbl, file.path(temp_output_dir, "waiver_state_diff_summary.csv"))

for (state_abbrev in names(state_extracts)) {
  extract <- state_extracts[[state_abbrev]]
  readr::write_csv(extract$benchmark_only, file.path(temp_output_dir, paste0(state_abbrev, "_benchmark_only.csv")))
  readr::write_csv(extract$generated_only, file.path(temp_output_dir, paste0(state_abbrev, "_generated_only.csv")))
  readr::write_csv(extract$benchmark_rows, file.path(temp_output_dir, paste0(state_abbrev, "_benchmark_rows.csv")))
  readr::write_csv(extract$generated_rows, file.path(temp_output_dir, paste0(state_abbrev, "_generated_rows.csv")))
}

print(summary_tbl)
cat(sprintf("\nSaved state diff extracts to %s\n", temp_output_dir))
