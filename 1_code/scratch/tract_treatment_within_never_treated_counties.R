#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        tract_treatment_within_never_treated_counties.R
# Current author:   Codex
# Last Updated:     May 17, 2026
# Description:      Identify census tracts that are eventually treated under
#                   the tract-level waiver definition even though their county
#                   is "never county-waived" under the exact definition used in
#                   figure 3_1_0_2, then save a map and underlying tract table.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_9_analysis/2_9_3_us_analysis_panel_tract_pre_covariates.rds`
#                   local tract shapefiles under `0_8_geographies/`
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_0_waivers/scratch_tract_treatment_within_never_treated_counties_map.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_0_waivers/scratch_tract_treatment_within_never_treated_counties.csv`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(maps)
library(readr)
library(sf)
library(stringr)
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

repo_root <- normalizePath(file.path(script_dir, "..", ".."))
setwd(repo_root)

source(file.path(repo_root, "1_code", "1_0_ingest", "shared_ingest_helpers.R"))
source(file.path(repo_root, "1_code", "1_0_ingest", "tract_ingest_helpers.R"))
source(file.path(repo_root, "1_code", "1_1_descriptives", "1_1_0_waivers", "shared_us_analysis_helpers.R"))

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

county_panel_path <- file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds")
tract_panel_path <- file.path(processed_root, "2_9_analysis", "2_9_3_us_analysis_panel_tract_pre_covariates.rds")
output_dir <- file.path("3_outputs", "3_1_descriptives", "3_1_0_waivers")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
map_output_path <- file.path(output_dir, "scratch_tract_treatment_within_never_treated_counties_map.jpeg")
csv_output_path <- file.path(output_dir, "scratch_tract_treatment_within_never_treated_counties.csv")

ctx <- load_us_analysis_context()

county_panel <- readRDS(county_panel_path)

tract_panel <- readRDS(tract_panel_path) |>
  transmute(
    tract_fips = str_pad(as.character(tract_fips), width = 11, side = "left", pad = "0"),
    county_fips = normalize_fips(county_fips),
    year = as.integer(year),
    tract_treated = as.logical(treated),
    treatment = as.integer(treatment),
    type = as.character(type)
  )

county_status <- county_panel |>
  select(county_fips) |>
  distinct() |>
  mutate(county_fips = normalize_fips(county_fips)) |>
  left_join(
    ctx$county_panel |>
      distinct(county_fips, ever_county_waived) |>
      mutate(county_fips = normalize_fips(county_fips)),
    by = "county_fips"
  ) |>
  mutate(ever_county_waived = coalesce(ever_county_waived, FALSE))

tract_status <- tract_panel |>
  group_by(tract_fips, county_fips) |>
  summarise(
    tract_ever_treated = any(tract_treated, na.rm = TRUE),
    first_tract_treatment_year = {
      if (any(treatment == 1, na.rm = TRUE)) {
        min(year[treatment == 1], na.rm = TRUE)
      } else {
        NA_integer_
      }
    },
    first_treatment_type = {
      if (any(treatment == 1, na.rm = TRUE)) {
        first_year <- min(year[treatment == 1], na.rm = TRUE)
        dplyr::first(type[year == first_year & treatment == 1])
      } else {
        NA_character_
      }
    },
    treated_years = sum(treatment == 1, na.rm = TRUE),
    .groups = "drop"
  )

county_status <- county_status |>
  left_join(
    tract_status |>
      group_by(county_fips) |>
      summarise(
        county_has_treated_tracts = any(tract_ever_treated, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "county_fips"
  ) |>
  mutate(county_has_treated_tracts = coalesce(county_has_treated_tracts, FALSE))

treated_tracts_in_never_county_waived_counties <- tract_status |>
  inner_join(county_status, by = "county_fips") |>
  filter(!ever_county_waived, tract_ever_treated) |>
  arrange(county_fips, first_tract_treatment_year, tract_fips)

tract_sf <- load_scope_tracts(input_root, processed_root) |>
  mutate(tract_fips = str_pad(as.character(tract_fips), width = 11, side = "left", pad = "0"))

state_map <- maps::map("state", plot = FALSE, fill = TRUE)
state_sf <- sf::st_as_sf(state_map)

map_data <- tract_sf |>
  left_join(
    tract_status |>
      select(tract_fips, county_fips, tract_ever_treated),
    by = c("tract_fips", "county_fips")
  ) |>
  left_join(
    county_status |>
      select(county_fips, ever_county_waived, county_has_treated_tracts),
    by = "county_fips"
  ) |>
  mutate(
    map_status = case_when(
      !coalesce(ever_county_waived, FALSE) & coalesce(tract_ever_treated, FALSE) ~ "Eventually treated tract in never county-waived county",
      !coalesce(ever_county_waived, FALSE) & !coalesce(county_has_treated_tracts, FALSE) ~ "Never county-waived county with no eventually treated tracts",
      TRUE ~ "Other tracts in county analysis scope"
    )
  )

county_summary <- treated_tracts_in_never_county_waived_counties |>
  group_by(county_fips) |>
  summarise(
    treated_tract_n = n(),
    first_tract_treatment_year = min(first_tract_treatment_year, na.rm = TRUE),
    treatment_types = str_c(sort(unique(first_treatment_type)), collapse = ", "),
    .groups = "drop"
  ) |>
  arrange(desc(treated_tract_n), county_fips)

overview <- tibble(
  never_county_waived_counties = sum(!county_status$ever_county_waived, na.rm = TRUE),
  never_county_waived_counties_with_treated_tracts = n_distinct(treated_tracts_in_never_county_waived_counties$county_fips),
  never_county_waived_counties_with_no_treated_tracts = sum(!county_status$ever_county_waived & !county_status$county_has_treated_tracts, na.rm = TRUE),
  treated_tracts_in_never_county_waived_counties = nrow(treated_tracts_in_never_county_waived_counties)
)

cat("\nOverview\n")
print(overview)

cat("\nCounty summary\n")
print(county_summary, n = Inf)

cat("\nEventually treated tracts inside never county-waived counties\n")
print(treated_tracts_in_never_county_waived_counties, n = Inf)

map_theme <- theme_im(base_size = 12) +
  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    axis.ticks = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )

map_colors <- c(
  "Eventually treated tract in never county-waived county" = "#c5050c",
  "Never county-waived county with no eventually treated tracts" = "#0072B2",
  "Other tracts in county analysis scope" = "grey85"
)

p <- ggplot(map_data) +
  geom_sf(
    aes(fill = factor(map_status, levels = names(map_colors))),
    color = NA
  ) +
  geom_sf(
    data = state_sf,
    inherit.aes = FALSE,
    fill = NA,
    color = "grey20",
    linewidth = 0.18
  ) +
  scale_fill_manual(
    values = map_colors,
    breaks = names(map_colors)
  ) +
  labs(
    title = "Eventually Treated Tracts Inside Never County-Waived Counties",
    subtitle = "County status matches figure 3_1_0_2; tract status uses the tract analysis-panel treatment definition",
    fill = NULL,
    caption = "Gray tracts are in the county analysis scope but do not satisfy both conditions."
  ) +
  coord_sf(xlim = c(-125, -66), ylim = c(24, 50), expand = FALSE) +
  map_theme

ggsave(
  filename = map_output_path,
  plot = p,
  width = 11,
  height = 7,
  units = "in",
  dpi = 300
)

write.csv(
  treated_tracts_in_never_county_waived_counties,
  csv_output_path,
  row.names = FALSE
)

cat("\nSaved outputs\n")
cat(map_output_path, "\n")
cat(csv_output_path, "\n")
