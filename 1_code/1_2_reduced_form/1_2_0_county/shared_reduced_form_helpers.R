library(dplyr)
library(stringr)
library(fixest)
library(ggplot2)

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

get_repo_root <- function() {
  script_path <- get_script_path()
  start_path <- if (!is.na(script_path)) script_path else getwd()
  find_repo_root(start_path)
}

read_root_path <- function(path_file) {
  readLines(path_file, warn = FALSE)[[1]] |>
    str_trim() |>
    str_remove_all("^['\"]|['\"]$")
}

map_output_component <- function(component) {
  sub("^1_", "3_", component)
}

build_output_dir_path <- function(...) {
  path_components <- Filter(
    function(component) !is.null(component) && length(component) > 0,
    list(...)
  )
  do.call(file.path, as.list(unlist(path_components, use.names = FALSE)))
}

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

ensure_reduced_form_dirs <- function() {
  plot_dir <- build_output_dir_path("3_outputs", "3_2_reduced_form", reduced_form_output_subdir())
  table_dir <- build_output_dir_path("3_outputs", "3_0_tables", reduced_form_output_subdir())
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  list(plot_dir = plot_dir, table_dir = table_dir)
}

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

reduced_form_plot_path <- function(filename) {
  output_dirs <- ensure_reduced_form_dirs()
  next_available_path(file.path(output_dirs$plot_dir, filename))
}

reduced_form_table_path <- function(filename) {
  output_dirs <- ensure_reduced_form_dirs()
  next_available_path(file.path(output_dirs$table_dir, filename))
}

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

load_event_study_sample <- function() {
  repo_root <- get_repo_root()
  setwd(repo_root)

  processed_root <- read_root_path("2_processed_data/processed_root.txt")
  readRDS(file.path(processed_root, "2_9_analysis", "2_9_2_event_study_sample.rds"))
}

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
    data = aba1
  )
}

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
