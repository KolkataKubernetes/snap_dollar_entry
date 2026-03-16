#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
full_args <- commandArgs(trailingOnly = FALSE)

parse_flag_value <- function(flag, default = NULL) {
  flag_eq <- paste0(flag, "=")

  for (arg in args) {
    if (startsWith(arg, flag_eq)) {
      return(sub(flag_eq, "", arg, fixed = TRUE))
    }
  }

  flag_index <- match(flag, args)
  if (!is.na(flag_index) && flag_index < length(args)) {
    return(args[[flag_index + 1]])
  }

  default
}

has_flag <- function(flag) {
  any(args == flag) || any(startsWith(args, paste0(flag, "=")))
}

print_usage <- function() {
  cat(
    paste(
      "Usage:",
      "  Rscript 1_code/run_refactor_pipeline.R [--stage <stage>] [--dry-run]",
      "",
      "Stages:",
      "  ingest",
      "  descriptives",
      "  reduced_form",
      "  all",
      "",
      "Examples:",
      "  Rscript 1_code/run_refactor_pipeline.R --dry-run",
      "  Rscript 1_code/run_refactor_pipeline.R --stage ingest",
      "  Rscript 1_code/run_refactor_pipeline.R --stage all",
      sep = "\n"
    )
  )
}

if (has_flag("--help") || has_flag("-h")) {
  print_usage()
  quit(save = "no", status = 0)
}

stage <- parse_flag_value("--stage", default = "all")
dry_run <- has_flag("--dry-run")

script_arg <- grep("^--file=", full_args, value = TRUE)
if (!length(script_arg)) {
  stop("Could not determine runner path from commandArgs().")
}

runner_path <- normalizePath(sub("^--file=", "", script_arg[[1]]))
repo_root <- normalizePath(file.path(dirname(runner_path), ".."))
setwd(repo_root)
rscript_bin <- normalizePath(file.path(R.home("bin"), "Rscript"), mustWork = TRUE)

dir.create("3_outputs", recursive = TRUE, showWarnings = FALSE)
dir.create("3_outputs/tables", recursive = TRUE, showWarnings = FALSE)

discover_stage_scripts <- function(stage_dir) {
  if (!dir.exists(stage_dir)) {
    return(character())
  }

  stage_files <- list.files(
    stage_dir,
    pattern = "\\.[Rr]$",
    full.names = FALSE
  )

  stage_files <- stage_files[!grepl("^shared_.*\\.[Rr]$", stage_files)]

  file.path(stage_dir, sort(stage_files))
}

stage_map <- list(
  ingest = discover_stage_scripts("1_code/1_0_ingest"),
  descriptives = discover_stage_scripts("1_code/1_1_descriptives"),
  reduced_form = discover_stage_scripts("1_code/1_2_reduced_form")
)

requested_stages <- if (identical(stage, "all")) {
  names(stage_map)
} else {
  stage
}

invalid_stages <- setdiff(requested_stages, names(stage_map))
if (length(invalid_stages)) {
  stop(
    sprintf(
      "Unknown stage(s): %s. Valid stages are: %s",
      paste(invalid_stages, collapse = ", "),
      paste(c(names(stage_map), "all"), collapse = ", ")
    )
  )
}

scripts_to_run <- unlist(stage_map[requested_stages], use.names = FALSE)

cat(sprintf("Repository root: %s\n", repo_root))
cat(sprintf("Requested stage(s): %s\n", paste(requested_stages, collapse = ", ")))

if (!length(scripts_to_run)) {
  cat("No scripts found for the requested stage(s).\n")
  quit(save = "no", status = 0)
}

cat("Scripts queued:\n")
for (script_path in scripts_to_run) {
  cat(sprintf("  - %s\n", script_path))
}

if (dry_run) {
  cat("Dry run only. No scripts were executed.\n")
  quit(save = "no", status = 0)
}

run_script <- function(script_path) {
  cat(sprintf("\n=== Running %s ===\n", script_path))
  status <- system2(rscript_bin, script_path)

  if (!identical(status, 0L)) {
    stop(sprintf("Script failed with exit code %s: %s", status, script_path))
  }
}

for (script_path in scripts_to_run) {
  run_script(script_path)
}

cat("\nPipeline completed successfully.\n")
