#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_13_honestdid_total_ds_control_groups.R
# Previous author:  -
# Current author:   Codex
# Last Updated:     March 17, 2026
# Description:      Standalone HonestDiD sensitivity analysis for the Dollar
#                   Stores Sun-Abraham event study under the current
#                   eventually-treated control sample and the alternative
#                   never-treated control sample.
# INPUTS:           `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_processed_data/processed_root.txt`
# PROCEDURES:       Rebuild both estimation samples, estimate both reduced-form
#                   models, recover the aggregated period-level covariance
#                   matrix, and run the Roth-Rambachan relative-magnitudes
#                   sensitivity analysis for the first post period and the
#                   average post effect.
# OUTPUTS:          `3_outputs/3_2_reduced_form/3_2_13_honestdid_total_ds_sensitivity_plots*.pdf`
#                   `3_outputs/tables/3_2_13_honestdid_total_ds_summary*.csv`
#                   `3_outputs/tables/3_2_13_honestdid_total_ds_detail*.csv`
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(fixest)
library(HonestDiD)
library(ggplot2)

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

read_root_path <- function(path_file) {
  path_value <- readLines(path_file, warn = FALSE)[[1]]
  path_value <- trimws(path_value)
  path_value <- sub("^'", "", path_value)
  sub("'$", "", path_value)
}

