#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        shared_reduced_form_helpers.R
# Description:      Shared helper functions for the county stock-Poisson
#                   reduced-form branch. These helpers resolve repository
#                   paths, load the branch-specific county stock sample, bridge
#                   from R into Python `diff_diff.WooldridgeDiD`, and write
#                   versioned figure/table/csv artifacts under `3_outputs`.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `2_9_analysis/2_9_5_county_stockpoissonreg_sample.rds`
# OUTPUTS:          No direct outputs. Downstream scripts use these helpers to
#                   write versioned `.pdf`, `.tex`, `.csv`, `.png`, and `.jpeg`
#                   artifacts under `3_outputs`.
# DEPENDENCIES:     `dplyr`, `ggplot2`, `reticulate`
# Review focus:     Verify that the Python bridge targets
#                   `diff_diff.WooldridgeDiD(method = "poisson")` with stock
#                   outcomes, `control_group = "never_treated"`, and
#                   versioned output paths.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(ggplot2)
library(reticulate)

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
  path_value <- readLines(path_file, warn = FALSE)[[1]]
  path_value <- trimws(path_value)
  gsub("^['\"]|['\"]$", "", path_value)
}

ensure_reduced_form_dirs <- function() {
  plot_dir <- file.path("3_outputs", "3_2_reduced_form", "3_2_0_county", "3_2_0_2_stockpoissonregs")
  table_dir <- file.path("3_outputs", "3_0_tables", "3_2_0_county", "3_2_0_2_stockpoissonregs")
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

event_study_outcomes <- c(
  "total_ds_stock",
  "chain_super_market_stock",
  "chain_convenience_store_stock",
  "chain_multi_category_stock",
  "chain_medium_grocery_stock",
  "chain_small_grocery_stock",
  "chain_produce_stock",
  "chain_farmers_market_stock"
)

event_study_labels <- c(
  "Dollar Store Stock",
  "Supermarket Stock",
  "Convenience Store Stock",
  "Multi Category Stock",
  "Medium Grocery Stock",
  "Small Grocery Stock",
  "Produce Stock",
  "Farmers Market Stock"
)

names(event_study_labels) <- event_study_outcomes

poisson_control_group <- "never_treated"
poisson_covariates <- c("population", "wage", "meanInc", "rent", "urate")

control_group_display_label <- function(control_group = poisson_control_group) {
  switch(
    control_group,
    never_treated = "never-treated",
    not_yet_treated = "not-yet-treated",
    control_group
  )
}

load_poisson_sample <- function() {
  repo_root <- get_repo_root()
  setwd(repo_root)

  processed_root <- read_root_path("2_processed_data/processed_root.txt")
  readRDS(file.path(processed_root, "2_9_analysis", "2_9_5_county_stockpoissonreg_sample.rds"))
}

configure_diff_diff <- function() {
  repo_root <- get_repo_root()
  python_path_override <- Sys.getenv("SNAP_DOLLAR_ENTRY_PYTHON", unset = "")
  local_python <- file.path(repo_root, ".venv-diffdiff-arm", "bin", "python")

  if (nzchar(python_path_override)) {
    reticulate::use_python(python_path_override, required = TRUE)
    return(invisible(NULL))
  }

  if (file.exists(local_python)) {
    reticulate::use_python(local_python, required = TRUE)
    return(invisible(NULL))
  }

  stop(
    paste0(
      "No compatible Python interpreter was found for diff-diff. ",
      "Set SNAP_DOLLAR_ENTRY_PYTHON to an arm64 interpreter with diff-diff ",
      "installed, or create the repo-local environment at ",
      local_python,
      "."
    )
  )
}

get_diff_diff_module <- local({
  diff_diff_module <- NULL

  function() {
    if (is.null(diff_diff_module)) {
      configure_diff_diff()
      diff_diff_module <<- reticulate::import("diff_diff", delay_load = FALSE)
    }

    diff_diff_module
  }
})

normalize_results_df <- function(df) {
  if ("conf_int" %in% names(df)) {
    conf_low <- vapply(df$conf_int, function(x) x[[1]], numeric(1))
    conf_high <- vapply(df$conf_int, function(x) x[[2]], numeric(1))
    df$conf_int_lo <- conf_low
    df$conf_int_hi <- conf_high
    df$conf_int <- NULL
  }

  for (column_name in names(df)) {
    if (is.list(df[[column_name]])) {
      element_lengths <- vapply(df[[column_name]], length, integer(1))
      if (length(element_lengths) == 0 || all(element_lengths %in% c(0L, 1L))) {
        df[[column_name]] <- vapply(df[[column_name]], function(x) {
          if (length(x) == 0) {
            return(NA_character_)
          }

          as.character(x[[1]])
        }, character(1))
      }
    }
  }

  df
}

sanitize_effect_df <- function(df) {
  required_cols <- intersect(c("att", "se", "t_stat", "p_value", "conf_int_lo", "conf_int_hi"), names(df))

  if (length(required_cols) == 0) {
    return(df)
  }

  bad_row <- rep(FALSE, nrow(df))

  if ("att" %in% names(df)) {
    bad_row <- bad_row | !is.finite(df$att)
  }

  if ("se" %in% names(df)) {
    bad_row <- bad_row | !is.finite(df$se) | df$se < 0
  }

  if ("p_value" %in% names(df)) {
    bad_row <- bad_row | is.na(df$p_value)
  }

  if ("conf_int_lo" %in% names(df) && "conf_int_hi" %in% names(df)) {
    bad_row <- bad_row | !is.finite(df$conf_int_lo) | !is.finite(df$conf_int_hi)
  }

  for (column_name in required_cols) {
    df[[column_name]][bad_row] <- NA_real_
  }

  df
}

build_poisson_model_frame <- function(var_name) {
  sample <- load_poisson_sample()

  if (!var_name %in% names(sample)) {
    stop(sprintf("Outcome '%s' is not present in the stock-Poisson sample.", var_name))
  }

  sample |>
    transmute(
      county_fips = county_fips,
      year = year,
      g_first_treat = as.integer(g_first_treat),
      outcome = .data[[var_name]],
      population = population,
      wage = wage,
      meanInc = meanInc,
      rent = rent,
      urate = urate
    ) |>
    filter(
      is.finite(g_first_treat),
      g_first_treat >= 0,
      is.finite(outcome),
      outcome >= 0,
      if_all(all_of(poisson_covariates), is.finite)
    )
}

run_event_study_model <- function(var_name) {
  diff_diff <- get_diff_diff_module()
  model_frame <- build_poisson_model_frame(var_name)

  estimator <- diff_diff$WooldridgeDiD(
    method = "poisson",
    control_group = poisson_control_group,
    cluster = "county_fips",
    alpha = 0.05
  )

  fit_args <- list(
    data = model_frame,
    outcome = "outcome",
    unit = "county_fips",
    time = "year",
    cohort = "g_first_treat"
  )

  if (length(poisson_covariates) > 0) {
    fit_args$xtvar <- poisson_covariates
  }

  results <- do.call(estimator$fit, fit_args)

  list(
    estimator = estimator,
    results = results,
    model_frame = model_frame,
    outcome = var_name
  )
}

collect_model_outputs <- function(model_bundle) {
  results <- model_bundle$results

  gt_df <- sanitize_effect_df(normalize_results_df(reticulate::py_to_r(results$to_dataframe("gt"))))
  results$aggregate("event")
  event_df <- sanitize_effect_df(normalize_results_df(reticulate::py_to_r(results$to_dataframe("event"))))
  results$aggregate("group")
  group_df <- sanitize_effect_df(normalize_results_df(reticulate::py_to_r(results$to_dataframe("group"))))
  results$aggregate("calendar")
  calendar_df <- sanitize_effect_df(normalize_results_df(reticulate::py_to_r(results$to_dataframe("calendar"))))
  simple_df <- sanitize_effect_df(normalize_results_df(reticulate::py_to_r(results$to_dataframe("simple"))))

  simple_df$outcome <- model_bundle$outcome
  simple_df$n_obs <- as.integer(results$n_obs)
  simple_df$n_treated_units <- as.integer(results$n_treated_units)
  simple_df$n_control_units <- as.integer(results$n_control_units)
  simple_df$method <- as.character(results$method)
  simple_df$control_group <- as.character(results$control_group)

  gt_df$outcome <- model_bundle$outcome
  event_df$outcome <- model_bundle$outcome
  group_df$outcome <- model_bundle$outcome
  calendar_df$outcome <- model_bundle$outcome

  list(
    gt_df = gt_df,
    event_df = event_df,
    group_df = group_df,
    calendar_df = calendar_df,
    simple_df = simple_df
  )
}

format_p_value <- function(p_value) {
  ifelse(is.na(p_value), "", ifelse(p_value < 0.001, "<0.001", sprintf("%.3f", p_value)))
}

significance_stars <- function(p_value) {
  ifelse(
    is.na(p_value),
    "",
    ifelse(p_value < 0.01, "***", ifelse(p_value < 0.05, "**", ifelse(p_value < 0.1, "*", "")))
  )
}

format_att_value <- function(att, p_value) {
  ifelse(is.na(att), "Not estimable", paste0(sprintf("%.4f", att), significance_stars(p_value)))
}

format_se_value <- function(se) {
  ifelse(is.na(se), "", paste0("(", sprintf("%.4f", se), ")"))
}

format_ci_value <- function(conf_int_lo, conf_int_hi) {
  ifelse(
    is.na(conf_int_lo) | is.na(conf_int_hi),
    "",
    sprintf("[%.4f, %.4f]", conf_int_lo, conf_int_hi)
  )
}

build_event_plot <- function(event_df, label) {
  if (nrow(event_df) == 0) {
    stop("No event-study aggregation rows are available to plot.")
  }

  ggplot(event_df, aes(x = relative_period, y = att)) +
    geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
    geom_vline(xintercept = -0.5, linewidth = 0.4, linetype = "dashed", color = "grey50") +
    geom_errorbar(aes(ymin = conf_int_lo, ymax = conf_int_hi), width = 0.12, linewidth = 0.45, color = "#1B4F72") +
    geom_line(linewidth = 0.7, color = "#1B4F72") +
    geom_point(size = 2, color = "#1B4F72") +
    scale_x_continuous(breaks = sort(unique(event_df$relative_period))) +
    labs(
      title = paste0("Stock-Stock-Poisson ETWFE ATT: ", label),
      subtitle = paste0(
        "diff-diff WooldridgeDiD with ",
        control_group_display_label(),
        " controls"
      ),
      x = "Relative period",
      y = "ATT"
    ) +
    theme_im(base_size = 12)
}

write_single_outcome_table <- function(simple_df, label, output_path) {
  row <- simple_df[1, ]

  table_lines <- c(
    "\\begingroup",
    "\\centering",
    "\\begin{tabular}{lccccc}",
    "   \\tabularnewline \\midrule \\midrule",
    "   Outcome & ATT & Std. Error & p-value & 95\\% CI & Units\\\\",
    "   \\midrule",
    sprintf(
      "   %s & %s & %s & %s & %s & %s/%s\\\\",
      label,
      format_att_value(row$att, row$p_value),
      ifelse(is.na(row$se), "", sprintf("%.4f", row$se)),
      format_p_value(row$p_value),
      format_ci_value(row$conf_int_lo, row$conf_int_hi),
      format(row$n_treated_units, big.mark = ","),
      format(row$n_control_units, big.mark = ",")
    ),
    "   \\midrule \\midrule",
    "   \\multicolumn{6}{l}{\\emph{Estimator: diff-diff WooldridgeDiD(method = poisson)}}\\\\",
    sprintf(
      "   \\\\multicolumn{6}{l}{\\\\emph{Control group: %s; county-clustered standard errors}}\\\\\\\\",
      control_group_display_label()
    ),
    "   \\multicolumn{6}{l}{\\emph{Signif. Codes: ***: 0.01, **: 0.05, *: 0.1}}\\\\",
    "\\end{tabular}",
    "\\par\\endgroup"
  )

  writeLines(table_lines, con = output_path)
}

save_event_study_artifact <- function(var_name, label, file_stub) {
  model_bundle <- run_event_study_model(var_name)
  outputs <- collect_model_outputs(model_bundle)

  plot_path <- reduced_form_plot_path(paste0(file_stub, ".pdf"))
  tex_path <- reduced_form_table_path(paste0(file_stub, ".tex"))
  gt_csv_path <- reduced_form_table_path(paste0(file_stub, "_gt.csv"))
  event_csv_path <- reduced_form_table_path(paste0(file_stub, "_event.csv"))
  aggregate_csv_path <- reduced_form_table_path(paste0(file_stub, "_aggregates.csv"))

  event_plot <- build_event_plot(outputs$event_df, label)
  ggsave(plot_path, event_plot, width = 8, height = 6, units = "in")

  write_single_outcome_table(outputs$simple_df, label, tex_path)

  aggregate_df <- bind_rows(
    outputs$simple_df |> mutate(aggregation = "simple"),
    outputs$event_df |> mutate(aggregation = "event"),
    outputs$group_df |> mutate(aggregation = "group"),
    outputs$calendar_df |> mutate(aggregation = "calendar")
  )

  write.csv(outputs$gt_df, gt_csv_path, row.names = FALSE)
  write.csv(outputs$event_df, event_csv_path, row.names = FALSE)
  write.csv(aggregate_df, aggregate_csv_path, row.names = FALSE)

  invisible(
    list(
      model_bundle = model_bundle,
      outputs = outputs,
      plot_path = plot_path,
      tex_path = tex_path,
      gt_csv_path = gt_csv_path,
      event_csv_path = event_csv_path,
      aggregate_csv_path = aggregate_csv_path
    )
  )
}
