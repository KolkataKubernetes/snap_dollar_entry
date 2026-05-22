#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_12_compare_total_ds_control_groups.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Standalone comparison of Dollar Stores Sun-Abraham event
#                   studies under the current eventually-treated control sample
#                   and an alternative all-never-treated control sample.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
# PROCEDURES:       Rebuild both estimation samples, estimate both reduced-form
#                   models, and save isolated comparison outputs.
# OUTPUTS:          `3_outputs/3_2_reduced_form/isolated/3_2_12_event_study_ihs_total_ds_compare_controls*.pdf`
#                   `3_outputs/3_0_tables/isolated/3_2_12_event_study_ihs_total_ds_compare_controls*.tex`
#                   `3_outputs/3_0_tables/isolated/3_2_12_event_study_ihs_total_ds_compare_controls*_event_profile.csv`
#                   `3_outputs/3_0_tables/isolated/3_2_12_event_study_ihs_total_ds_compare_controls*_att.csv`
# DEPENDENCIES:     `dplyr`, `fixest`, `ggplot2`
# Review focus:     The purpose of this script is comparison. Reviewers should
#                   check that the only intended difference between the two
#                   models is the control-group construction.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(fixest)
library(ggplot2)

# Resolve the script directory so this standalone file can find the repository root.
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

repo_root <- normalizePath(file.path(script_dir, "..", "..", ".."))
setwd(repo_root)

# Purpose: read a one-line root-path pointer file used elsewhere in the repo.
# Inputs: `path_file`, a repository-relative text file containing one path.
# Returns: trimmed path string with surrounding quotes removed.
# Side effects: reads from disk.
read_root_path <- function(path_file) {
  path_value <- readLines(path_file, warn = FALSE)[[1]]
  path_value <- trimws(path_value)
  path_value <- sub("^'", "", path_value)
  sub("'$", "", path_value)
}

# Purpose: create the isolated output folders for figures and tables.
# Inputs: none.
# Returns: no explicit return value.
# Side effects: creates directories when missing.
ensure_output_dirs <- function() {
  dir.create(file.path("3_outputs", "3_2_reduced_form", "isolated"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path("3_outputs", "3_0_tables", "isolated"), recursive = TRUE, showWarnings = FALSE)
}

# Purpose: version output filenames instead of overwriting prior artifacts.
# Inputs: `path`, the preferred output path.
# Returns: `path` itself or the next `_vNN` variant.
# Side effects: checks the filesystem for existing outputs.
next_available_path <- function(path) {
  if (!file.exists(path)) {
    return(path)
  }

  base <- tools::file_path_sans_ext(path)
  ext <- tools::file_ext(path)
  index <- 1
  candidate <- sprintf("%s_v%02d.%s", base, index, ext)

  while (file.exists(candidate)) {
    index <- index + 1
    candidate <- sprintf("%s_v%02d.%s", base, index, ext)
  }

  candidate
}

# Purpose: define the shared plotting theme used in the comparison figure.
# Inputs: `base_size`, the theme base text size.
# Returns: a ggplot theme object.
# Side effects: none.
theme_im <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(linewidth = 0.3),
      panel.grid.major.y = element_line(linewidth = 0.3),
      legend.position = "top",
      legend.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold")
    )
}

# Purpose: convert a fitted model into an event-profile table with a control-group tag.
# Inputs: `model` and `control_group_label`.
# Returns: plotting-ready event-profile data frame.
# Side effects: none.
extract_event_profile <- function(model, control_group_label) {
  event_coeftable <- as.data.frame(coeftable(model))
  event_coeftable$term <- rownames(event_coeftable)
  rownames(event_coeftable) <- NULL

  event_confint <- as.data.frame(confint(model))
  event_confint$term <- rownames(event_confint)
  rownames(event_confint) <- NULL
  names(event_confint)[1:2] <- c("conf_low", "conf_high")

  event_coeftable |>
    filter(grepl("^year::", term)) |>
    left_join(event_confint, by = "term") |>
    mutate(
      event_time = as.integer(sub("^year::", "", term)),
      control_group = control_group_label
    ) |>
    select(control_group, event_time, term, Estimate, `Std. Error`, `t value`, `Pr(>|t|)`, conf_low, conf_high)
}

# Purpose: extract the aggregated ATT row for one fitted model.
# Inputs: `model` and `control_group_label`.
# Returns: ATT summary data frame with a control-group tag.
# Side effects: none.
extract_att <- function(model, control_group_label) {
  att_model <- summary(model, agg = "att")
  att_coeftable <- as.data.frame(coeftable(att_model))
  att_coeftable$term <- rownames(att_coeftable)
  rownames(att_coeftable) <- NULL

  att_coeftable |>
    filter(term == "ATT") |>
    mutate(control_group = control_group_label) |>
    select(control_group, term, Estimate, `Std. Error`, `t value`, `Pr(>|t|)`)
}

