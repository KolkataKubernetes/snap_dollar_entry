library(fixest)
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

source(file.path(script_dir, "shared_reduced_form_helpers.R"))

models <- lapply(event_study_outcomes, run_event_study_model)
names(models) <- event_study_outcomes

etable(
  models$total_ds,
  models$chain_super_market,
  models$chain_convenience_store,
  models$chain_multi_category,
  models$chain_medium_grocery,
  models$chain_small_grocery,
  models$chain_produce,
  models$chain_farmers_market,
  headers = unname(event_study_labels),
  file = reduced_form_table_path("3_2_9_event_study_ihs_all.tex"),
  agg = "att",
  keep = "ATT",
  replace = TRUE
)
