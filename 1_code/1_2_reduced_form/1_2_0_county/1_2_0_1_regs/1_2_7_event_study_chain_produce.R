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

current_reduced_form_subdir <- c("3_2_0_county", "3_2_0_1_regs")
source(file.path(script_dir, "1_2_reduced_form", "1_2_0_county", "shared_reduced_form_helpers.R"))
save_event_study_artifact("chain_produce", "Produce", "3_2_7_event_study_ihs_chain_produce")
