#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_0b_waiver_ingest.R
# Previous author:  Alejandro Herrera
# Current author:   Alejandro Herrera + Inder Majumdar + Codex
# Last Updated:     March 16, 2026
# Description:      Standardize waiver geographies and produce the final long
#                   waiver panel used by the benchmark U.S. analysis.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `2_0_waivers/2_0_0_waiver_data_consolidated_generated.rds`
#                   `0_3_county_list/national_county.txt`
# OUTPUTS:          `2_0_waivers/2_0_2_waived_data_consolidated_long_generated.rds`
#                   `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file:
# - legacy/1_code/1_0_2_Standardize_Geographies.R

# -----------------------------
# 0) Setup and configuration
# -----------------------------

library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)

# --- Set local pathing to allow for script to run within IDE

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

# --- Helper function to expand wide waiver rows into county-month rows

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

# --- Helper function to prepare the Census county crosswalk

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

# --- Helper function to standardize known waiver-name typos before matching: From Alejandro's legacy code

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

# --- Helper function to standardize location strings before county matching

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

# --- Read paths for ingest, saving processed data

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

waiver_output_dir <- ensure_dir(file.path(processed_root, "2_0_waivers"))
county_crosswalk_path <- file.path(input_root, "0_3_county_list", "national_county.txt")

# -----------------------------
# 1) Data Ingest
# -----------------------------

generated_wide <- readRDS(file.path(waiver_output_dir, "2_0_0_waiver_data_consolidated_generated.rds"))
geo <- prepare_geo_crosswalk(county_crosswalk_path)

# -----------------------------
# 2) Data Transform ("Long" dataset), standardize geography
# -----------------------------

# --- Expand generated wide waiver panel to a monthly long file

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

# --- Expand entire-state waivers to county-level rows

state_rows <- generated_long |>
  filter(ENTIRE_STATE == 1) |>
  left_join(geo, by = c("STATE_ABBREV" = "STATE"), relationship = "many-to-many") |>
  mutate(
    LOC = COUNTYNAME,
    LOC_TYPE = "County"
  ) |>
  select(-COUNTYNAME)

# --- Match county-coded rows directly to Census county FIPS

county_rows <- generated_long |>
  filter(LOC_TYPE == "County") |>
  left_join(geo, by = c("LOC" = "COUNTYNAME", "STATE_ABBREV" = "STATE"))

# --- Preserve non-county, non-statewide rows without assigning county FIPS

other_rows <- generated_long |>
  filter(LOC_TYPE != "County", ENTIRE_STATE != 1) |>
  mutate(FIPS = NA_character_)

# --- Recombine standardized waiver rows into the final generated long panel

generated_long <- bind_rows(other_rows, county_rows, state_rows) |>
  mutate(FIPS = normalize_fips(FIPS)) |>
  arrange(STATE_ABBREV, LOC, MONTH_DATE, SOURCE_DOC)

# -----------------------------
# 3) Save, close out
# -----------------------------

saveRDS(
  generated_long,
  file.path(waiver_output_dir, "2_0_2_waived_data_consolidated_long_generated.rds")
)
saveRDS(
  generated_long,
  file.path(waiver_output_dir, "2_0_4_waived_data_consolidated_long.rds")
)
