#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_0_2_waiver_geographies_to_tracts.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 19, 2026
# Description:      Expand the live waiver long panel from county and special
#                   waiver geographies to tract identifiers, preserving
#                   diagnostics for every retained geography.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
#                   local geometry files under `0_8_geographies/`
#                   `philadelphia_divisions.md`
# OUTPUTS:          `2_0_waivers/2_0_6_waiver_geography_to_tract_crosswalk.rds`
#                   `2_0_waivers/2_0_7_waived_data_consolidated_long_tract.rds`
#                   `2_0_waivers/2_0_8_waiver_tract_match_diagnostics.rds`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

library(dplyr)
library(purrr)
library(readr)
library(sf)
library(stringr)
library(tibble)
library(tidyr)

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
# 1) Helper functions for tract geography assignment
# -----------------------------

# --- Add tract-matching keys to a spatial lookup layer built from names

prepare_named_lookup <- function(x, state_col = "state_abbrev") {
  name_keys <- build_name_keys(x$NAME10)
  lsad_keys <- if ("NAMELSAD10" %in% names(x)) build_name_keys(x$NAMELSAD10) else tibble(raw_key = NA_character_, stripped_key = NA_character_)

  x |>
    mutate(
      raw_key = name_keys$raw_key,
      stripped_key = name_keys$stripped_key,
      alt_raw_key = lsad_keys$raw_key,
      alt_stripped_key = lsad_keys$stripped_key
    )
}

# --- Match one waiver geography to one source polygon by standardized name

resolve_named_geometries <- function(waiver_geos, lookup, use_state = TRUE, state_filter = TRUE) {
  resolved <- vector("list", nrow(waiver_geos))

  for (i in seq_len(nrow(waiver_geos))) {
    geo <- waiver_geos[i, , drop = FALSE]
    candidates <- lookup

    if (use_state && "state_abbrev" %in% names(candidates)) {
      candidates <- candidates |>
        filter(state_abbrev == geo$STATE_ABBREV[[1]])
    }

    exact <- candidates |>
      filter(
        stripped_key == geo$loc_stripped_key[[1]] |
          alt_stripped_key == geo$loc_stripped_key[[1]] |
          raw_key == geo$loc_key[[1]] |
          alt_raw_key == geo$loc_key[[1]]
      )

    if (!nrow(exact)) {
      exact <- candidates |>
        filter(
          str_detect(stripped_key, fixed(geo$loc_stripped_key[[1]])) |
            str_detect(geo$loc_stripped_key[[1]], fixed(stripped_key)) |
            str_detect(alt_stripped_key, fixed(geo$loc_stripped_key[[1]])) |
            str_detect(geo$loc_stripped_key[[1]], fixed(alt_stripped_key))
        )
    }

    if (!nrow(exact)) {
      next
    }

    resolved[[i]] <- st_sf(
      st_drop_geometry(geo),
      geometry_source = exact$geometry_source[[1]],
      state_filter = state_filter,
      geometry = st_sfc(st_union(st_geometry(exact)), crs = st_crs(exact))
    )
  }

  resolved <- resolved[!vapply(resolved, is.null, logical(1))]

  if (!length(resolved)) {
    return(NULL)
  }

  do.call(rbind, resolved)
}

# --- Expand a matched polygon to tracts using majority overlap with fallback

