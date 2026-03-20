#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        tract_ingest_helpers.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 20, 2026
# Description:      Shared helper functions for the tract ingest scripts. These
#                   helpers centralize tract-scope loading, geography-name
#                   normalization, and shapefile access so the tract waiver,
#                   retailer, and panel scripts all use the same contracts.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   local geometry files under `0_8_geographies/`
# OUTPUTS:          helper functions only
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

library(dplyr)
library(readr)
library(sf)
library(stringr)
library(tibble)

# -----------------------------
# 1) Crosswalk and name-standardization helpers
# -----------------------------

# --- Read the Census county list once and standardize it into tract-safe keys

prepare_county_crosswalk <- function(input_root) {
  county_path <- file.path(input_root, "0_3_county_list", "national_county.txt")

  readr::read_csv(
    county_path,
    col_names = c("state_abbrev", "state_fips", "county_fips_component", "county_name", "classfp"),
    show_col_types = FALSE
  ) |>
    mutate(
      state_fips = str_pad(as.character(state_fips), width = 2, side = "left", pad = "0"),
      county_fips_component = str_pad(as.character(county_fips_component), width = 3, side = "left", pad = "0"),
      county_fips = paste0(state_fips, county_fips_component),
      county_name = county_name |>
        str_to_lower() |>
        str_replace_all(" city and borough$", "") |>
        str_replace_all(" county$", "") |>
        str_replace_all(" parish$", "") |>
        str_replace_all(" borough$", "") |>
        str_replace_all(" census area$", "") |>
        str_replace_all(" municipality$", "") |>
        str_replace_all("\\s+", " ") |>
        str_squish(),
      county_key = normalize_geo_key(county_name)
    ) |>
    select(state_abbrev, state_fips, county_fips, county_name, county_key)
}

# --- Build a permissive geography key so waiver names can match across sources

normalize_geo_key <- function(x) {
  x |>
    str_to_lower() |>
    str_replace_all("&", " and ") |>
    str_replace_all("@", " at ") |>
    str_replace_all("\\([^)]*\\)", " ") |>
    str_replace_all(",\\s*[^,]*county part", " ") |>
    str_replace_all("[`'’]", "") |>
    str_replace_all("[[:punct:]]", " ") |>
    str_replace_all("\\bphiadelphia\\b", "philadelphia") |>
    str_replace_all("\\bmckeesport\\b", "mckeesport") |>
    str_replace_all("\\bmcdowell\\b", "mcdowell") |>
    str_replace_all("\\bmt\\b", "mount") |>
    str_replace_all("\\bst\\b", "saint") |>
    str_replace_all("\\bft\\b", "fort") |>
    str_replace_all("\\bmdekanton\\b", "mdewakanton") |>
    str_replace_all("\\bcouer\\b", "coeur") |>
    str_replace_all("\\btonawonda\\b", "tonawanda") |>
    str_replace_all("\\bpart\\b", " ") |>
    str_replace_all("\\bcounties\\b", "county") |>
    str_replace_all("\\sand\\s", " and ") |>
    str_replace_all("\\s+", " ") |>
    str_squish()
}

# --- Strip administrative words so name matching can focus on place identity

strip_admin_terms <- function(x) {
  x |>
    str_replace_all("\\bcity town\\b", " ") |>
    str_replace_all("\\btown city\\b", " ") |>
    str_replace_all("\\bcity\\b", " ") |>
    str_replace_all("\\btownship\\b", " ") |>
    str_replace_all("\\btown\\b", " ") |>
    str_replace_all("\\bcounty\\b", " ") |>
    str_replace_all("\\bparish\\b", " ") |>
    str_replace_all("\\bborough\\b", " ") |>
    str_replace_all("\\bboro\\b", " ") |>
    str_replace_all("\\bvillage\\b", " ") |>
    str_replace_all("\\breservation area\\b", " ") |>
    str_replace_all("\\breservation\\b", " ") |>
    str_replace_all("\\braincheria\\b", " ") |>
    str_replace_all("\\bcommunity\\b", " ") |>
    str_replace_all("\\bnation\\b", " ") |>
    str_replace_all("\\bindian\\b", " ") |>
    str_replace_all("\\btrust land\\b", " ") |>
    str_replace_all("\\boff reservation\\b", " ") |>
    str_replace_all("\\boff\\b", " ") |>
    str_replace_all("\\barea\\b", " ") |>
    str_replace_all("\\bmetropolitan division\\b", " ") |>
    str_replace_all("\\bmicropolitan\\b", " ") |>
    str_replace_all("\\blma\\b", " ") |>
    str_replace_all("\\bma\\b", " ") |>
    str_replace_all("\\bcounty part\\b", " ") |>
    str_replace_all("\\s+", " ") |>
    str_squish()
}

