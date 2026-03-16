#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_0b_waiver_ingest.R
# Previous author:  Alejandro Herrera
# Current author:   Alejandro Herrera + Codex
# Last Updated:     March 16, 2026
# Description:      Standardize waiver geographies and produce the final long
#                   waiver panel used by the benchmark U.S. analysis.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `2_0_waivers/2_0_0_waiver_data_consolidated_generated.rds`
#                   `2_0_waivers/2_0_1_waiver_data_consolidated_benchmark.rds`
#                   `0_0_waivers/0_0_2_consolidated_panels/waived_data_consolidated_long.csv`
#                   `0_inputs/0_3_county_list/national_county.txt`
# OUTPUTS:          `2_0_waivers/2_0_2_waived_data_consolidated_long_generated.rds`
#                   `2_0_waivers/2_0_3_waived_data_consolidated_long_benchmark.rds`
#                   `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
#                   `2_0_waivers/2_0_5_waiver_panel_diff_summary.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file:
# - legacy/1_code/1_0_2_Standardize_Geographies.R

library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(tibble)
library(lubridate)

source("1_code/shared_ingest_helpers.R")

expand_month_rows <- function(df) {
  month_sequences <- purrr::map2(
    df$DATE_START,
    df$DATE_END,
    ~ seq.Date(from = .x, to = .y, by = "month")
  )

  month_lengths <- lengths(month_sequences)

  expanded <- df[rep(seq_len(nrow(df)), month_lengths), , drop = FALSE]
  expanded$MONTH_DATE <- as.Date(unlist(month_sequences))
  expanded$YEAR <- lubridate::year(expanded$MONTH_DATE)
  expanded
}

prepare_geo_crosswalk <- function(path) {
  readr::read_csv(
    path,
    col_names = c("STATE", "STATEFP", "COUNTYFP", "COUNTYNAME", "CLASSFP"),
    show_col_types = FALSE
  ) |>
    mutate(
      STATEFP = stringr::str_pad(as.character(STATEFP), width = 2, side = "left", pad = "0"),
      COUNTYFP = stringr::str_pad(as.character(COUNTYFP), width = 3, side = "left", pad = "0")
    ) |>
    transmute(
      STATE = STATE,
      COUNTYNAME = COUNTYNAME,
      FIPS = paste0(STATEFP, COUNTYFP)
    ) |>
    mutate(
      COUNTYNAME = COUNTYNAME |>
        str_to_lower() |>
        str_to_title() |>
        str_replace_all("City County", "City")
    )
}

apply_waiver_name_fixes <- function(df) {
  df |>
    mutate(
      LOC = str_replace_all(LOC, "\\bBiaden\\b", "Bladen"),
      LOC = str_replace_all(LOC, "\\bBighorn\\b", "Big Horn"),
      LOC = str_replace_all(LOC, "\\bCarterel\\b", "Carteret"),
      LOC = str_replace_all(LOC, "\\bCentra Costa\\b", "Contra Costa"),
      LOC = str_replace_all(LOC, "\\bDublin\\b", "Duplin"),
      LOC = str_replace_all(LOC, "\\bFemont\\b", "Fremont"),
      LOC = str_replace_all(LOC, "\\bIona\\b", "Ionia"),
      LOC = str_replace_all(LOC, "\\bLunenberg\\b", "Lunenburg"),
      LOC = str_replace_all(LOC, "\\bMclean\\b", "McLean"),
      LOC = str_replace_all(LOC, "\\bRollette\\b", "Rolette"),
      LOC = str_replace_all(LOC, "\\bTiaga\\b", "Tioga"),
      LOC = str_replace_all(LOC, "\\bUpsher\\b", "Upshur"),
      LOC = str_replace_all(LOC, "\\bWyth\\b", "Wythe"),
      LOC = str_replace_all(LOC, "\\bBaltimore City\\b", "Baltimore")
    )
}

standardize_loc_strings <- function(df) {
  df |>
    mutate(
      LOC = LOC |>
        str_to_lower() |>
        str_to_title(),
      LOC = if_else(LOC_TYPE == "County", paste(LOC, "County"), LOC),
      LOC = str_replace_all(LOC, "City County", "City"),
      LOC = case_when(
        LOC == "Petersburg County" & STATE_ABBREV == "VA" ~ "Petersburg City",
        LOC == "Williamsburg County" & STATE_ABBREV == "VA" ~ "Williamsburg City",
        LOC == "Martinsville County" & STATE_ABBREV == "VA" ~ "Martinsville City",
        TRUE ~ LOC
      )
    )
}

