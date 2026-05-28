#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_11_event_study_total_ds_never_treated_control.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Standalone Sun-Abraham event study for Dollar Stores using
#                   all never-treated counties in the state/DC sample as the
#                   reference cohort.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
# PROCEDURES:       Rebuild the 2014-2019 event-study sample while retaining
#                   all never-treated counties in the sample universe, estimate
#                   the Dollar Stores reduced form, and save isolated
#                   event-study / ATT outputs.
# OUTPUTS:          `3_outputs/3_2_reduced_form/isolated/3_2_11_event_study_ihs_total_ds_never_treated_control*.pdf`
#                   `3_outputs/3_0_tables/isolated/3_2_11_event_study_ihs_total_ds_never_treated_control*.tex`
#                   `3_outputs/3_0_tables/isolated/3_2_11_event_study_ihs_total_ds_never_treated_control*_event_profile.csv`
#                   `3_outputs/3_0_tables/isolated/3_2_11_event_study_ihs_total_ds_never_treated_control*_att.csv`
# DEPENDENCIES:     `dplyr`, `fixest`, `ggplot2`
# Review focus:     The identifying design difference from the benchmark
#                   reduced form is the control group: this script keeps all
#                   never-treated counties in the comparison sample.
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

# Purpose: define the shared plotting theme used in the isolated event-study figure.
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

# Load the county analysis panel that will be rebuilt into the isolated sample.
processed_root <- read_root_path("2_processed_data/processed_root.txt")
analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

# Rebuild the sample while keeping all never-treated counties available as controls.
# Review focus: the benchmark covariate scaling and timing sentinels remain the
# same; the substantive change is the inclusion rule for never-treated units.
event_study_sample <- analysis_panel |>
  mutate(
    lowq = total_ds + chain_convenience_store,
    rent = rent / 1000,
    meanInc = meanInc / 1000,
    zl = dplyr::lag(urate),
    z = urate,
    no_stores = (total_ds + chain_super_market + chain_convenience_store + chain_multi_category) == 0,
    state_fips = county_fips %/% 1000
  ) |>
  filter(year %in% 2014:2019) |>
  mutate(
    tau2 = if_else(is.na(tau2), -1000, tau2),
    eventYear2 = if_else(is.na(eventYear2), 10000, eventYear2),
    treated_group = eventYear2 != 10000,
    never_treated = eventYear2 == 10000
  ) |>
  # Keep all never-treated counties plus treated counties that satisfy the
  # benchmark event-time window.
  filter(never_treated | year - eventYear2 >= -3) |>
  mutate(state_year = paste(state, year))

# Estimate the Dollar Stores reduced form under the all-never-treated control design.
model <- feols(
  log(total_ds + sqrt(total_ds^2 + 1)) ~
    sunab(eventYear2, year, ref.p = -1) +
    population + wage + meanInc + rent + urate |
    county_fips + year,
  data = event_study_sample,
  vcov = ~county_fips
)

event_coeftable <- as.data.frame(coeftable(model))
event_coeftable$term <- rownames(event_coeftable)
rownames(event_coeftable) <- NULL

event_confint <- as.data.frame(confint(model))
event_confint$term <- rownames(event_confint)
rownames(event_confint) <- NULL
names(event_confint)[1:2] <- c("conf_low", "conf_high")

# Convert the event-study coefficients into a plotting-ready event profile.
event_results <- event_coeftable |>
  filter(grepl("^year::", term)) |>
  left_join(event_confint, by = "term") |>
  mutate(
    event_time = as.integer(sub("^year::", "", term)),
    control_group = "never_treated"
  ) |>
  select(control_group, event_time, term, Estimate, `Std. Error`, `t value`, `Pr(>|t|)`, conf_low, conf_high)

att_model <- summary(model, agg = "att")
att_coeftable <- as.data.frame(coeftable(att_model))
att_coeftable$term <- rownames(att_coeftable)
rownames(att_coeftable) <- NULL

# Extract the aggregated ATT summary for export alongside the event profile.
att_results <- att_coeftable |>
  filter(term == "ATT") |>
  mutate(control_group = "never_treated") |>
  select(control_group, term, Estimate, `Std. Error`, `t value`, `Pr(>|t|)`)

# Create the isolated output folders and version all exported artifact names.
ensure_output_dirs()

plot_path <- next_available_path(
  file.path("3_outputs", "3_2_reduced_form", "isolated", "3_2_11_event_study_ihs_total_ds_never_treated_control.pdf")
)
tex_path <- next_available_path(
  file.path("3_outputs", "3_0_tables", "isolated", "3_2_11_event_study_ihs_total_ds_never_treated_control_att.tex")
)
event_csv_path <- next_available_path(
  file.path("3_outputs", "3_0_tables", "isolated", "3_2_11_event_study_ihs_total_ds_never_treated_control_event_profile.csv")
)
att_csv_path <- next_available_path(
  file.path("3_outputs", "3_0_tables", "isolated", "3_2_11_event_study_ihs_total_ds_never_treated_control_att.csv")
)

# Plot the event-time profile so reviewers can compare it against the benchmark control-group choice.
event_plot <- ggplot(
  event_results,
  aes(x = event_time, y = Estimate)
) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
  geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.45, color = "#1B4F72") +
  geom_line(linewidth = 0.7, color = "#1B4F72") +
  geom_point(size = 2, color = "#1B4F72") +
  scale_x_continuous(breaks = sort(unique(event_results$event_time))) +
  labs(
    title = "IHS(Dollar Stores) - Never-Treated Control",
    x = "Event time",
    y = "Coefficient"
  ) +
  theme_im(base_size = 12)

ggsave(plot_path, event_plot, width = 8, height = 6, units = "in")

etable(
  model,
  agg = "att",
  keep = "ATT",
  file = tex_path,
  replace = TRUE
)

write.csv(event_results, event_csv_path, row.names = FALSE)
write.csv(att_results, att_csv_path, row.names = FALSE)

cat("Standalone never-treated control event study completed.\n")
cat(sprintf("Sample rows: %s\n", nrow(event_study_sample)))
cat(sprintf("Sample counties: %s\n", dplyr::n_distinct(event_study_sample$county_fips)))
cat(sprintf("Never-treated counties: %s\n", dplyr::n_distinct(event_study_sample$county_fips[event_study_sample$never_treated])))
cat(sprintf("ATT estimate: %.6f\n", att_results$Estimate[[1]]))
cat(sprintf("ATT standard error: %.6f\n", att_results$`Std. Error`[[1]]))
cat(sprintf("ATT p-value: %.6f\n", att_results$`Pr(>|t|)`[[1]]))
cat(sprintf("Plot: %s\n", plot_path))
cat(sprintf("ATT table: %s\n", tex_path))
cat(sprintf("Event profile CSV: %s\n", event_csv_path))
cat(sprintf("ATT CSV: %s\n", att_csv_path))
