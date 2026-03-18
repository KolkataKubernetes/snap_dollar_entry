#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_9_ever_waived_county_map.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Create a county map showing counties ever assigned a
#                   county-level ABAWD waiver.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, identify counties that
#                   ever receive a county-level waiver, join to county polygons
#                   via `sf`, and save the map and underlying county table.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_9_ever_waived_county_map.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_9_ever_waived_county_map.csv`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(sf)
library(maps)

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

#(1) Build county waiver status ------------------------------------------------
ever_waived <- ctx$county_panel |>
  distinct(county_fips, ever_county_waived) |>
  mutate(
    waiver_status = if_else(
      ever_county_waived,
      "Ever county-waived",
      "Never county-waived"
    )
  )

#(2) Build county geometry with sf ---------------------------------------------
data(county.fips, package = "maps")

county_map <- maps::map("county", plot = FALSE, fill = TRUE)
county_sf <- sf::st_as_sf(county_map) |>
  mutate(polyname = ID) |>
  left_join(county.fips, by = "polyname") |>
  mutate(county_fips = as.integer(fips))

state_map <- maps::map("state", plot = FALSE, fill = TRUE)
state_sf <- sf::st_as_sf(state_map)

map_data <- county_sf |>
  left_join(ever_waived, by = "county_fips")

#(3) Draw the map --------------------------------------------------------------
map_theme <- ctx$theme_im(base_size = 12) +
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
    color = "white",
    linewidth = 0.06
  ) +
  geom_sf(
    data = state_sf,
    inherit.aes = FALSE,
    fill = NA,
    color = "grey20",
    linewidth = 0.18
  ) +
  scale_fill_manual(
    values = ctx$waiver_colors,
    breaks = names(ctx$waiver_colors),
    na.value = "grey80"
  ) +
  labs(
    title = "Counties Ever Assigned a County-Level Waiver",
    subtitle = "County-level ABAWD waiver exposure over the analysis period",
    fill = NULL,
    caption = "Gray polygons are unmatched counties in the maps county geometry."
  ) +
  coord_sf(xlim = c(-125, -66), ylim = c(24, 50), expand = FALSE) +
  map_theme

ggsave(
  filename = descriptive_output_path("3_1_9_ever_waived_county_map.jpeg"),
  plot = p,
  width = 11,
  height = 7,
  units = "in"
)

write.csv(
  ever_waived,
  descriptive_output_path("3_1_9_ever_waived_county_map.csv"),
  row.names = FALSE
)
