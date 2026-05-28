#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_0_6_2_event_study_chain_super_market.R
# Description:      Thin wrapper that runs the county LPM entry-indicator reduced form for
#                   chain supermarkets using the shared helper script.
# INPUTS:           `2_9_analysis/2_9_9_event_study_sample_lpm_entryindicator.rds`
#                   `2_processed_data/processed_root.txt`
# OUTPUTS:          `3_outputs/3_2_reduced_form/3_2_0_county/3_2_0_6_lpm_entryindicator_regs/3_2_0_6_2_event_study_lpm_chain_super_market_entry*.pdf`
#                   `3_outputs/3_0_tables/3_2_0_county/3_2_0_6_lpm_entryindicator_regs/3_2_0_6_2_event_study_lpm_chain_super_market_entry*.tex`
# DEPENDENCIES:     `fixest`, `shared_reduced_form_helpers.R`
# Review focus:     The shared helper owns the model logic. Review this wrapper
#                   for correct alignment between the supermarket outcome name,
#                   label, and output stub.
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

# Load the shared entry-indicator helpers that contain the model formula and output writer.
source(file.path(script_dir, "shared_reduced_form_helpers.R"))
# Delegate the entry-indicator event study to the helper for the supermarket outcome.
save_event_study_artifact("chain_super_market_entry", "Supermarkets", "3_2_0_6_2_event_study_lpm_chain_super_market_entry")