assign_polygon_geographies <- function(waiver_polygons, tracts_5070) {
  if (is.null(waiver_polygons) || !nrow(waiver_polygons)) {
    return(tibble())
  }

  polygon_5070 <- st_transform(waiver_polygons, 5070) |>
    st_make_valid()

  out <- vector("list", nrow(polygon_5070))

  for (i in seq_len(nrow(polygon_5070))) {
    geo <- polygon_5070[i, , drop = FALSE]
    state_filter <- if ("state_filter" %in% names(geo)) {
      isTRUE(geo$state_filter[[1]])
    } else {
      TRUE
    }

    candidates <- if (state_filter) {
      tracts_5070 |>
        filter(state_abbrev == geo$STATE_ABBREV[[1]])
    } else {
      tracts_5070
    }

    if (!nrow(candidates)) {
      next
    }

    intersections <- suppressWarnings(
      st_intersection(
        candidates |>
          select(tract_fips, county_fips, tract_area),
        geo |>
          select(geo_id)
      )
    )

    if (!nrow(intersections)) {
      next
    }

    intersections <- intersections |>
      mutate(overlap_share = as.numeric(st_area(geometry)) / tract_area)

    selected <- intersections |>
      filter(overlap_share > 0.5)

    assignment_rule <- "majority_area"

    if (!nrow(selected)) {
      max_share <- max(intersections$overlap_share, na.rm = TRUE)
      selected <- intersections |>
        filter(overlap_share == max_share, overlap_share > 0)
      assignment_rule <- "majority_area_fallback"
    }

    out[[i]] <- selected |>
      st_drop_geometry() |>
      transmute(
        geo_id = geo$geo_id[[1]],
        tract_fips,
        county_fips,
        overlap_share,
        geometry_source = geo$geometry_source[[1]],
        assignment_rule = assignment_rule
      )
  }

  bind_rows(out)
}

# --- Build Massachusetts NECTA geometries from county-subdivision membership

resolve_necta_geometries <- function(waiver_geos, all_cousubs, target_state = "MA") {
  if (!nrow(waiver_geos)) {
    return(NULL)
  }

  resolved <- vector("list", nrow(waiver_geos))

  for (i in seq_len(nrow(waiver_geos))) {
    geo <- waiver_geos[i, , drop = FALSE]
    parts <- geo$LOC[[1]] |>
      str_split("\\s-\\s|\\-", simplify = FALSE) |>
      pluck(1) |>
      str_trim()
    parts <- parts[parts != ""]
    part_keys <- strip_admin_terms(normalize_geo_key(parts))

    candidates <- all_cousubs |>
      filter(stripped_key %in% part_keys | alt_stripped_key %in% part_keys)

    if (!nrow(candidates)) {
      next
    }

    code_table <- bind_rows(
      candidates |>
        filter(!is.na(CNECTAFP10), CNECTAFP10 != "") |>
        transmute(code = CNECTAFP10, stripped_key),
      candidates |>
        filter(!is.na(NECTAFP10), NECTAFP10 != "") |>
        transmute(code = NECTAFP10, stripped_key)
    ) |>
      distinct()

    common_codes <- code_table |>
      filter(stripped_key %in% part_keys) |>
      count(code, name = "matched_parts") |>
      arrange(desc(matched_parts), code)

    # One NECTA label spans towns that do not all share one code under the
    # simple exact-match rule, so it needs a small explicit override.
    if (geo$LOC[[1]] == "Lawrence-Methuen Town - Salem") {
      common_codes <- common_codes |>
        filter(code %in% c("715", "71650"))
    } else {
      common_codes <- common_codes |>
        filter(matched_parts == length(unique(part_keys)))
    }

    if (!nrow(common_codes)) {
      next
    }

    code <- common_codes$code[[1]]
    members <- all_cousubs |>
      filter((CNECTAFP10 == code | NECTAFP10 == code) & state_abbrev == target_state)

    resolved[[i]] <- st_sf(
      st_drop_geometry(geo),
      geometry_source = "county_subdivision_necta",
      state_filter = TRUE,
      geometry = st_sfc(st_union(st_geometry(members)), crs = st_crs(members))
    )
  }

  resolved <- resolved[!vapply(resolved, is.null, logical(1))]

  if (!length(resolved)) {
    return(NULL)
  }

  do.call(rbind, resolved)
}

# --- Convert NYC community-district codes into the waiver memo naming format

