#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_1_3_SNAP_retailer_tract_panel.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 19, 2026
# Description:      Assign store-level SNAP rows to 2010 tracts and build the
#                   tract-year retailer count panel used by the tract analysis
#                   pipeline.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `2_5_SNAP/2_5_0_snap_clean.rds`
#                   local tract shapefiles under `0_8_geographies/`
# OUTPUTS:          `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds`
#                   `2_5_SNAP/2_5_3_store_count_tract.rds`
#                   `2_5_SNAP/2_5_4_snap_tract_match_diagnostics.rds`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

library(dplyr)
library(purrr)
library(sf)
library(tibble)

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
source(file.path(dirname(script_dir), "tract_ingest_helpers.R"))

# -----------------------------
# 1) Helper functions for tract point assignment
# -----------------------------

# --- Assign one state's SNAP store points to tracts, then fall back within-county

assign_state_points <- function(points_df, tracts_state) {
  if (!nrow(points_df)) {
    return(tibble())
  }

  points_sf <- st_as_sf(
    points_df,
    coords = c("Longitude", "Latitude"),
    crs = 4326,
    remove = FALSE
  ) |>
    st_transform(st_crs(tracts_state))

  joined <- st_join(
    points_sf,
    tracts_state |>
      rename(tract_county_fips = county_fips) |>
      select(tract_fips, tract_county_fips),
    join = st_intersects,
    left = TRUE
  )

  joined_df <- joined |>
    st_drop_geometry() |>
    # Boundary-touching points can intersect more than one tract, so keep one
    # deterministic assignment before the nearest-tract fallback stage.
    mutate(assignment_rule = if_else(!is.na(tract_fips), "point_in_polygon", NA_character_)) |>
    arrange(store_row_id, tract_fips) |>
    group_by(store_row_id) |>
    slice(1) |>
    ungroup()

  unmatched_ids <- joined_df$store_row_id[is.na(joined_df$tract_fips)]

  if (length(unmatched_ids)) {
    points_missing <- points_sf |>
      filter(store_row_id %in% unmatched_ids)
    points_missing_df <- points_missing |>
      st_drop_geometry()

    # Most fallback cases are spatial near-misses rather than true county misses,
    # so nearest-tract assignment first searches within the original county.
    nearest_match <- points_missing_df |>
      mutate(county_fips_original = coalesce(county_fips_original, "__STATE_FALLBACK__")) |>
      group_split(county_fips_original) |>
      purrr::map_dfr(function(group_df) {
        group_points <- points_missing |>
          filter(store_row_id %in% group_df$store_row_id)
        county_key <- group_df$county_fips_original[[1]]
        county_subset <- if (county_key != "__STATE_FALLBACK__") {
          tracts_state |>
            filter(county_fips == county_key)
        } else {
          tracts_state[0, ]
        }
        candidate_tracts <- if (nrow(county_subset)) county_subset else tracts_state
        nearest_idx <- st_nearest_feature(group_points, candidate_tracts)

        tibble(
          store_row_id = group_df$store_row_id,
          tract_fips = candidate_tracts$tract_fips[nearest_idx],
          tract_county_fips = candidate_tracts$county_fips[nearest_idx]
        )
      })

    joined_df <- joined_df |>
      select(-tract_fips, -tract_county_fips, -assignment_rule) |>
      left_join(
        bind_rows(
          joined_df |>
            filter(!is.na(tract_fips)) |>
            transmute(store_row_id, tract_fips, tract_county_fips, assignment_rule = "point_in_polygon"),
          nearest_match |>
            mutate(assignment_rule = "nearest_tract_fallback")
        ),
        by = "store_row_id"
      )
  }

  joined_df
}

# -----------------------------
# 2) Read paths, scope, and processed inputs
# -----------------------------

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

snap_output_dir <- ensure_dir(file.path(processed_root, "2_5_SNAP"))
snap_path <- file.path(snap_output_dir, "2_5_0_snap_clean.rds")

