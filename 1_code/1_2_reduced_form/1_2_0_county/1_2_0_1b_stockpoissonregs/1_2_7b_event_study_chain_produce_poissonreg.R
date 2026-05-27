#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_7b_event_study_chain_produce_poissonreg.R
# Description:      Thin wrapper that runs the county stock-Poisson ETWFE reduced
#                   form for produce stock using the shared helper script.
# INPUTS:           `2_9_analysis/2_9_5_county_stockpoissonreg_sample.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          versioned plot/table/csv artifacts for the produce Poisson
#                   branch under `3_outputs`
# DEPENDENCIES:     `shared_reduced_form_helpers.R`
# Review focus:     Verify that the delegated outcome and output stub both
#                   correspond to Produce stock.
#///////////////////////////////////////////////////////////////////////////////

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(active_path)) return(dirname(normalizePath(active_path)))
  }
  for (frame in rev(sys.frames())) if (!is.null(frame$ofile)) return(dirname(normalizePath(frame$ofile)))
  normalizePath(getwd())
})

source(file.path(script_dir, "shared_reduced_form_helpers.R"))
save_event_study_artifact("chain_produce_stock", "Produce Stock", "3_2_7b_event_study_chain_produce_stockpoissonreg")