# Purpose: estimate the benchmark Dollar Stores reduced form on a supplied sample.
# Inputs: `data`, an already-filtered county-year sample.
# Returns: `fixest` model object.
# Side effects: none.
estimate_model <- function(data) {
  feols(
    log(total_ds + sqrt(total_ds^2 + 1)) ~
      sunab(eventYear2, year, ref.p = 0) +
      population + wage + meanInc + rent + urate |
      county_fips + year,
    data = data,
    vcov = ~county_fips
  )
}

# Load the county analysis panel that will be split into two alternative control-group samples.
processed_root <- read_root_path("2_processed_data/processed_root.txt")
analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

# Rebuild the common base panel before defining the two competing control-group samples.
base_panel <- analysis_panel |>
  mutate(
    rent = rent / 1000,
    meanInc = meanInc / 1000,
    state_fips = county_fips %/% 1000
  ) |>
  filter(year %in% 2014:2019) |>
  mutate(
    tau2 = if_else(is.na(tau2), -1000, tau2),
    eventYear2 = if_else(is.na(eventYear2), 10000, eventYear2),
    treated_group = eventYear2 != 10000,
    never_treated = eventYear2 == 10000
  ) |>
  group_by(county_fips) |>
  mutate(treated_county = sum(treated_group) > 0) |>
  ungroup()

# Benchmark sample: eventually-treated counties only, with the benchmark event-time window.
eventually_treated_sample <- base_panel |>
  filter(year - eventYear2 >= -3, treated_county)

# Alternative sample: keep all never-treated counties in addition to the treated event-time window.
never_treated_sample <- base_panel |>
  filter(never_treated | year - eventYear2 >= -3)

# Estimate the two models that will be compared throughout the rest of the script.
eventually_treated_model <- estimate_model(eventually_treated_sample)
never_treated_model <- estimate_model(never_treated_sample)

# Stack the event-time profiles and ATT summaries so the comparison outputs can be written side by side.
event_profile_results <- bind_rows(
  extract_event_profile(eventually_treated_model, "eventually_treated"),
  extract_event_profile(never_treated_model, "never_treated")
)

att_results <- bind_rows(
  extract_att(eventually_treated_model, "eventually_treated"),
  extract_att(never_treated_model, "never_treated")
)

plot_data <- event_profile_results |>
  mutate(
    control_group = factor(
      control_group,
      levels = c("eventually_treated", "never_treated"),
      labels = c("Eventually-treated controls", "Never-treated controls")
    )
  )

# Plot both event-study profiles on common axes so differences come only from the control-group choice.
comparison_plot <- ggplot(
  plot_data,
  aes(x = event_time, y = Estimate, color = control_group, group = control_group)
) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
  geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.45) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = sort(unique(plot_data$event_time))) +
  labs(
    title = "Dollar Stores Event Study Comparison",
    subtitle = "Sun-Abraham reduced form under alternative control groups",
    x = "Event time",
    y = "Coefficient on IHS(Dollar Stores)",
    color = NULL
  ) +
  theme_im(base_size = 12)

# Create the isolated output folders and version all exported artifact names.
ensure_output_dirs()

plot_path <- next_available_path(
  file.path("3_outputs", "3_2_reduced_form", "isolated", "3_2_12_event_study_ihs_total_ds_compare_controls.pdf")
)
tex_path <- next_available_path(
  file.path("3_outputs", "3_0_tables", "isolated", "3_2_12_event_study_ihs_total_ds_compare_controls_att.tex")
)
event_csv_path <- next_available_path(
  file.path("3_outputs", "3_0_tables", "isolated", "3_2_12_event_study_ihs_total_ds_compare_controls_event_profile.csv")
)
att_csv_path <- next_available_path(
  file.path("3_outputs", "3_0_tables", "isolated", "3_2_12_event_study_ihs_total_ds_compare_controls_att.csv")
)

ggsave(plot_path, comparison_plot, width = 8, height = 6, units = "in")

etable(
  eventually_treated_model,
  never_treated_model,
  agg = "att",
  keep = "ATT",
  headers = c("Eventually-treated controls", "Never-treated controls"),
  file = tex_path,
  replace = TRUE
)

write.csv(event_profile_results, event_csv_path, row.names = FALSE)
write.csv(att_results, att_csv_path, row.names = FALSE)

cat("Standalone control-group comparison completed.\n")
cat(sprintf("Eventually-treated ATT: %.6f (SE %.6f, p %.6f)\n",
            att_results$Estimate[att_results$control_group == "eventually_treated"][[1]],
            att_results$`Std. Error`[att_results$control_group == "eventually_treated"][[1]],
            att_results$`Pr(>|t|)`[att_results$control_group == "eventually_treated"][[1]]))
cat(sprintf("Never-treated ATT: %.6f (SE %.6f, p %.6f)\n",
            att_results$Estimate[att_results$control_group == "never_treated"][[1]],
            att_results$`Std. Error`[att_results$control_group == "never_treated"][[1]],
            att_results$`Pr(>|t|)`[att_results$control_group == "never_treated"][[1]]))
cat(sprintf("Comparison plot: %s\n", plot_path))
cat(sprintf("ATT comparison table: %s\n", tex_path))
cat(sprintf("Event profile CSV: %s\n", event_csv_path))
cat(sprintf("ATT CSV: %s\n", att_csv_path))