prepare_nyc_lookup <- function(input_root) {
  borough_map <- c(
    "1" = "manhattan",
    "2" = "bronx",
    "3" = "brooklyn",
    "4" = "queens",
    "5" = "staten island"
  )

  read_sf_resource(file.path(input_root, "0_8_geographies", "NY_Comm_District", "nyc_community_districts_shapefile.zip")) |>
    mutate(
      district = BoroCD %% 100,
      borough = borough_map[as.character(BoroCD %/% 100)],
      NAME10 = str_c("District ", district, ", ", str_to_title(borough)),
      geometry_source = "nyc_community_district"
    ) |>
    prepare_named_lookup()
}

# --- Read the Maine labor-market areas and expose them through name keys

prepare_lma_lookup <- function(input_root) {
  read_sf_resource(file.path(input_root, "0_8_geographies", "maine_LMA", "maine_labor_market_areas.geojson")) |>
    mutate(
      NAME10 = LABOR_MARK,
      NAMELSAD10 = LABOR_MARK,
      state_abbrev = "ME",
      geometry_source = "maine_lma"
    ) |>
    prepare_named_lookup()
}

# --- Patch the one reservation case that needed a manual intersection fallback

build_manual_reservation_matches <- function(waiver_geos, aiannh, tracts_5070) {
  geo <- waiver_geos |>
    filter(LOC_TYPE == "Reservation", LOC == "Kiowa-Comanche-Apache-Fort Sill Apache")

  if (!nrow(geo)) {
    return(tibble())
  }

  loc_key <- normalize_geo_key(geo$LOC[[1]])
  reservation_shape <- aiannh |>
    filter(raw_key == loc_key | stripped_key == strip_admin_terms(loc_key)) |>
    slice(1)

  if (!nrow(reservation_shape)) {
    return(tibble())
  }

  intersections <- suppressWarnings(
    st_intersection(
      tracts_5070 |>
        select(tract_fips, county_fips, tract_area),
      st_transform(reservation_shape, 5070) |>
        st_make_valid()
    )
  )

  if (!nrow(intersections)) {
    return(tibble())
  }

  intersections |>
    mutate(overlap_share = as.numeric(st_area(geometry)) / tract_area) |>
    st_drop_geometry() |>
    transmute(
      geo_id = geo$geo_id[[1]],
      tract_fips,
      county_fips,
      overlap_share,
      geometry_source = "aiannh_manual",
      assignment_rule = "manual_reservation_intersection"
    )
}

# -----------------------------
# 2) Read paths, scope, and source data
# -----------------------------

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

waiver_output_dir <- ensure_dir(file.path(processed_root, "2_0_waivers"))
waiver_path <- file.path(waiver_output_dir, "2_0_4_waived_data_consolidated_long.rds")

ignored_state_fips <- c("02", "15", "60", "66", "69", "72", "78")
excluded_loc_types <- c("Island", "Borough and Census Area", "Native Village Statistical Area")

county_crosswalk <- prepare_county_crosswalk(input_root)
state_lookup <- make_state_lookup(county_crosswalk)
tracts <- load_scope_tracts(input_root, processed_root) |>
  left_join(
    county_crosswalk |>
      distinct(county_fips, county_key),
    by = "county_fips"
  )
tracts_5070 <- st_transform(tracts, 5070) |>
  mutate(tract_area = as.numeric(st_area(geometry)))

# -----------------------------
# 3) Standardize waiver inputs for the tract branch
# -----------------------------

# --- Normalize tract-branch naming issues before any geometry matching

