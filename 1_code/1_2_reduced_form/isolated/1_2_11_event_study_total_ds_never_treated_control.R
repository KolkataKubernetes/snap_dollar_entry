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
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(fixest)
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
  dir.create(file.path("3_outputs", "3_2_reduced_form", "isolated"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path("3_outputs", "3_0_tables", "isolated"), recursive = TRUE, showWarnings = FALSE)
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

processed_root <- read_root_path("2_processed_data/processed_root.txt")
analysis_panel <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))

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
  filter(never_treated | year - eventYear2 >= -3) |>
  mutate(state_year = paste(state, year))

model <- feols(
  log(total_ds + sqrt(total_ds^2 + 1)) ~
    sunab(eventYear2, year, ref.p = 0) +
    population + wage + meanInc + rent + urate |
    county_fips + year,
  data = event_study_sample
)

event_coeftable <- as.data.frame(coeftable(model))
event_coeftable$term <- rownames(event_coeftable)
rownames(event_coeftable) <- NULL

event_confint <- as.data.frame(confint(model))
event_confint$term <- rownames(event_confint)
rownames(event_confint) <- NULL
names(event_confint)[1:2] <- c("conf_low", "conf_high")

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

att_results <- att_coeftable |>
  filter(term == "ATT") |>
  mutate(control_group = "never_treated") |>
  select(control_group, term, Estimate, `Std. Error`, `t value`, `Pr(>|t|)`)

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
