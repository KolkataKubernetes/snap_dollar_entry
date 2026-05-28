#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_1_1_event_study_total_ds.R
# Description:      Thin wrapper that runs the benchmark county reduced form for
#                   Dollar Stores using the shared helper script.
# INPUTS:           `2_9_analysis/2_9_2_event_study_sample.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_1_IHS_regs/3_2_0_1_1_event_study_ihs_total_ds*.pdf`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_1_IHS_regs/3_2_0_1_1_event_study_ihs_total_ds*.tex`
# DEPENDENCIES:     `fixest`, `shared_reduced_form_helpers.R`
# Review focus:     The substantive estimation logic lives in the shared helper,
#                   so the main thing to verify here is that the outcome name,
#                   display label, and output stub all correspond to Dollar
#                   Stores.
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

# Load the shared benchmark helpers that contain the model formula and output writer.
source(file.path(script_dir, "shared_reduced_form_helpers.R"))
# Delegate the benchmark event study to the helper using the Dollar Stores
# outcome column and the matching output stub.
save_event_study_artifact("total_ds", "Dollar Stores", "3_2_0_1_1_event_study_ihs_total_ds")
