library(dplyr)
library(data.table)

# ==============================================================================
# Setup: script directory & helpers
# ==============================================================================

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- rstudioapi::getActiveDocumentContext()$path
    if (nzchar(active_path)) return(dirname(normalizePath(active_path)))
  }
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) return(dirname(normalizePath(frame$ofile)))
  }
  
  normalizePath(getwd())
})

current_descriptive_subdir <- "3_1_2_manuscript_tables"

helpers_path <- file.path(script_dir, "1_1_descriptives", "shared_us_analysis_helpers.R")
if (!file.exists(helpers_path)) {
  helpers_path <- file.path(dirname(script_dir), "shared_us_analysis_helpers.R")
}
source(helpers_path)

repo_root     <- get_repo_root()
setwd(repo_root)
processed_root <- file.path(box_root, "data/2_processed_data/2_9_analysis")

# ==============================================================================
# Load data
# ==============================================================================

data  <- readRDS(file.path(processed_root, "2_9_2_event_study_sample.rds")) |> data.table()

panel <- readRDS(file.path(processed_root, "2_9_0_us_analysis_panel.rds")) |>
  mutate(sometime_treated = !is.na(eventYear2)) |>
  data.table() |>
  filter(year %in% 2014:2019)

# ==============================================================================
# Variable definitions
# ==============================================================================

control_vars <- c(
  "population", "wage", "meanInc", "rent", "urate"
)

outcome_vars <- c(
  "total_ds", "chain_super_market", "chain_convenience_store",
  "chain_multi_category", "chain_medium_grocery", "chain_small_grocery",
  "chain_produce", "chain_farmers_market"
)


var_labels <- c(
  population             = "Population",
  wage                   = "Wage",
  meanInc                = "Mean Income",
  rent                   = "Rent",
  urate                  = "Unemployment Rate",
  total_ds               = "Entering Dollar Stores",
  chain_super_market     = "Entering Supermarkets",
  chain_convenience_store = "Entering Convenience Stores",
  chain_multi_category   = "Entering Multi-Category",
  chain_medium_grocery   = "Entering Medium Grocery",
  chain_small_grocery    = "Entering Small Grocery",
  chain_produce          = "Entering Produce",
  chain_farmers_market   = "Entering Farmers Markets"
)

# ==============================================================================
# Split panel into treatment groups
# ==============================================================================

treated_df <- panel |> filter(sometime_treated)
control_df <- panel |> filter(!sometime_treated)

# ==============================================================================
# Helper functions
# ==============================================================================

fmt <- function(x, digits = 2) {
  formatC(x, format = "f", digits = digits, big.mark = ",")
}

sig_stars <- function(p) {
  if (is.na(p))  return("")
  if (p <= 0.01) return("$^{***}$")
  if (p <= 0.05) return("$^{**}$")
  if (p <= 0.10) return("$^{*}$")
  ""
}

build_row <- function(v) {
  t_mean <- mean(treated_df[[v]], na.rm = TRUE)
  t_sd   <- sd(treated_df[[v]],   na.rm = TRUE)
  c_mean <- mean(control_df[[v]], na.rm = TRUE)
  c_sd   <- sd(control_df[[v]],   na.rm = TRUE)
  f_mean <- mean(panel[[v]],      na.rm = TRUE)
  f_sd   <- sd(panel[[v]],        na.rm = TRUE)
  
  p_val <- tryCatch(
    t.test(treated_df[[v]], control_df[[v]])$p.value,
    error = function(e) NA_real_
  )
  
  sprintf(
    "\\quad %s & %s & %s & %s & %s & %s & %s & %s%s \\\\",
    var_labels[[v]],
    fmt(t_mean), fmt(t_sd),
    fmt(c_mean), fmt(c_sd),
    fmt(f_mean), fmt(f_sd),
    fmt(t_mean - c_mean), sig_stars(p_val)
  )
}

# ==============================================================================
# Summary counts
# ==============================================================================

n_treated  <- nrow(treated_df);          n_control  <- nrow(control_df);          n_full  <- nrow(panel)
nc_treated <- n_distinct(treated_df$county_fips)
nc_control <- n_distinct(control_df$county_fips)
nc_full    <- n_distinct(panel$county_fips)

# ==============================================================================
# Build LaTeX table
# ==============================================================================

control_rows         <- vapply(control_vars, build_row, character(1))
control_rows[length(control_rows)] <- sub("\\\\\\\\$", "\\\\\\\\[0.3em]", control_rows[length(control_rows)])
outcome_rows         <- vapply(outcome_vars,  build_row, character(1))

fmt_n <- function(n) formatC(n, big.mark = ",")

tex_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Descriptive Statistics by Treatment Status}",
  "\\label{tab:desc_stats}",
  "\\resizebox{\\textwidth}{!}{",
  "\\begin{tabular}{l cc cc cc c}",
  "\\hline\\hline",
  paste(
    " & \\multicolumn{2}{c}{(1) Sometime-Treated}",
    "& \\multicolumn{2}{c}{(2) Never-Treated}",
    "& \\multicolumn{2}{c}{(3) Full Sample} & \\\\"
  ),
  " & Mean & SD & Mean & SD & Mean & SD & (1)$-$(2) \\\\",
  "\\hline",
  "\\textit{Panel A: Controls} \\\\",
  control_rows,
  "\\textit{Panel B: Outcomes} \\\\",
  outcome_rows,
  "\\hline",
  sprintf(
    "County-years & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} & \\\\",
    fmt_n(n_treated), fmt_n(n_control), fmt_n(n_full)
  ),
  sprintf(
    "Counties & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} & \\\\",
    fmt_n(nc_treated), fmt_n(nc_control), fmt_n(nc_full)
  ),
  "\\hline\\hline",
  "\\multicolumn{8}{l}{\\footnotesize $^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.1$. Difference reports treated minus control mean.} \\\\",
  "\\end{tabular}",
  "}",
  "\\end{table}"
)

# ==============================================================================
# Write output
# ==============================================================================

writeLines(tex_lines, descriptive_output_path("3_1_2_0_descriptive_stats.tex"))