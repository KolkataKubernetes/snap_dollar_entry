library(stringr)

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

normalize_fips <- function(x) {
  digits <- stringr::str_extract(as.character(x), "\\d+")
  digits <- ifelse(is.na(digits) | digits == "", NA_character_, digits)
  ifelse(is.na(digits), NA_character_, stringr::str_pad(digits, width = 5, side = "left", pad = "0"))
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}
