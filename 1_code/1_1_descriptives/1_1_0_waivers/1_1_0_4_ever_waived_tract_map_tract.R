#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_0_4_ever_waived_tract_map_tract.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 22, 2026
# Description:      Create a tract map showing census tracts ever assigned an
#                   ABAWD waiver in the tract analysis panel.
# INPUTS:           `2_9_analysis/2_9_6_us_analysis_panel_tract_timevarying_covariates.rds`
#                   `0_8_geographies/census_tracts/tl_2010_*_tract10.zip`
# PROCEDURES:       Load the shared descriptive and tract-ingest helpers,
#                   compute whether each tract is ever waived, join those flags
#                   to the local 2010 tract polygons in the county analysis
#                   scope, and save the map into the waiver descriptive folder.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_4_ever_waived_tract_map_tract.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(sf)
library(maps)
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

source(file.path(script_dir, "shared_us_analysis_helpers.R"))
source(file.path(dirname(dirname(script_dir)), "1_0_ingest", "shared_ingest_helpers.R"))
source(file.path(dirname(dirname(script_dir)), "1_0_ingest", "tract_ingest_helpers.R"))

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

#(1) Build tract waiver status -------------------------------------------------
tract_panel <- readRDS(
  file.path(processed_root, "2_9_analysis", "2_9_6_us_analysis_panel_tract_timevarying_covariates.rds")
) |>
  transmute(
    tract_fips = str_pad(as.character(tract_fips), width = 11, side = "left", pad = "0"),
    treated = coalesce(as.logical(treated), FALSE)
  )

ever_waived <- tract_panel |>
  group_by(tract_fips) |>
  summarise(ever_tract_waived = any(treated), .groups = "drop") |>
  mutate(
    waiver_status = if_else(
      ever_tract_waived,
      "Ever tract-waived",
      "Never tract-waived"
    )
  )

#(2) Build tract geometry with sf ----------------------------------------------
tract_sf <- load_scope_tracts(input_root, processed_root) |>
  mutate(tract_fips = str_pad(as.character(tract_fips), width = 11, side = "left", pad = "0"))

state_map <- maps::map("state", plot = FALSE, fill = TRUE)
state_sf <- sf::st_as_sf(state_map)

map_data <- tract_sf |>
  left_join(ever_waived, by = "tract_fips")

waiver_colors_tract <- c(
  "Ever tract-waived" = "#c5050c",
  "Never tract-waived" = "#0072B2"
)

#(3) Draw the map --------------------------------------------------------------
map_theme <- theme_im(base_size = 12) +
  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    axis.ticks = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )

p <- ggplot(map_data) +
  geom_sf(
    aes(fill = waiver_status),
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
    values = waiver_colors_tract,
    breaks = names(waiver_colors_tract),
    na.value = "grey80"
  ) +
  labs(
    title = "Census Tracts Ever Assigned an ABAWD Waiver",
    subtitle = "Tract-level waiver exposure over the analysis period",
    fill = NULL,
    caption = "Gray polygons are unmatched tracts in the tract analysis scope."
  ) +
  coord_sf(xlim = c(-125, -66), ylim = c(24, 50), expand = FALSE) +
  map_theme

ggsave(
  filename = descriptive_output_path("3_1_0_4_ever_waived_tract_map_tract.jpeg"),
  plot = p,
  width = 11,
  height = 7,
  units = "in",
  dpi = 300
)
