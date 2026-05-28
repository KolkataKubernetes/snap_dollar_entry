#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_1_9_event_study_all_table.R
# Description:      Estimate the benchmark county reduced form for every outlet
#                   outcome and export a combined ATT table.
# INPUTS:           `2_9_analysis/2_9_2_event_study_sample.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `3_outputs/3_0_tables/3_2_0_county/3_2_0_1_IHS_regs/3_2_0_1_9_event_study_ihs_all*.tex`
# DEPENDENCIES:     `fixest`, `shared_reduced_form_helpers.R`
# Review focus:     The column order and labels are inherited from
#                   `event_study_outcomes` and `event_study_labels`, so any
#                   change to those registries changes the interpretation of
#                   this table as well as its formatting.
#///////////////////////////////////////////////////////////////////////////////

library(fixest)
# Resolve the script directory so the local benchmark helper file can be sourced.
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

# Load the shared benchmark helpers that define the common model and outcome registry.
source(file.path(script_dir, "shared_reduced_form_helpers.R"))

# Estimate one benchmark model per outcome using the shared helper function.
models <- lapply(event_study_outcomes, run_event_study_model)
names(models) <- event_study_outcomes

# Export a combined ATT table across the benchmark outcome list.
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
  file = reduced_form_table_path("3_2_0_1_9_event_study_ihs_all.tex"),
  agg = "att",
  keep = "ATT",
  replace = TRUE
)
