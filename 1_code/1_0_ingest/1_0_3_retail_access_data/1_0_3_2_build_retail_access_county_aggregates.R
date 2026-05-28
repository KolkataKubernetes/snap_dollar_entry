#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_3_2_build_retail_access_county_aggregates.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 27, 2026
# Description:      Build county weighted-distance summaries and tract-level
#                   ECDF source rows from the retail-access distance panel.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `2_10_retail_access/2_10_1_tract_retail_access_nearest_distance.rds`
#                   `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# OUTPUTS:          `2_10_retail_access/2_10_2_county_retail_access_weighted_summary.rds`
#                   `2_10_retail_access/2_10_3_retail_access_ecdf_source.rds`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
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

source(file.path(script_dir, "shared_retail_access_helpers.R"))

safe_weighted_mean <- function(distance, weight) {
  valid <- !is.na(distance) & !is.na(weight) & weight > 0

  if (!any(valid)) {
    return(NA_real_)
  }

  sum(distance[valid] * weight[valid]) / sum(weight[valid])
}

paths <- get_access_paths()
setwd(paths$repo_root)

tract_retail_access <- readRDS(
  file.path(paths$processed_access_dir, "2_10_1_tract_retail_access_nearest_distance.rds")
) |>
  mutate(
    county_fips = normalize_fips(county_fips),
    year = as.integer(year),
    poverty_weight = if_else(
      is.na(C17002_002E) & is.na(C17002_003E) & is.na(C17002_004E),
      NA_real_,
      rowSums(cbind(C17002_002E, C17002_003E, C17002_004E), na.rm = TRUE)
    )
  )

county_metadata <- load_county_access_metadata(paths)

tract_retail_access_long <- tract_retail_access |>
  transmute(
    tract_fips,
    county_fips,
    year,
    format,
    nearest_distance_miles,
    active_store_n,
    `Total population` = B01003_001E,
    `Below 1.25x FPL` = poverty_weight,
    `SNAP recipient households` = B22010_002E
  ) |>
  pivot_longer(
    cols = c(`Total population`, `Below 1.25x FPL`, `SNAP recipient households`),
    names_to = "weight_type",
    values_to = "raw_weight"
  )

county_weighted_summary <- tract_retail_access_long |>
  left_join(county_metadata, by = c("county_fips", "year")) |>
  group_by(county_fips, year, format, weight_type, rural_status, treatment_group, ever_treated_county) |>
  summarise(
    county_weighted_distance_miles = safe_weighted_mean(nearest_distance_miles, raw_weight),
    tract_n = sum(!is.na(nearest_distance_miles)),
    weighted_tract_n = sum(!is.na(nearest_distance_miles) & !is.na(raw_weight) & raw_weight > 0),
    county_total_weight = sum(
      raw_weight[!is.na(raw_weight) & !is.na(nearest_distance_miles) & raw_weight > 0],
      na.rm = TRUE
    ),
    .groups = "drop"
  ) |>
  mutate(
    rural_status = factor(rural_status, levels = c("Urban counties", "Rural counties")),
    treatment_group = factor(
      treatment_group,
      levels = c("Ever-treated counties", "Never-treated counties")
    ),
    weight_type = factor(weight_type, levels = access_weight_levels),
    format = factor(format, levels = access_format_levels)
  )

ecdf_source <- tract_retail_access_long |>
  filter(year %in% c(2014L, 2019L)) |>
  left_join(county_metadata, by = c("county_fips", "year")) |>
  filter(!is.na(rural_status), !is.na(treatment_group)) |>
  mutate(
    rural_status = factor(rural_status, levels = c("Urban counties", "Rural counties")),
    treatment_group = factor(
      treatment_group,
      levels = c("Ever-treated counties", "Never-treated counties")
    ),
    weight_type = factor(weight_type, levels = access_weight_levels),
    format = factor(format, levels = access_format_levels),
    year_label = factor(as.character(year), levels = c("2014", "2019"))
  )

saveRDS(
  county_weighted_summary,
  file.path(paths$processed_access_dir, "2_10_2_county_retail_access_weighted_summary.rds")
)

saveRDS(
  ecdf_source,
  file.path(paths$processed_access_dir, "2_10_3_retail_access_ecdf_source.rds")
)

print(
  county_weighted_summary |>
    summarise(
      rows = n(),
      counties = n_distinct(county_fips),
      min_year = min(year, na.rm = TRUE),
      max_year = max(year, na.rm = TRUE)
    )
)