ignored_state_fips <- c("60", "66", "69", "72", "78")
county_scope <- get_county_scope(processed_root)
tracts <- load_scope_tracts(input_root, processed_root) |>
  select(tract_fips, county_fips, state_abbrev, geometry)

# -----------------------------
# 3) Prepare the store-level tract assignment input
# -----------------------------

# --- Preserve the original county labels so tract diagnostics can compare back

snap_clean <- readRDS(snap_path) |>
  mutate(
    store_row_id = row_number(),
    county_fips_original = normalize_fips(county_fips),
    state_fips_original = substr(county_fips_original, 1, 2),
    state_abbrev = State,
    in_scope = county_fips_original %in% county_scope,
    ignored_fips = state_fips_original %in% ignored_state_fips
  )

scope_points <- snap_clean |>
  filter(in_scope, !ignored_fips)

# -----------------------------
# 4) Assign SNAP stores to tracts
# -----------------------------

# --- Run the spatial point assignment state by state to keep the join tractable

state_results <- map_dfr(
  sort(unique(scope_points$state_abbrev)),
  function(state_abbrev) {
    tracts_state <- tracts |>
      filter(state_abbrev == !!state_abbrev)
    points_state <- scope_points |>
      filter(state_abbrev == !!state_abbrev)

    assign_state_points(points_state, tracts_state)
  }
)

# --- Merge the tract assignments back onto the full SNAP store panel

snap_with_tracts <- snap_clean |>
  left_join(
    state_results |>
      transmute(store_row_id, tract_fips, tract_county_fips, assignment_rule),
    by = "store_row_id"
  ) |>
  mutate(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = case_when(
      !is.na(tract_fips) ~ substr(tract_fips, 1, 5),
      TRUE ~ county_fips_original
    ),
    county_fips_match = is.na(tract_fips) | county_fips_original == county_fips
  )

# -----------------------------
# 5) Build tract-year retailer outcomes and diagnostics
# -----------------------------

# --- Expand matched stores over their active authorization years at the tract level

store_count_tract <- snap_with_tracts |>
  filter(!is.na(tract_fips), !is.na(authorization_year), !is.na(end_year)) |>
  group_by(store_row_id, tract_fips, county_fips, chain) |>
  reframe(year = seq.int(first(authorization_year), first(end_year))) |>
  count(tract_fips, county_fips, chain, year, name = "count") |>
  arrange(tract_fips, chain, year)

# --- Save the main tract-assignment accounting metrics for Milestone 1 validation

snap_tract_diagnostics <- tibble(
  total_rows = nrow(snap_with_tracts),
  scope_rows = sum(snap_with_tracts$in_scope & !snap_with_tracts$ignored_fips),
  matched_rows = sum(!is.na(snap_with_tracts$tract_fips)),
  point_in_polygon_rows = sum(snap_with_tracts$assignment_rule == "point_in_polygon", na.rm = TRUE),
  fallback_rows = sum(snap_with_tracts$assignment_rule == "nearest_tract_fallback", na.rm = TRUE),
  out_of_scope_rows = sum(!snap_with_tracts$in_scope | snap_with_tracts$ignored_fips, na.rm = TRUE),
  county_mismatch_rows = sum(!snap_with_tracts$county_fips_match, na.rm = TRUE),
  unexpected_unmatched_rows = sum(snap_with_tracts$in_scope & !snap_with_tracts$ignored_fips & is.na(snap_with_tracts$tract_fips))
)

# -----------------------------
# 6) Save, close out
# -----------------------------

saveRDS(snap_with_tracts, file.path(snap_output_dir, "2_5_2_snap_clean_with_tracts.rds"))
saveRDS(store_count_tract, file.path(snap_output_dir, "2_5_3_store_count_tract.rds"))
saveRDS(snap_tract_diagnostics, file.path(snap_output_dir, "2_5_4_snap_tract_match_diagnostics.rds"))

print(snap_tract_diagnostics)
