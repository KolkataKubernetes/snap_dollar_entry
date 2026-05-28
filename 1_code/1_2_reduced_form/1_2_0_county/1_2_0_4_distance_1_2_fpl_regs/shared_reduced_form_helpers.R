library(fixest)
library(ggplot2)

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(active_path)) return(dirname(normalizePath(active_path)))
  }
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) return(dirname(normalizePath(frame$ofile)))
  }
  normalizePath(getwd())
})

source(file.path(dirname(script_dir), "1_2_0_1_IHS_regs", "shared_reduced_form_helpers.R"))

distance_sample_filename <- "2_10_5_event_study_sample_distance_1_2_fpl.rds"

load_event_study_sample <- function() {
  repo_root <- get_repo_root()
  setwd(repo_root)
  processed_root <- read_root_path("2_processed_data/processed_root.txt")
  readRDS(file.path(processed_root, "2_10_retail_access", distance_sample_filename))
}

event_study_outcomes <- c(
  "distance_dollar_stores",
  "distance_supermarkets",
  "distance_convenience_stores",
  "distance_multi_category"
)

event_study_labels <- c(
  "Dollar Stores Distance",
  "Supermarkets Distance",
  "Convenience Stores Distance",
  "Multi Category Distance"
)

names(event_study_labels) <- event_study_outcomes

run_event_study_model <- function(var_name) {
  aba1 <- load_event_study_sample()

  feols(
    as.formula(
      paste0(
        var_name,
        " ~ ",
        "sunab(eventYear2, year, ref.p = -1) + ",
        "population + wage + meanInc + rent + urate | county_fips + year"
      )
    ),
    data = aba1,
    cluster = ~county_fips
  )
}

save_event_study_artifact <- function(var_name, label, file_stub) {
  model <- run_event_study_model(var_name)
  event_profile <- extract_event_profile(model)

  event_plot <- ggplot(event_profile, aes(x = event_time, y = Estimate)) +
    geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
    geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey50") +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.45, color = "#1B4F72") +
    geom_line(linewidth = 0.7, color = "#1B4F72") +
    geom_point(size = 2, color = "#1B4F72") +
    scale_x_continuous(breaks = event_profile$event_time) +
    labs(title = label, x = "Event time", y = "Coefficient") +
    theme_im(base_size = 12)

  ggsave(filename = reduced_form_plot_path(paste0(file_stub, ".pdf")), plot = event_plot, width = 8, height = 6, units = "in")

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