waiver_long <- readRDS(waiver_path) |>
  mutate(
    STATE_ABBREV = case_when(
      (is.na(STATE_ABBREV) | STATE_ABBREV == "") & LOC == "Gosnold" & LOC_TYPE == "Town" ~ "MA",
      TRUE ~ STATE_ABBREV
    ),
    LOC = str_replace_all(LOC, "\\bPhiadelphia\\b", "Philadelphia"),
    LOC = case_when(
      STATE_ABBREV == "VA" & LOC == "Dickinson County" ~ "Dickenson County",
      STATE_ABBREV == "SD" & LOC == "Oglala Lakota County" ~ "Shannon County",
      STATE_ABBREV == "NH" & LOC == "Drummer" ~ "Dummer",
      STATE_ABBREV == "RI" & LOC == "Burrilville" ~ "Burrillville",
      STATE_ABBREV == "RI" & LOC == "North Kingston" ~ "North Kingstown",
      STATE_ABBREV == "RI" & LOC == "South Kingston" ~ "South Kingstown",
      STATE_ABBREV == "NM" & LOC == "San Ildefenso Pueblo" ~ "San Ildefonso Pueblo",
      STATE_ABBREV == "SD" & LOC %in% c("Crow") & LOC_TYPE %in% c("Reservation", "Reservation Area") ~ "Crow Creek",
      STATE_ABBREV == "MN" & LOC == "Chippewa Trust" ~ "Minnesota Chippewa",
      STATE_ABBREV == "OR" & LOC == "Coos/Lower Umpqua/Siuslaw" ~ "Coos, Lower Umpqua, and Siuslaw",
      STATE_ABBREV == "NM" & LOC == "Fort Sill Apache" ~ "Kiowa-Comanche-Apache-Fort Sill Apache",
      TRUE ~ LOC
    )
  ) |>
  left_join(state_lookup, by = c("STATE_ABBREV" = "state_abbrev"))

# --- Collapse the live waiver file to one unique geography row per tract rule

waiver_geos <- waiver_long |>
  distinct(STATE_ABBREV, state_fips, LOC_TYPE, LOC) |>
  arrange(STATE_ABBREV, LOC_TYPE, LOC) |>
  mutate(
    geo_id = row_number(),
    loc_key = normalize_geo_key(LOC),
    loc_stripped_key = strip_admin_terms(loc_key),
    scope_status = case_when(
      is.na(STATE_ABBREV) ~ "missing_state",
      state_fips %in% ignored_state_fips ~ "ignored_fips",
      LOC_TYPE %in% excluded_loc_types ~ "excluded_loc_type",
      TRUE ~ "retain"
    )
  )

tract_index <- tracts |>
  st_drop_geometry() |>
  distinct(tract_fips, county_fips, state_abbrev)

# -----------------------------
# 4) Direct tract expansions for geography types that do not need polygons
# -----------------------------

# --- Counties and county/town rows expand straight through county_fips

county_matches <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE %in% c("County", "County/Town")) |>
  mutate(county_fips = normalize_fips(waiver_long$FIPS[match(paste(STATE_ABBREV, LOC_TYPE, LOC), paste(waiver_long$STATE_ABBREV, waiver_long$LOC_TYPE, waiver_long$LOC))])) |>
  left_join(
    county_crosswalk |>
      distinct(state_abbrev, county_fips, county_key),
    by = c("STATE_ABBREV" = "state_abbrev", "loc_stripped_key" = "county_key")
  ) |>
  mutate(county_fips = coalesce(county_fips.x, county_fips.y)) |>
  select(-county_fips.x, -county_fips.y) |>
  inner_join(tract_index, by = c("county_fips", "STATE_ABBREV" = "state_abbrev"), relationship = "many-to-many") |>
  transmute(
    geo_id,
    tract_fips,
    county_fips,
    overlap_share = 1,
    geometry_source = "county_direct",
    assignment_rule = "county_direct"
  )

# --- State rows expand to every tract in the state already represented in scope

state_matches <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE == "State") |>
  inner_join(tract_index, by = c("STATE_ABBREV" = "state_abbrev"), relationship = "many-to-many") |>
  transmute(
    geo_id,
    tract_fips,
    county_fips,
    overlap_share = 1,
    geometry_source = "state_direct",
    assignment_rule = "state_direct"
  )

# --- The Philadelphia metropolitan-division rows expand through a fixed county bundle

philly_counties <- county_crosswalk |>
  filter(state_abbrev == "PA", county_key %in% read_philadelphia_division_counties(input_root)) |>
  distinct(county_fips)

philly_matches <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE %in% c("Metropolitan Division", "OTHER")) |>
  select(geo_id) |>
  crossing(philly_counties) |>
  inner_join(tract_index, by = "county_fips", relationship = "many-to-many") |>
  transmute(
    geo_id,
    tract_fips,
    county_fips,
    overlap_share = 1,
    geometry_source = "philadelphia_division_counties",
    assignment_rule = "county_bundle_direct"
  )

