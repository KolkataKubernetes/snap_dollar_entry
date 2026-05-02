#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_0_5_annual_state_waiver_status_counts.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     May 2, 2026
# Description:      Create an annual stacked-bar figure of state waiver status,
#                   split into statewide waiver, county waiver, and no waiver.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
# PROCEDURES:       Load the shared analysis context, collapse the county
#                   analysis panel to one state-year waiver-scope label, count
#                   states by annual waiver status, and save the stacked-bar
#                   figure.
# OUTPUTS:          `3_outputs/3_1_descriptives/3_1_0_waivers/3_1_0_5_annual_state_waiver_status_counts.jpeg`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
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

#(1) Build annual state-year waiver status ------------------------------------
state_year_status <- ctx$analysis_panel |>
  filter(!is.na(state), !is.na(year), !is.na(waiver_scope)) |>
  group_by(state, year) |>
  summarise(
    state_status = case_when(
      any(waiver_scope == "statewide") ~ "State waiver",
      any(waiver_scope == "substate") ~ "County waiver",
      TRUE ~ "No waiver"
    ),
    .groups = "drop"
  )

state_status_levels <- c("No waiver", "County waiver", "State waiver")
waiver_year_range <- range(state_year_status$year[state_year_status$state_status != "No waiver"], na.rm = TRUE)

state_year_counts <- state_year_status |>
  filter(year >= waiver_year_range[[1]], year <= waiver_year_range[[2]]) |>
  count(year, state_status, name = "n_states") |>
  tidyr::complete(
    year,
    state_status = state_status_levels,
    fill = list(n_states = 0L)
  ) |>
  mutate(state_status = factor(state_status, levels = state_status_levels))

status_colors <- c(
  "No waiver" = "grey75",
  "County waiver" = "#9CCC65",
  "State waiver" = "#00796B"
)

#(2) Save the figure -----------------------------------------------------------
p <- ggplot(
  state_year_counts,
  aes(x = year, y = n_states, fill = state_status)
) +
  geom_col(width = 0.72, color = "white", linewidth = 0.2) +
  scale_fill_manual(values = status_colors, breaks = state_status_levels) +
  scale_x_continuous(breaks = sort(unique(state_year_counts$year))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
  labs(
    title = "Annual ABAWD Waiver Status Across States",
    subtitle = "State-year counts within the county analysis-panel coverage",
    x = "Year",
    y = "Number of states",
    fill = NULL,
    caption = paste(
      "Note: County waiver counts exclude substate waivers that are not",
      "explicitly assigned to a county in the county analysis panel."
    )
  ) +
  ctx$theme_im(base_size = 13) +
  theme(
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    plot.caption = element_text(hjust = 0)
  )

ggsave(
  filename = descriptive_output_path("3_1_0_5_annual_state_waiver_status_counts.jpeg"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)
