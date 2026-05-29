library(stringr)

get_script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)

  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]])))
  }

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    script_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(script_path)) {
      return(normalizePath(script_path))
    }
  }

  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) {
      return(normalizePath(frame$ofile))
    }
  }

  NA_character_
}

find_repo_root <- function(start_path) {
  candidate <- normalizePath(start_path, winslash = "/", mustWork = FALSE)

  if (!dir.exists(candidate)) {
    candidate <- dirname(candidate)
  }

  repeat {
    if (file.exists(file.path(candidate, "AGENTS.md")) && dir.exists(file.path(candidate, "1_code"))) {
      return(candidate)
    }

    parent <- dirname(candidate)
    if (identical(parent, candidate)) {
      stop(sprintf("Could not locate repository root from '%s'.", start_path))
    }

    candidate <- parent
  }
}

get_repo_root <- function() {
  script_path <- get_script_path()
  start_path <- if (!is.na(script_path)) script_path else getwd()
  find_repo_root(start_path)
}

read_root_path <- function(path_file) {
  readLines(path_file, warn = FALSE)[[1]] |>
    str_trim() |>
    str_remove_all("^['\"]|['\"]$")
}

read_root_path_candidates <- function(path_file) {
  readLines(path_file, warn = FALSE) |>
    str_trim() |>
    str_remove_all("^['\"]|['\"]$") |>
    (\(x) x[nzchar(x)])()
}

select_root_candidate <- function(candidates) {
  if (!length(candidates)) {
    return(NA_character_)
  }

  existing_candidates <- candidates[dir.exists(candidates)]
  candidate_pool <- if (length(existing_candidates)) existing_candidates else candidates

  if (.Platform$OS.type == "windows") {
    windows_candidates <- candidate_pool[grepl("^[A-Za-z]:[\\\\/]", candidate_pool)]
    if (length(windows_candidates)) {
      return(windows_candidates[[1]])
    }
  }

  unix_candidates <- candidate_pool[grepl("^/", candidate_pool)]
  if (length(unix_candidates)) {
    return(unix_candidates[[1]])
  }

  candidate_pool[[1]]
}

build_sibling_root <- function(reference_root, sibling_name) {
  normalized_root <- gsub("[/\\\\]+$", "", reference_root)
  file.path(dirname(normalized_root), sibling_name)
}

resolve_input_root <- function(path_file = "0_inputs/input_root.txt") {
  candidates <- read_root_path_candidates(path_file)

  if (!length(candidates)) {
    stop(sprintf("No input root candidates found in '%s'.", path_file))
  }

  select_root_candidate(candidates)
}

resolve_processed_root <- function(
  path_file = "2_processed_data/processed_root.txt",
  input_path_file = "0_inputs/input_root.txt"
) {
  candidates <- read_root_path_candidates(path_file)
  selected_candidate <- select_root_candidate(candidates)

  if (!is.na(selected_candidate) && dir.exists(selected_candidate)) {
    return(selected_candidate)
  }

  sibling_candidate <- build_sibling_root(resolve_input_root(input_path_file), "2_processed_data")

  if (dir.exists(sibling_candidate)) {
    return(sibling_candidate)
  }

  if (!is.na(selected_candidate)) {
    return(selected_candidate)
  }

  sibling_candidate
}

normalize_fips <- function(x) {
  digits <- stringr::str_extract(as.character(x), "\\d+")
  digits <- ifelse(is.na(digits) | digits == "", NA_character_, digits)
  ifelse(is.na(digits), NA_character_, stringr::str_pad(digits, width = 5, side = "left", pad = "0"))
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}