# -----------------------------
# 5) Build polygon lookups for special waiver geography types
# -----------------------------

# --- Load county subdivisions for town-like places, RI/VT cities, and NECTAs

cousub_states <- waiver_geos |>
  filter(
    scope_status == "retain",
    LOC_TYPE %in% c("Town", "Township", "Plantation", "Unorganized", "NECTA") |
      (LOC_TYPE == "City" & STATE_ABBREV %in% c("RI", "VT"))
  ) |>
  distinct(state_fips) |>
  pull(state_fips)

cousubs <- if (length(cousub_states)) {
  load_state_level_sf(input_root, "census_county_subdivisions", "cousub10", cousub_states) |>
    add_state_abbrev(county_crosswalk) |>
    mutate(geometry_source = "county_subdivision") |>
    prepare_named_lookup()
} else {
  NULL
}

# --- Load places for non-RI/non-VT cities, boroughs, and Berwick

place_states <- waiver_geos |>
  filter(
    scope_status == "retain",
    LOC_TYPE %in% c("Boro", "Borough", "Other") |
      (LOC_TYPE == "City" & !STATE_ABBREV %in% c("RI", "VT"))
  ) |>
  distinct(state_fips) |>
  pull(state_fips)

places <- if (length(place_states)) {
  load_state_level_sf(input_root, "census_places", "place10", place_states) |>
    add_state_abbrev(county_crosswalk) |>
    mutate(geometry_source = "place") |>
    prepare_named_lookup()
} else {
  NULL
}

# --- AIANNH, NYC community districts, and Maine LMA each have their own source

aiannh <- read_sf_resource(file.path(input_root, "0_8_geographies", "census_american_indian_areas", "tl_2010_us_aiannh10.zip")) |>
  mutate(
    state_abbrev = NA_character_,
    geometry_source = "aiannh"
  ) |>
  prepare_named_lookup()

nyc_lookup <- prepare_nyc_lookup(input_root)
lma_lookup <- prepare_lma_lookup(input_root)

# -----------------------------
# 6) Match special geographies to polygons, then polygons to tracts
# -----------------------------

# --- Resolve each waiver geography type to the source polygons chosen in the plan

town_like_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE %in% c("Town", "Township", "Plantation", "Unorganized"))
town_like_polygons <- resolve_named_geometries(town_like_geos, cousubs, use_state = TRUE, state_filter = TRUE)

ri_vt_city_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE == "City", STATE_ABBREV %in% c("RI", "VT"))
ri_vt_city_polygons <- resolve_named_geometries(ri_vt_city_geos, cousubs, use_state = TRUE, state_filter = TRUE)

place_city_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE == "City", !STATE_ABBREV %in% c("RI", "VT"))
place_city_polygons <- resolve_named_geometries(place_city_geos, places, use_state = TRUE, state_filter = TRUE)

boro_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE %in% c("Boro", "Borough"))
boro_polygons <- resolve_named_geometries(boro_geos, places, use_state = TRUE, state_filter = TRUE)

other_place_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE == "Other")
other_place_polygons <- resolve_named_geometries(other_place_geos, places, use_state = TRUE, state_filter = TRUE)

reservation_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE %in% c("Reservation", "Reservation Area"))
reservation_polygons <- resolve_named_geometries(reservation_geos, aiannh, use_state = FALSE, state_filter = FALSE)

community_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE == "Community District")
community_polygons <- resolve_named_geometries(community_geos, nyc_lookup, use_state = FALSE, state_filter = TRUE)

lma_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE == "LMA")
lma_polygons <- resolve_named_geometries(lma_geos, lma_lookup, use_state = TRUE, state_filter = TRUE)

necta_geos <- waiver_geos |>
  filter(scope_status == "retain", LOC_TYPE == "NECTA", STATE_ABBREV == "MA")