ensure_output_dirs <- function() {
  dir.create(file.path("3_outputs", "3_2_reduced_form"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path("3_outputs", "tables"), recursive = TRUE, showWarnings = FALSE)
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

estimate_model <- function(data) {
  feols(
    log(total_ds + sqrt(total_ds^2 + 1)) ~
      sunab(eventYear2, year, ref.p = 0) +
      population + wage + meanInc + rent + urate |
      county_fips + year,
    data = data
  )
}

extract_aggregated_event_study <- function(model) {
  raw_summary <- summary(model, agg = FALSE)
  coef_raw <- coef(raw_summary)
  vcov_raw <- raw_summary$cov.scaled
  mm <- model.matrix(raw_summary)

  event_names <- names(coef_raw)[grepl("^year::", names(coef_raw))]
  event_labels <- unique(sub(":cohort::.*$", "", event_names))

  weight_matrix <- matrix(
    0,
    nrow = length(event_labels),
    ncol = length(event_names),
    dimnames = list(event_labels, event_names)
  )

  for (event_label in event_labels) {
    matched_names <- event_names[startsWith(event_names, event_label)]
    shares <- colSums(sign(mm[, matched_names, drop = FALSE]))
    shares <- shares / sum(shares)
    weight_matrix[event_label, matched_names] <- shares
  }

  betahat <- as.vector(weight_matrix %*% coef_raw[event_names])
  sigma <- weight_matrix %*% vcov_raw[event_names, event_names] %*% t(weight_matrix)

  names(betahat) <- rownames(weight_matrix)
  rownames(sigma) <- rownames(weight_matrix)
  colnames(sigma) <- rownames(weight_matrix)

  list(
    betahat = betahat,
    sigma = sigma,
    event_terms = rownames(weight_matrix),
    event_times = as.integer(sub("^year::", "", rownames(weight_matrix))),
    numPrePeriods = sum(grepl("^year::-", rownames(weight_matrix))),
    numPostPeriods = sum(grepl("^year::[0-9]", rownames(weight_matrix)))
  )
}

run_honestdid_target <- function(agg_obj, l_vec, control_group, target_name, mbar_vec) {
  original <- constructOriginalCS(
    betahat = agg_obj$betahat,
    sigma = agg_obj$sigma,
    numPrePeriods = agg_obj$numPrePeriods,
    numPostPeriods = agg_obj$numPostPeriods,
    l_vec = l_vec
  ) |>
    mutate(
      control_group = control_group,
      target = target_name,
      theta_hat = sum(l_vec * agg_obj$betahat[(agg_obj$numPrePeriods + 1):length(agg_obj$betahat)])
    )

  robust <- createSensitivityResults_relativeMagnitudes(
    betahat = agg_obj$betahat,
    sigma = agg_obj$sigma,
    numPrePeriods = agg_obj$numPrePeriods,
    numPostPeriods = agg_obj$numPostPeriods,
    l_vec = l_vec,
    Mbarvec = mbar_vec,
    gridPoints = 500
  ) |>
    mutate(
      control_group = control_group,
      target = target_name,
      theta_hat = sum(l_vec * agg_obj$betahat[(agg_obj$numPrePeriods + 1):length(agg_obj$betahat)])
    )

  breakdown_row <- robust |>
    arrange(Mbar) |>
    filter(lb <= 0, ub >= 0) |>
    slice_head(n = 1)

  breakdown_mbar <- if (nrow(breakdown_row) == 0) {
    NA_real_
  } else {
    breakdown_row$Mbar[[1]]
  }

  summary_row <- tibble(
    control_group = control_group,
    target = target_name,
    theta_hat = original$theta_hat[[1]],
    original_lb = original$lb[[1]],
    original_ub = original$ub[[1]],
    breakdown_mbar = breakdown_mbar,
    robust_lb_mbar_0 = robust$lb[robust$Mbar == 0][[1]],
    robust_ub_mbar_0 = robust$ub[robust$Mbar == 0][[1]],
    robust_lb_mbar_0_5 = robust$lb[robust$Mbar == 0.5][[1]],
    robust_ub_mbar_0_5 = robust$ub[robust$Mbar == 0.5][[1]],
    robust_lb_mbar_1 = robust$lb[robust$Mbar == 1][[1]],
    robust_ub_mbar_1 = robust$ub[robust$Mbar == 1][[1]],
    robust_lb_mbar_2 = robust$lb[robust$Mbar == 2][[1]],
    robust_ub_mbar_2 = robust$ub[robust$Mbar == 2][[1]]
  )

  list(
    original = original,
    robust = robust,
    summary = summary_row
  )
}

mbar_vec <- seq(0, 3, by = 0.25)
target_specs <- list(
  first_post = HonestDiD::basisVector(index = 1, size = 4),
  average_post = rep(1 / 4, 4)
)

processed_root <- read_root_path("2_processed_data/processed_root.txt")
analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

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
  group_by(state_fips) |>
  mutate(treated_state = sum(treated_group) > 0) |>
  group_by(county_fips) |>
  mutate(treated_county = sum(treated_group) > 0) |>
  ungroup()

eventually_treated_sample <- base_panel |>
  filter(year - eventYear2 >= -3, treated_state, treated_county)

never_treated_sample <- base_panel |>
  filter(treated_state, never_treated | year - eventYear2 >= -3)

models <- list(
  eventually_treated = estimate_model(eventually_treated_sample),
  never_treated = estimate_model(never_treated_sample)
)

agg_objects <- lapply(models, extract_aggregated_event_study)

results <- list()
for (control_group in names(agg_objects)) {
  for (target_name in names(target_specs)) {
    key <- paste(control_group, target_name, sep = "__")
    results[[key]] <- run_honestdid_target(
      agg_obj = agg_objects[[control_group]],
      l_vec = target_specs[[target_name]],
      control_group = control_group,
      target_name = target_name,
      mbar_vec = mbar_vec
    )
  }
}

summary_results <- bind_rows(lapply(results, `[[`, "summary"))
detailed_results <- bind_rows(lapply(results, function(x) {
  bind_rows(
    x$original |>
      mutate(Mbar = NA_real_, result_type = "original"),
    x$robust |>
      mutate(result_type = "robust")
  )
}))

ensure_output_dirs()

summary_path <- next_available_path(
  file.path("3_outputs", "tables", "3_2_13_honestdid_total_ds_summary.csv")
)
detail_path <- next_available_path(
  file.path("3_outputs", "tables", "3_2_13_honestdid_total_ds_detail.csv")
)
plot_path <- next_available_path(
  file.path("3_outputs", "3_2_reduced_form", "3_2_13_honestdid_total_ds_sensitivity_plots.pdf")
)

write.csv(summary_results, summary_path, row.names = FALSE)
write.csv(detailed_results, detail_path, row.names = FALSE)

pdf(plot_path, width = 8, height = 6)
for (result_name in names(results)) {
  result_item <- results[[result_name]]
  plot_obj <- createSensitivityPlot_relativeMagnitudes(
    robustResults = result_item$robust,
    originalResults = result_item$original,
    maxMbar = max(mbar_vec)
  ) +
    labs(
      title = paste(
        "HonestDiD:",
        gsub("_", "-", result_item$summary$control_group[[1]]),
        "|",
        gsub("_", " ", result_item$summary$target[[1]])
      ),
      subtitle = "Roth-Rambachan relative-magnitudes sensitivity analysis",
      x = "Mbar",
      y = "Confidence interval"
    ) +
    theme_im(base_size = 12)
  print(plot_obj)
}
dev.off()

cat("Standalone HonestDiD sensitivity analysis completed.\n")
cat(sprintf("Summary CSV: %s\n", summary_path))
cat(sprintf("Detail CSV: %s\n", detail_path))
cat(sprintf("Sensitivity plots PDF: %s\n", plot_path))
for (i in seq_len(nrow(summary_results))) {
  row <- summary_results[i, ]
  breakdown_display <- if (is.na(row$breakdown_mbar)) "not reached by Mbar = 3" else sprintf("%.2f", row$breakdown_mbar)
  cat(sprintf(
    "%s / %s: theta_hat = %.6f, original CI = [%.6f, %.6f], breakdown Mbar = %s\n",
    row$control_group,
    row$target,
    row$theta_hat,
    row$original_lb,
    row$original_ub,
    breakdown_display
  ))
}
