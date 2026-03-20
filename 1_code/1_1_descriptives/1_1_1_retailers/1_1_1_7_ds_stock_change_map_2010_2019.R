#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_8_ds_stock_change_map_2010_2019.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Create a county map of percent change in Dollar Store stock
#                   between 2010 and 2019.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#                   `0_7_Ruralurbancontinuumcodes2023.xlsx`
# PROCEDURES:       Load the shared descriptive context, compute county-level
#                   Dollar Store stock in 2010 and 2019, calculate percent
#                   change relative to 2010, join to county polygons via `sf`,
#                   and save the map and underlying county table.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_7_ds_stock_change_map_2010_2019.jpeg`
#                   `3_outputs/3_1_descriptives/3_1_1_retailers/3_1_1_7_ds_stock_change_map_2010_2019.csv`
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

#(1) Compute county-level Dollar Store change ----------------------------------
ds_change <- ctx$ds_stock |>
  filter(year %in% c(2010, 2019)) |>
  select(county_fips, year, ds_stock_count) |>
  tidyr::pivot_wider(
    names_from = year,
    values_from = ds_stock_count,
    names_prefix = "stock_",
    values_fill = 0
  ) |>
  mutate(
    pct_change = if_else(stock_2010 > 0, 100 * (stock_2019 - stock_2010) / stock_2010, NA_real_),
    pct_change_display = scales::squish(pct_change, range = c(-100, 200)),
    had_ds_2010 = stock_2010 > 0
  )

#(2) Build county geometry with sf ---------------------------------------------
data(county.fips, package = "maps")

county_map <- maps::map("county", plot = FALSE, fill = TRUE)
county_sf <- sf::st_as_sf(county_map) |>
  mutate(polyname = ID) |>
  left_join(county.fips, by = "polyname") |>
  mutate(county_fips = as.integer(fips))

map_data <- county_sf |>
  left_join(ds_change, by = "county_fips")

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
  geom_sf(aes(fill = pct_change_display), color = NA) +
  scale_fill_gradient2(
    low = "#2166AC",
    mid = "grey95",
    high = "#B2182B",
    midpoint = 0,
    limits = c(-100, 200),
    oob = scales::squish,
    na.value = "grey80",
    labels = function(x) paste0(x, "%")
  ) +
  labs(
    title = "Dollar Store Stock Change by County, 2010 to 2019",
    subtitle = "County-level percent change in Dollar Store stock; display scale capped at -100% and 200%",
    fill = "% change",
    caption = "Gray counties had no Dollar Stores in 2010, so percent change is undefined."
  ) +
  coord_sf(xlim = c(-125, -66), ylim = c(24, 50), expand = FALSE) +
  map_theme

ggsave(
  filename = descriptive_output_path("3_1_1_7_ds_stock_change_map_2010_2019.jpeg"),
  plot = p,
  width = 11,
  height = 7,
  units = "in"
)

write.csv(
  ds_change,
  descriptive_output_path("3_1_1_7_ds_stock_change_map_2010_2019.csv"),
  row.names = FALSE
)
