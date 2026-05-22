#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        shared_reduced_form_helpers.R
# Description:      Shared helper functions for the county reduced-form
#                   scripts. These helpers resolve paths, load the benchmark
#                   event-study sample, estimate the benchmark Sun-Abraham
#                   specification, and write versioned figure/table outputs.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `2_9_analysis/2_9_2_event_study_sample.rds`
# OUTPUTS:          No direct outputs. Downstream scripts use these helpers to
#                   write versioned `.pdf` and `.tex` artifacts under
#                   `3_outputs`.
# DEPENDENCIES:     `dplyr`, `stringr`, `fixest`, `ggplot2`
# Review focus:     Verify that path resolution reaches the repository root,
#                   that the benchmark model formula matches the intended
#                   reduced form, and that `next_available_path()` prevents
#                   silent overwrites by versioning output filenames.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(stringr)
library(fixest)
library(ggplot2)

# Resolve the currently running script path across command line, RStudio, and sourced execution.
# Purpose: identify the on-disk location of the caller so sibling helper files can be sourced safely.
# Inputs: none beyond the current R session state.
# Returns: normalized script path when available, otherwise `NA_character_`.
# Side effects: none.
get_script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)

  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]])))
  }

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    script_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(script_path)) {
      return(normalizePath(script_path))
    }
  }

  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) {
      return(normalizePath(frame$ofile))
    }
  }

  NA_character_
}

# Walk upward from a file or directory until the repository root markers are found.
# Purpose: avoid hardcoded absolute paths by discovering the repo from the caller location.
# Inputs: `start_path`, a file path or directory path somewhere inside the repository.
# Returns: normalized repository root path.
# Side effects: stops with an error if the root cannot be found.
find_repo_root <- function(start_path) {
  candidate <- normalizePath(start_path, winslash = "/", mustWork = FALSE)

  if (!dir.exists(candidate)) {
    candidate <- dirname(candidate)
  }

  repeat {
    if (file.exists(file.path(candidate, "AGENTS.md")) && dir.exists(file.path(candidate, "1_code"))) {
      return(candidate)
    }

    parent <- dirname(candidate)
    if (identical(parent, candidate)) {
      stop(sprintf("Could not locate repository root from '%s'.", start_path))
    }

    candidate <- parent
  }
}

# Resolve the repository root for the currently executing reduced-form script.
# Purpose: provide a single root locator that downstream helpers can reuse.
# Inputs: none.
# Returns: normalized repository root path.
# Side effects: inherits the stop behavior from `find_repo_root()` if discovery fails.
get_repo_root <- function() {
  script_path <- get_script_path()
  start_path <- if (!is.na(script_path)) script_path else getwd()
  find_repo_root(start_path)
}

# Read a one-line pointer file that stores an external root path.
# Purpose: recover Box-backed or other externally configured roots without hardcoding user paths.
# Inputs: `path_file`, a repository-relative text file containing one quoted or unquoted path.
# Returns: trimmed path string with surrounding quotes removed.
# Side effects: reads from disk.
read_root_path <- function(path_file) {
  readLines(path_file, warn = FALSE)[[1]] |>
    str_trim() |>
    str_remove_all("^['\"]|['\"]$")
}

# Translate a `1_code` path component into the matching `3_outputs` component.
# Purpose: keep output subdirectories parallel to the code layout without hardcoding each folder.
# Inputs: `component`, one segment from a reduced-form code path.
# Returns: the same segment with a leading `1_` replaced by `3_` when present.
# Side effects: none.
map_output_component <- function(component) {
  sub("^1_", "3_", component)
}

# Build a file path from non-empty path fragments.
# Purpose: centralize path assembly while ignoring `NULL` or zero-length placeholders.
# Inputs: variadic path components.
# Returns: a single path created with `file.path()`.
# Side effects: none.
build_output_dir_path <- function(...) {
  path_components <- Filter(
    function(component) !is.null(component) && length(component) > 0,
    list(...)
  )
  do.call(file.path, as.list(unlist(path_components, use.names = FALSE)))
}

# Recover the reduced-form subdirectory that should be mirrored inside `3_outputs`.
# Purpose: map the current script location to a matching output folder tree.
# Inputs: none.
# Returns: character vector of path components, or `character()` when no subdirectory applies.
# Side effects: depends on the discovered script path and repository root.
reduced_form_output_subdir <- function() {
  script_path <- get_script_path()

  if (is.na(script_path)) {
    return(character())
  }

  repo_root <- get_repo_root()
  stage_root <- normalizePath(file.path(repo_root, "1_code", "1_2_reduced_form"), winslash = "/", mustWork = TRUE)
  script_dir <- normalizePath(dirname(script_path), winslash = "/", mustWork = TRUE)
  relative_dir <- sub(paste0("^", stage_root, "/?"), "", script_dir)

  if (identical(relative_dir, script_dir) || identical(relative_dir, "")) {
    return(character())
  }

  vapply(strsplit(relative_dir, "/", fixed = TRUE)[[1]], map_output_component, character(1))
}

# Create the plot and table directories for the current reduced-form script family.
# Purpose: ensure downstream writers can save artifacts without assuming folders already exist.
# Inputs: none.
# Returns: list with `plot_dir` and `table_dir`.
# Side effects: creates directories if missing.
ensure_reduced_form_dirs <- function() {
  plot_dir <- build_output_dir_path("3_outputs", "3_2_reduced_form", reduced_form_output_subdir())
  table_dir <- build_output_dir_path("3_outputs", "3_0_tables", reduced_form_output_subdir())
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  list(plot_dir = plot_dir, table_dir = table_dir)
}

