library(dplyr)
library(stringr)
library(fixest)

get_repo_root <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)

  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[[1]]))
    return(normalizePath(file.path(dirname(script_path), "..", "..")))
  }

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    script_path <- rstudioapi::getActiveDocumentContext()$path
    return(normalizePath(file.path(dirname(script_path), "..", "..")))
  }

  normalizePath(getwd())
}

read_root_path <- function(path_file) {
  readLines(path_file, warn = FALSE)[[1]] |>
    str_trim() |>
    str_remove_all("^['\"]|['\"]$")
}

ensure_reduced_form_dirs <- function() {
  dir.create(file.path("3_outputs", "3_2_reduced_form"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path("3_outputs", "tables"), recursive = TRUE, showWarnings = FALSE)
}

reduced_form_plot_path <- function(filename) {
  ensure_reduced_form_dirs()
  file.path("3_outputs", "3_2_reduced_form", filename)
}

reduced_form_table_path <- function(filename) {
  ensure_reduced_form_dirs()
  file.path("3_outputs", "tables", filename)
}

load_event_study_sample <- function() {
  repo_root <- get_repo_root()
  setwd(repo_root)

  processed_root <- read_root_path("2_processed_data/processed_root.txt")
  readRDS(file.path(processed_root, "2_9_analysis", "2_9_2_event_study_sample.rds"))
}

event_study_outcomes <- c(
  "total_ds",
  "chain_super_market",
  "chain_convenience_store",
  "chain_multi_category",
  "chain_medium_grocery",
  "chain_small_grocery",
  "chain_produce",
  "chain_farmers_market"
)

event_study_labels <- c(
  "Dollar Stores",
  "Supermarkets",
  "Convenience Stores",
  "Multi Category",
  "Medium Grocery",
  "Small Grocery",
  "Produce",
  "Farmers Market"
)

names(event_study_labels) <- event_study_outcomes

run_event_study_model <- function(var_name) {
  aba1 <- load_event_study_sample()

  feols(
    as.formula(
      paste0(
        "log(",
        var_name,
        " + sqrt(",
        var_name,
        "^2 + 1)) ~ ",
        "sunab(eventYear2, year, ref.p = 0) + ",
        "population + wage + meanInc + rent + urate | county_fips + year"
      )
    ),
    data = aba1
  )
}

save_event_study_artifact <- function(var_name, label, file_stub) {
  model <- run_event_study_model(var_name)

  pdf(reduced_form_plot_path(paste0(file_stub, ".pdf")), width = 8, height = 6)
  iplot(model, sep = 0.2, main = "", pt.join = TRUE)
  title(paste0("IHS(", label, ")"))
  dev.off()

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
