#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_3_1_build_retail_access_distance_panel.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Construct tract-year-format nearest-retailer distances for
#                   the `2014:2019` retail-access study period.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `2_10_retail_access/2_10_0_tract_access_weights_2014_2019.rds`
#                   `2_5_SNAP/2_5_2_snap_clean_with_tracts.rds`
#                   local tract shapefiles under `0_8_geographies/`
# OUTPUTS:          `2_10_retail_access/2_10_1_tract_retail_access_nearest_distance.rds`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(purrr)
library(sf)
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

source(file.path(script_dir, "shared_retail_access_helpers.R"))

paths <- get_access_paths()
setwd(paths$repo_root)

tract_access_weights <- readRDS(
  file.path(paths$processed_access_dir, "2_10_0_tract_access_weights_2014_2019.rds")
) |>
  mutate(
    tract_fips = str_pad(tract_fips, width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
    year = as.integer(year)
  )

tract_centroids <- load_scope_tract_centroids(
  paths = paths,
  tract_ids = unique(tract_access_weights$tract_fips)
)

tract_distance_scope <- tract_centroids |>
  inner_join(
    tract_access_weights,
    by = c("tract_fips", "county_fips")
  )

snap_clean <- readRDS(file.path(paths$processed_root, "2_5_SNAP", "2_5_2_snap_clean_with_tracts.rds")) |>
  mutate(
    store_row_id = as.integer(store_row_id),
    authorization_year = as.integer(authorization_year),
    end_year = as.integer(end_year),
    format = classify_access_format(chain)
  ) |>
  filter(
    !is.na(format),
    !is.na(Longitude),
    !is.na(Latitude),
    !is.na(authorization_year),
    !is.na(end_year)
  ) |>
  mutate(
    active_start_year = pmax(authorization_year, 2014L),
    active_end_year = pmin(end_year, 2019L)
  ) |>
  filter(active_start_year <= active_end_year) |>
  distinct(store_row_id, format, Longitude, Latitude, active_start_year, active_end_year)

retailer_year_points <- snap_clean |>
  rowwise() |>
  reframe(
    store_row_id = store_row_id,
    format = format,
    Longitude = Longitude,
    Latitude = Latitude,
    year = seq.int(active_start_year, active_end_year)
  ) |>
  ungroup() |>
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE) |>
  st_transform(5070)

year_format_grid <- expand.grid(
  year = 2014:2019,
  format = access_format_levels,
  stringsAsFactors = FALSE
)

tract_retail_access <- purrr::map_dfr(
  split(year_format_grid, seq_len(nrow(year_format_grid))),
  function(combo) {
    current_year <- combo$year[[1]]
    current_format <- combo$format[[1]]

    tracts_year <- tract_distance_scope |>
      filter(year == current_year)

    retailers_year_format <- retailer_year_points |>
      filter(year == current_year, format == current_format)

    if (!nrow(retailers_year_format)) {
      return(
        tracts_year |>
          st_drop_geometry() |>
          transmute(
            tract_fips,
            county_fips,
            year,
            format = current_format,
            nearest_distance_miles = NA_real_,
            active_store_n = 0L,
            B01003_001E,
            C17002_002E,
            C17002_003E,
            C17002_004E,
            B22010_002E
          )
      )
    }

    nearest_idx <- st_nearest_feature(tracts_year, retailers_year_format)
    nearest_distance_miles <- as.numeric(
      st_distance(tracts_year, retailers_year_format[nearest_idx, ], by_element = TRUE)
    ) * 0.000621371

    tracts_year |>
      st_drop_geometry() |>
      transmute(
        tract_fips,
        county_fips,
        year,
        format = current_format,
        nearest_distance_miles,
        active_store_n = nrow(retailers_year_format),
        B01003_001E,
        C17002_002E,
        C17002_003E,
        C17002_004E,
        B22010_002E
      )
  }
)

saveRDS(
  tract_retail_access,
  file.path(paths$processed_access_dir, "2_10_1_tract_retail_access_nearest_distance.rds")
)

print(
  tract_retail_access |>
    summarise(
      rows = n(),
      tracts = n_distinct(tract_fips),
      min_year = min(year, na.rm = TRUE),
      max_year = max(year, na.rm = TRUE),
      formats = paste(sort(unique(format)), collapse = "; "),
      negative_distances = sum(nearest_distance_miles < 0, na.rm = TRUE)
    )
)