# Version an output filename instead of overwriting an existing artifact.
# Purpose: preserve prior analytical outputs so reruns remain non-destructive.
# Inputs: `path`, the preferred output path.
# Returns: `path` itself when unused, otherwise the next `_vNN` variant.
# Side effects: reads the filesystem to test for collisions.
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

# Build a versioned plot output path for the current reduced-form script.
# Purpose: route figure outputs into the mirrored reduced-form plot directory.
# Inputs: `filename`, the desired plot filename.
# Returns: full versioned plot path.
# Side effects: may create output directories through `ensure_reduced_form_dirs()`.
reduced_form_plot_path <- function(filename) {
  output_dirs <- ensure_reduced_form_dirs()
  next_available_path(file.path(output_dirs$plot_dir, filename))
}

# Build a versioned table output path for the current reduced-form script.
# Purpose: route table outputs into the mirrored reduced-form table directory.
# Inputs: `filename`, the desired table filename.
# Returns: full versioned table path.
# Side effects: may create output directories through `ensure_reduced_form_dirs()`.
reduced_form_table_path <- function(filename) {
  output_dirs <- ensure_reduced_form_dirs()
  next_available_path(file.path(output_dirs$table_dir, filename))
}

# Define the shared plotting theme used across reduced-form figures.
# Purpose: keep benchmark figures visually consistent across outcome scripts.
# Inputs: `base_size`, the base text size for `theme_minimal()`.
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

# Load the saved benchmark event-study sample used by the helper-driven scripts.
# Purpose: separate sample construction from repeated estimation scripts.
# Inputs: none.
# Returns: the `2_9_2_event_study_sample.rds` data frame.
# Side effects: sets the working directory to the repository root and reads from disk.
load_event_study_sample <- function() {
  repo_root <- get_repo_root()
  setwd(repo_root)

  processed_root <- read_root_path("2_processed_data/processed_root.txt")
  readRDS(file.path(processed_root, "2_9_analysis", "2_9_2_event_study_sample.rds"))
}

# These registries define the benchmark outcome order and display labels used by
# the single-outcome scripts, combined ATT table, and slide-ready image table.
event_study_outcomes <- c(
  "total_ds",
  "chain_super_market",
  "chain_convenience_store",
  "chain_multi_category",
  "chain_medium_grocery",
  "chain_small_grocery",
  "chain_produce",
  "chain_farmers_market"
)

event_study_labels <- c(
  "Dollar Stores",
  "Supermarkets",
  "Convenience Stores",
  "Multi Category",
  "Medium Grocery",
  "Small Grocery",
  "Produce",
  "Farmers Market"
)

names(event_study_labels) <- event_study_outcomes

# Estimate the benchmark county reduced form for one outlet-count outcome.
# Purpose: keep the benchmark Sun-Abraham specification identical across outcome scripts.
# Inputs: `var_name`, the name of an outcome column already present in the benchmark sample.
# Returns: a `fixest` model object.
# Side effects: loads the benchmark sample from disk through `load_event_study_sample()`.
# Review focus: confirm the IHS transform, covariate set, event-study term, and county clustering.
run_event_study_model <- function(var_name) {
  aba1 <- load_event_study_sample()

  feols(
    as.formula(
      paste0(
        "log(",
        var_name,
        " + sqrt(",
        var_name,
        "^2 + 1)) ~ ",
        "sunab(eventYear2, year, ref.p = 0) + ",
        "population + wage + meanInc + rent + urate | county_fips + year"
      )
    ),
    data = aba1,
    vcov = ~county_fips
  )
}

# Extract event-time coefficients and confidence intervals from a fitted benchmark model.
# Purpose: convert the `fixest` object into a plotting-ready event-profile table.
# Inputs: `model`, a fitted benchmark reduced-form model.
# Returns: data frame ordered by `event_time`.
# Side effects: none.
extract_event_profile <- function(model) {
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
    mutate(event_time = as.integer(sub("^year::", "", term))) |>
    arrange(event_time)
}

# Estimate the benchmark reduced form and save its figure and ATT table.
# Purpose: give the thin wrapper scripts a single call that produces the standard artifacts.
# Inputs: `var_name` outcome column, `label` display name, and `file_stub` output stem.
# Returns: the fitted model invisibly.
# Side effects: writes versioned `.pdf` and `.tex` outputs under `3_outputs`.
# Review focus: verify that reruns version outputs rather than overwriting them and
#               that the saved artifacts use the same benchmark model object.
save_event_study_artifact <- function(var_name, label, file_stub) {
  model <- run_event_study_model(var_name)
  event_profile <- extract_event_profile(model)

  event_plot <- ggplot(
    event_profile,
    aes(x = event_time, y = Estimate)
  ) +
    geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
    geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey50") +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.45, color = "#1B4F72") +
    geom_line(linewidth = 0.7, color = "#1B4F72") +
    geom_point(size = 2, color = "#1B4F72") +
    scale_x_continuous(breaks = event_profile$event_time) +
    labs(
      title = paste0("IHS(", label, ")"),
      x = "Event time",
      y = "Coefficient"
    ) +
    theme_im(base_size = 12)

  ggsave(
    filename = reduced_form_plot_path(paste0(file_stub, ".pdf")),
    plot = event_plot,
    width = 8,
    height = 6,
    units = "in"
  )

  etable(
    model,
    agg = "att",
    keep = "ATT",
    dict = event_study_labels,
    file = reduced_form_table_path(paste0(file_stub, ".tex")),
    replace = TRUE
  )

  invisible(model)
}
