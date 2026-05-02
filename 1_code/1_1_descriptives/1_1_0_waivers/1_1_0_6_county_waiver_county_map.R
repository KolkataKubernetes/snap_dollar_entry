#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_0_6_county_waiver_county_map.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 2, 2026
# Description:      Create faceted county maps showing waiver geography
#                   variation at the beginning, middle, and end of the
#                   econometric study period.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_9_analysis/2_9_2_event_study_sample.rds`
# PROCEDURES:       Load the shared analysis context, derive the study-period
#                   anchor years from the county event-study sample, identify
#                   treated state-years, classify counties within those
#                   state-years, join to county polygons via `sf`, and save the
#                   faceted maps and underlying county-year table.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_6_county_waiver_county_map.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_6_county_waiver_county_map.csv`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(sf)
library(maps)
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

source(file.path(script_dir, "shared_us_analysis_helpers.R"))
ctx <- load_us_analysis_context()

repo_root <- get_repo_root()
setwd(repo_root)
processed_root <- read_root_path("2_processed_data/processed_root.txt")

#(1) Derive selected study years and county treatment status -------------------
event_study_sample <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_2_event_study_sample.rds"))
study_years <- sort(unique(as.integer(event_study_sample$year)))
selected_years <- c(
  study_years[[1]],
  study_years[[ceiling(length(study_years) / 2)]],
  study_years[[length(study_years)]]
)

selected_year_labels <- c(
  sprintf("Beginning year (%s)", selected_years[[1]]),
  sprintf("Middle year (%s)", selected_years[[2]]),
  sprintf("End year (%s)", selected_years[[3]])
)

selected_year_lookup <- tibble(
  year = selected_years,
  study_year = factor(selected_year_labels, levels = selected_year_labels)
)

county_lookup <- ctx$analysis_panel |>
  filter(!is.na(county_fips), !is.na(state)) |>
  distinct(county_fips, state)

eligible_state_years <- ctx$analysis_panel |>
  filter(!is.na(state), year %in% selected_years) |>
  group_by(state, year) |>
  summarise(
    eligible_county_map = any(waiver_scope %in% c("statewide", "substate")),
    .groups = "drop"
  )

county_year_status <- ctx$analysis_panel |>
  filter(!is.na(county_fips), !is.na(state), year %in% selected_years) |>
  transmute(
    county_fips,
    state,
    year,
    county_waived = waiver_scope %in% c("statewide", "substate")
  ) |>
  distinct()

county_year_grid <- tidyr::crossing(
  county_lookup,
  year = selected_years
) |>
  left_join(eligible_state_years, by = c("state", "year")) |>
  left_join(county_year_status, by = c("county_fips", "state", "year")) |>
  mutate(
    eligible_county_map = coalesce(eligible_county_map, FALSE),
    county_waived = coalesce(county_waived, FALSE),
    map_status = case_when(
      !eligible_county_map ~ NA_character_,
      county_waived ~ "County-waived counties",
      TRUE ~ "Other counties"
    )
  ) |>
  left_join(selected_year_lookup, by = "year")

#(2) Build county geometry with sf --------------------------------------------
data(county.fips, package = "maps")

county_map <- maps::map("county", plot = FALSE, fill = TRUE)
county_sf <- sf::st_as_sf(county_map) |>
  mutate(polyname = ID) |>
  left_join(county.fips, by = "polyname") |>
  mutate(county_fips = as.integer(fips))

state_map <- maps::map("state", plot = FALSE, fill = TRUE)
state_sf <- sf::st_as_sf(state_map)

map_data <- county_sf |>
  left_join(county_year_grid, by = "county_fips", relationship = "many-to-many") |>
  filter(!is.na(study_year))

map_status_levels <- c("County-waived counties", "Other counties")
map_colors <- c(
  "County-waived counties" = unname(ctx$waiver_colors[["Ever county-waived"]]),
  "Other counties" = unname(ctx$waiver_colors[["Never county-waived"]])
)

#(3) Draw the faceted maps ----------------------------------------------------
map_theme <- ctx$theme_im(base_size = 12) +
  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    axis.ticks = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold")
  )

p <- ggplot(map_data) +
  geom_sf(
    aes(fill = factor(map_status, levels = map_status_levels)),
    color = "white",
    linewidth = 0.05
  ) +
  geom_sf(
    data = state_sf,
    inherit.aes = FALSE,
    fill = NA,
    color = "grey20",
    linewidth = 0.18
  ) +
  facet_wrap(~ study_year, nrow = 1) +
  scale_fill_manual(
    values = map_colors,
    breaks = map_status_levels,
    na.value = "grey80"
  ) +
  labs(
    title = "ABAWD Waiver Geography in Selected Analysis Years",
    subtitle = "Statewide and county-level waiver exposure are both colored",
    fill = NULL,
    caption = paste(
      "Gray states have no waiver in that year.",
      "The middle year is the lower midpoint of the econometric study window."
    )
  ) +
  coord_sf(xlim = c(-125, -66), ylim = c(24, 50), expand = FALSE) +
  map_theme

ggsave(
  filename = descriptive_output_path("3_1_0_6_county_waiver_county_map.jpeg"),
  plot = p,
  width = 14,
  height = 5.8,
  units = "in"
)

write.csv(
  county_year_grid |>
    mutate(map_status = coalesce(map_status, "Gray state-year")) |>
    select(county_fips, state, year, study_year, eligible_county_map, county_waived, map_status),
  descriptive_output_path("3_1_0_6_county_waiver_county_map.csv"),
  row.names = FALSE
)