# --- Keep both the full normalized key and the stripped key for lookup tables

build_name_keys <- function(x) {
  raw_key <- normalize_geo_key(x)
  stripped_key <- strip_admin_terms(raw_key)
  tibble(raw_key = raw_key, stripped_key = stripped_key)
}

# -----------------------------
# 2) Geometry-loading helpers
# -----------------------------

# --- Read plain spatial files directly and zipped shapefiles through GDAL VSI

read_sf_resource <- function(path, quiet = TRUE) {
  if (grepl("\\.zip$", path, ignore.case = TRUE)) {
    return(st_read(sprintf("/vsizip/%s", path), quiet = quiet))
  }

  st_read(path, quiet = quiet)
}

# --- Load one state-level Census geography product across a requested state set

load_state_level_sf <- function(input_root, subdir, suffix, state_fips) {
  paths <- file.path(
    input_root,
    "0_8_geographies",
    subdir,
    sprintf("tl_2010_%s_%s.zip", state_fips, suffix)
  )
  paths <- paths[file.exists(paths)]

  if (!length(paths)) {
    return(NULL)
  }

  objs <- lapply(paths, read_sf_resource)
  do.call(rbind, objs)
}

# -----------------------------
# 3) Tract-scope helpers
# -----------------------------

# --- Use the benchmark county analysis panel to define the tract-analysis scope

get_county_scope <- function(processed_root) {
  analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))
  sort(unique(normalize_fips(analysis_panel$county_fips)))
}

# --- Load 2010 tracts only for counties that are already in the county pipeline

load_scope_tracts <- function(input_root, processed_root) {
  county_scope <- get_county_scope(processed_root)
  state_fips <- sort(unique(substr(county_scope, 1, 2)))

  tracts <- load_state_level_sf(
    input_root = input_root,
    subdir = "census_tracts",
    suffix = "tract10",
    state_fips = state_fips
  )

  county_crosswalk <- prepare_county_crosswalk(input_root)

  tracts |>
    mutate(
      state_fips = str_pad(STATEFP10, width = 2, side = "left", pad = "0"),
      county_fips = paste0(state_fips, str_pad(COUNTYFP10, width = 3, side = "left", pad = "0")),
      tract_fips = str_pad(GEOID10, width = 11, side = "left", pad = "0")
    ) |>
    filter(county_fips %in% county_scope) |>
    left_join(distinct(county_crosswalk, state_fips, state_abbrev), by = "state_fips")
}

# -----------------------------
# 4) State-lookup helpers
# -----------------------------

# --- Build a compact state FIPS-to-abbreviation lookup for local geometry files

make_state_lookup <- function(county_crosswalk) {
  county_crosswalk |>
    distinct(state_abbrev, state_fips)
}

# --- Attach state abbreviations to Census geometry layers that only carry FIPS

add_state_abbrev <- function(x, county_crosswalk, state_fips_col = "STATEFP10") {
  state_lookup <- make_state_lookup(county_crosswalk)
  x |>
    mutate(state_fips = str_pad(.data[[state_fips_col]], width = 2, side = "left", pad = "0")) |>
    left_join(state_lookup, by = "state_fips")
}

# --- Read the Philadelphia county bundle from the user-specified Box input file

read_philadelphia_division_counties <- function(input_root) {
  counties <- file.path(input_root, "philadelphia_divisions.md") |>
    readLines(warn = FALSE) |>
    str_trim()

  normalize_geo_key(counties[counties != ""])
}