necta_polygons <- if (!is.null(cousubs)) resolve_necta_geometries(necta_geos, cousubs) else NULL

# --- Convert every resolved polygon into tract rows under the majority-area rule

polygon_matches <- bind_rows(
  assign_polygon_geographies(town_like_polygons, tracts_5070),
  assign_polygon_geographies(ri_vt_city_polygons, tracts_5070),
  assign_polygon_geographies(place_city_polygons, tracts_5070),
  assign_polygon_geographies(boro_polygons, tracts_5070),
  assign_polygon_geographies(other_place_polygons, tracts_5070),
  assign_polygon_geographies(reservation_polygons, tracts_5070),
  assign_polygon_geographies(community_polygons, tracts_5070),
  assign_polygon_geographies(lma_polygons, tracts_5070),
  assign_polygon_geographies(necta_polygons, tracts_5070),
  build_manual_reservation_matches(waiver_geos, aiannh, tracts_5070)
)

# -----------------------------
# 7) Build tract outputs and diagnostics
# -----------------------------

# --- Combine every assignment path into one reusable tract crosswalk artifact

tract_crosswalk <- bind_rows(
  county_matches,
  state_matches,
  philly_matches,
  polygon_matches
) |>
  distinct() |>
  left_join(
    waiver_geos |>
      select(geo_id, STATE_ABBREV, LOC_TYPE, LOC),
    by = "geo_id"
  ) |>
  mutate(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips)
  ) |>
  arrange(STATE_ABBREV, LOC_TYPE, LOC, tract_fips)

# --- Expand the monthly waiver long file to the tract level through the crosswalk

waiver_long_tract <- waiver_long |>
  left_join(
    waiver_geos |>
      select(STATE_ABBREV, LOC_TYPE, LOC, geo_id),
    by = c("STATE_ABBREV", "LOC_TYPE", "LOC")
  ) |>
  inner_join(
    tract_crosswalk |>
      select(geo_id, tract_fips, county_fips),
    by = "geo_id",
    relationship = "many-to-many"
  ) |>
  mutate(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips)
  ) |>
  arrange(tract_fips, YEAR, MONTH_DATE, LOC_TYPE, LOC)

# --- Summarize tract-match coverage by waiver geography type for auditing

fallback_ids <- tract_crosswalk |>
  filter(assignment_rule == "majority_area_fallback") |>
  distinct(geo_id) |>
  pull(geo_id)

matched_counts <- tract_crosswalk |>
  count(geo_id, name = "tract_rows")

waiver_match_diagnostics <- waiver_geos |>
  left_join(matched_counts, by = "geo_id") |>
  mutate(
    tract_rows = coalesce(tract_rows, 0L),
    matched = tract_rows > 0L,
    fallback_used = geo_id %in% fallback_ids,
    unexpected_drop = scope_status == "retain" & !matched
  ) |>
  group_by(LOC_TYPE) |>
  summarise(
    total_geographies = n(),
    retained_n = sum(scope_status == "retain"),
    matched_n = sum(matched),
    fallback_n = sum(fallback_used),
    excluded_n = sum(scope_status == "excluded_loc_type"),
    ignored_fips_n = sum(scope_status == "ignored_fips"),
    missing_state_n = sum(scope_status == "missing_state"),
    unexpected_drop_n = sum(unexpected_drop),
    tract_rows = sum(tract_rows),
    .groups = "drop"
  ) |>
  arrange(desc(unexpected_drop_n), LOC_TYPE)

# -----------------------------
# 8) Save, close out
# -----------------------------

saveRDS(tract_crosswalk, file.path(waiver_output_dir, "2_0_6_waiver_geography_to_tract_crosswalk.rds"))
saveRDS(waiver_long_tract, file.path(waiver_output_dir, "2_0_7_waived_data_consolidated_long_tract.rds"))
saveRDS(waiver_match_diagnostics, file.path(waiver_output_dir, "2_0_8_waiver_tract_match_diagnostics.rds"))

print(waiver_match_diagnostics)