compare_panel_keys <- function(generated, benchmark, key_cols, artifact) {
  generated_counts <- generated |>
    count(across(all_of(key_cols)), name = "generated_n")
  benchmark_counts <- benchmark |>
    count(across(all_of(key_cols)), name = "benchmark_n")

  key_comparison <- full_join(generated_counts, benchmark_counts, by = key_cols) |>
    mutate(
      generated_n = coalesce(generated_n, 0L),
      benchmark_n = coalesce(benchmark_n, 0L),
      match_flag = generated_n == benchmark_n
    )

  summary_row <- tibble(
    artifact = artifact,
    generated_rows = nrow(generated),
    benchmark_rows = nrow(benchmark),
    generated_unique_keys = nrow(generated_counts),
    benchmark_unique_keys = nrow(benchmark_counts),
    mismatched_key_counts = sum(!key_comparison$match_flag)
  )

  list(summary = summary_row, comparison = key_comparison)
}

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

waiver_output_dir <- ensure_dir(file.path(processed_root, "2_0_waivers"))
county_crosswalk_path <- file.path(repo_root, "0_inputs", "0_3_county_list", "national_county.txt")
benchmark_long_path <- file.path(
  input_root,
  "0_0_waivers",
  "0_0_2_consolidated_panels",
  "waived_data_consolidated_long.csv"
)

generated_wide <- readRDS(file.path(waiver_output_dir, "2_0_0_waiver_data_consolidated_generated.rds"))
benchmark_wide <- readRDS(file.path(waiver_output_dir, "2_0_1_waiver_data_consolidated_benchmark.rds"))
geo <- prepare_geo_crosswalk(county_crosswalk_path)

generated_long <- generated_wide |>
  select(YEAR, STATE, STATE_ABBREV, ENTIRE_STATE, LOC, LOC_TYPE, DATE_START, DATE_END, SOURCE_DOC) |>
  mutate(
    DATE_START = as.Date(DATE_START),
    DATE_END = as.Date(DATE_END)
  ) |>
  filter(!is.na(DATE_START), !is.na(DATE_END)) |>
  expand_month_rows() |>
  apply_waiver_name_fixes() |>
  standardize_loc_strings()

state_rows <- generated_long |>
  filter(ENTIRE_STATE == 1) |>
  left_join(geo, by = c("STATE_ABBREV" = "STATE"), relationship = "many-to-many") |>
  mutate(
    LOC = COUNTYNAME,
    LOC_TYPE = "County"
  ) |>
  select(-COUNTYNAME)

county_rows <- generated_long |>
  filter(LOC_TYPE == "County") |>
  left_join(geo, by = c("LOC" = "COUNTYNAME", "STATE_ABBREV" = "STATE"))

other_rows <- generated_long |>
  filter(LOC_TYPE != "County", ENTIRE_STATE != 1) |>
  mutate(FIPS = NA_character_)

generated_long <- bind_rows(other_rows, county_rows, state_rows) |>
  mutate(FIPS = normalize_fips(FIPS)) |>
  arrange(STATE_ABBREV, LOC, MONTH_DATE, SOURCE_DOC)

benchmark_long <- readr::read_csv(
  benchmark_long_path,
  col_types = cols(FIPS = col_character()),
  show_col_types = FALSE
) |>
  mutate(
    DATE_START = as.Date(DATE_START),
    DATE_END = as.Date(DATE_END),
    MONTH_DATE = as.Date(MONTH_DATE),
    FIPS = normalize_fips(FIPS)
  ) |>
  arrange(STATE_ABBREV, LOC, MONTH_DATE, SOURCE_DOC)

saveRDS(
  generated_long,
  file.path(waiver_output_dir, "2_0_2_waived_data_consolidated_long_generated.rds")
)
saveRDS(
  benchmark_long,
  file.path(waiver_output_dir, "2_0_3_waived_data_consolidated_long_benchmark.rds")
)
saveRDS(
  generated_long,
  file.path(waiver_output_dir, "2_0_4_waived_data_consolidated_long.rds")
)

wide_compare <- compare_panel_keys(
  generated = generated_wide,
  benchmark = benchmark_wide,
  key_cols = intersect(names(generated_wide), names(benchmark_wide)),
  artifact = "wide_panel"
)
long_compare <- compare_panel_keys(
  generated = generated_long,
  benchmark = benchmark_long,
  key_cols = c(
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
  ),
  artifact = "long_panel"
)

diff_summary <- list(
  summary = bind_rows(wide_compare$summary, long_compare$summary),
  wide_key_comparison = wide_compare$comparison,
  long_key_comparison = long_compare$comparison
)

saveRDS(
  diff_summary,
  file.path(waiver_output_dir, "2_0_5_waiver_panel_diff_summary.rds")
)

print(diff_summary$summary)
