#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_0_6_county_waiver_county_map.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     June 1, 2026
# Description:      Create faceted county maps showing waiver geography
#                   variation at the beginning, middle, and end of the
#                   econometric study period.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_9_analysis/2_9_2_event_study_sample.rds`
# PROCEDURES:       Load the shared analysis context, derive the study-period
#                   anchor years from the county event-study sample, classify
#                   state-years from the full waiver panel so statewide-only
#                   states remain visible while substate years retain county
#                   variation, join to county polygons via `sf`, and save the
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

#(1) Derive selected study years -----------------------------------------------
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

#(2) Build county geometry with sf --------------------------------------------
data(county.fips, package = "maps")

county_map <- maps::map("county", plot = FALSE, fill = TRUE)
county_sf <- sf::st_as_sf(county_map) |>
  mutate(polyname = ID) |>
  left_join(county.fips, by = "polyname") |>
  mutate(
    county_fips = as.integer(fips),
    state = county_fips %/% 1000L
  ) |>
  filter(!is.na(county_fips))

state_map <- maps::map("state", plot = FALSE, fill = TRUE)
state_sf <- sf::st_as_sf(state_map)

#(3) Classify county waiver status from the full waiver panel ------------------
county_lookup <- county_sf |>
  st_drop_geometry() |>
  distinct(county_fips, state)

waiver_long_raw <- readRDS(
  file.path(processed_root, "2_0_waivers", "2_0_4_waived_data_consolidated_long.rds")
)

waiver_year_status <- waiver_long_raw |>
  mutate(
    county_fips = if ("FIPS" %in% names(waiver_long_raw)) as.integer(FIPS) else as.integer(county_fips),
    year = if ("YEAR" %in% names(waiver_long_raw)) as.integer(YEAR) else as.integer(year),
    waiver_scope = if ("waiver_scope" %in% names(waiver_long_raw)) {
      as.character(waiver_scope)
    } else if ("ENTIRE_STATE" %in% names(waiver_long_raw)) {
      if_else(as.integer(ENTIRE_STATE) == 1L, "statewide", "substate")
    } else {
      NA_character_
    }
  ) |>
  filter(!is.na(county_fips), year %in% selected_years) |>
  transmute(
    county_fips = as.integer(county_fips),
    state = county_fips %/% 1000L,
    year = as.integer(year),
    waiver_scope = as.character(waiver_scope)
  ) |>
  distinct()

state_year_scope <- waiver_year_status |>
  group_by(state, year) |>
  summarise(
    any_statewide = any(waiver_scope == "statewide"),
    any_substate = any(waiver_scope == "substate"),
    .groups = "drop"
  ) |>
  mutate(
    state_year_scope = case_when(
      any_substate ~ "substate_present",
      any_statewide ~ "statewide_only",
      TRUE ~ "none"
    )
  )

county_year_status <- waiver_year_status |>
  filter(waiver_scope == "substate") |>
  transmute(
    county_fips,
    state,
    year,
    county_waived = TRUE
  )

county_year_grid <- tidyr::crossing(
  county_lookup,
  year = selected_years
) |>
  left_join(state_year_scope, by = c("state", "year")) |>
  left_join(county_year_status, by = c("county_fips", "state", "year")) |>
  mutate(
    state_year_scope = coalesce(state_year_scope, "none"),
    any_statewide = coalesce(any_statewide, FALSE),
    any_substate = coalesce(any_substate, FALSE),
    county_waived = coalesce(county_waived, FALSE),
    map_status = case_when(
      state_year_scope == "statewide_only" ~ "Statewide-waived states",
      state_year_scope == "substate_present" & county_waived ~ "County-waived counties",
      state_year_scope == "substate_present" ~ "Other counties",
      TRUE ~ NA_character_
    )
  ) |>
  left_join(selected_year_lookup, by = "year")

map_data <- county_sf |>
  left_join(county_year_grid, by = c("county_fips", "state"), relationship = "many-to-many") |>
  filter(!is.na(study_year))

map_status_levels <- c("Statewide-waived states", "County-waived counties", "Other counties")
map_colors <- c(
  "Statewide-waived states" = "#00796B",
  "County-waived counties" = unname(ctx$waiver_colors[["Ever county-waived"]]),
  "Other counties" = unname(ctx$waiver_colors[["Never county-waived"]])
)

#(4) Draw the faceted maps ----------------------------------------------------
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
    subtitle = "County variation is shown when substate waivers exist; statewide-only states are filled uniformly",
    fill = NULL,
    caption = paste(
      "Gray states have no waiver in that year.",
      "Teal states are statewide-only waiver years.",
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
    select(
      county_fips,
      state,
      year,
      study_year,
      state_year_scope,
      any_statewide,
      any_substate,
      county_waived,
      map_status
    ),
  descriptive_output_path("3_1_0_6_county_waiver_county_map.csv"),
  row.names = FALSE
)
