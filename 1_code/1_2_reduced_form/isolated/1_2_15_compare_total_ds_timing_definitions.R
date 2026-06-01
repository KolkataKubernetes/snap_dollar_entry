#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_2_15_compare_total_ds_timing_definitions.R
# Description:      Compare the benchmark annual any-month treatment timing
#                   definition against a half-year rollover alternative that
#                   shifts spell onsets in July-December into the following
#                   calendar year.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `2_0_waivers/2_0_4_waived_data_consolidated_long.rds`
#                   `2_9_analysis/2_9_0_us_analysis_panel.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
# OUTPUTS:          `3_outputs/3_2_reduced_form/isolated/3_2_15_event_study_total_ds_timing_comparison*.pdf`
#                   `3_outputs/3_0_tables/isolated/3_2_15_event_study_total_ds_timing_comparison*.csv`
# DEPENDENCIES:     `dplyr`, `tidyr`, `ggplot2`, `fixest`, `lubridate`,
#                   `reticulate`, `stringr`
# Review focus:     Verify the spell-to-annual treatment conversion under the
#                   rollover rule, the benchmark-identical sample restrictions,
#                   and the side-by-side comparison outputs for the core county
#                   reduced-form specifications.
#///////////////////////////////////////////////////////////////////////////////

library(dplyr)
library(tidyr)
library(ggplot2)
library(fixest)
library(lubridate)
library(reticulate)
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

next_available_path <- function(path) {
  if (!file.exists(path)) {
    return(path)
  }

  base <- tools::file_path_sans_ext(path)
  ext <- tools::file_ext(path)
  index <- 1
  candidate <- sprintf("%s_v%02d.%s", base, index, ext)

  while (file.exists(candidate)) {
    index <- index + 1
    candidate <- sprintf("%s_v%02d.%s", base, index, ext)
  }

  candidate
}

theme_im <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(linewidth = 0.3),
      panel.grid.major.y = element_line(linewidth = 0.3),
      legend.position = "top",
      legend.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold"),
      strip.text = element_text(face = "bold"),
      axis.title = element_text(face = "bold")
    )
}

normalize_results_df <- function(df) {
  if ("conf_int" %in% names(df)) {
    conf_low <- vapply(df$conf_int, function(x) x[[1]], numeric(1))
    conf_high <- vapply(df$conf_int, function(x) x[[2]], numeric(1))
    df$conf_int_lo <- conf_low
    df$conf_int_hi <- conf_high
    df$conf_int <- NULL
  }

  for (column_name in names(df)) {
    if (is.list(df[[column_name]])) {
      element_lengths <- vapply(df[[column_name]], length, integer(1))
      if (length(element_lengths) == 0 || all(element_lengths %in% c(0L, 1L))) {
        df[[column_name]] <- vapply(df[[column_name]], function(x) {
          if (length(x) == 0) {
            return(NA_character_)
          }

          as.character(x[[1]])
        }, character(1))
      }
    }
  }

  df
}

sanitize_effect_df <- function(df) {
  required_cols <- intersect(c("att", "se", "t_stat", "p_value", "conf_int_lo", "conf_int_hi"), names(df))

  if (length(required_cols) == 0) {
    return(df)
  }

  bad_row <- rep(FALSE, nrow(df))

  if ("att" %in% names(df)) {
    bad_row <- bad_row | !is.finite(df$att)
  }

  if ("se" %in% names(df)) {
    bad_row <- bad_row | !is.finite(df$se) | df$se < 0
  }

  if ("p_value" %in% names(df)) {
    bad_row <- bad_row | is.na(df$p_value)
  }

  if ("conf_int_lo" %in% names(df) && "conf_int_hi" %in% names(df)) {
    bad_row <- bad_row | !is.finite(df$conf_int_lo) | !is.finite(df$conf_int_hi)
  }

  for (column_name in required_cols) {
    df[[column_name]][bad_row] <- NA_real_
  }

  df
}

ensure_columns <- function(df, columns, fill_value = 0L) {
  missing_cols <- setdiff(columns, names(df))

  if (length(missing_cols)) {
    df[missing_cols] <- fill_value
  }

  df
}

repo_root <- get_repo_root()
setwd(repo_root)

processed_root <- read_root_path("2_processed_data/processed_root.txt")

plot_dir <- file.path("3_outputs", "3_2_reduced_form", "isolated")
table_dir <- file.path("3_outputs", "3_0_tables", "isolated")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

waiver_long <- readRDS(file.path(processed_root, "2_0_waivers", "2_0_4_waived_data_consolidated_long.rds"))
analysis_panel_current <- readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))
store_count <- readRDS(file.path(processed_root, "2_5_SNAP", "2_5_1_store_count.rds"))

supermarket_chains <- c(
  "chain_ingles_markets",
  "chain_winn-dixie",
  "chain_stop_&_shop",
  "chain_albertsons",
  "chain_fred_meyer",
  "chain_trader_joes",
  "chain_trader_joe_s",
  "chain_whole_foods",
  "chain_save_a_lot",
  "chain_aldi",
  "chain_save_mart",
  "chain_safeway",
  "chain_kroger",
  "chain_giant_food",
  "chain_weis_markets",
  "chain_publix",
  "chain_supervalu",
  "chain_raleys",
  "chain_raley_s",
  "chain_smart_&_final",
  "chain_wild_oats",
  "chain_meijer",
  "chain_giant_eagle",
  "chain_he_butt",
  "chain_stater_bros",
  "chain_roundys",
  "chain_roundy_s"
)

club_store_chains <- c("chain_costco", "chain_sams_club", "chain_sam_s_club", "chain_bjs")
convenience_chains <- c("chain_seven_eleven", "chain_circle_k", "chain_speedway")
multi_category_chains <- c("chain_wal-mart", "chain_target")

stock_outcome_columns <- c(
  "chain_dollar_general_stock",
  "chain_dollar_tree_stock",
  "chain_family_dollar_stock",
  "chain_super_market_stock",
  "chain_convenience_store_stock",
  "chain_multi_category_stock",
  "chain_medium_grocery_stock",
  "chain_small_grocery_stock",
  "chain_produce_stock",
  "chain_farmers_market_stock",
  "total_ds_stock"
)

build_shifted_treatment_years <- function(waiver_long_df) {
  waiver_county_fips <- if ("FIPS" %in% names(waiver_long_df)) {
    waiver_long_df$FIPS
  } else if ("county_fips" %in% names(waiver_long_df)) {
    waiver_long_df$county_fips
  } else {
    stop("Selected waiver panel is missing both `FIPS` and `county_fips`.")
  }

  waiver_month <- if ("MONTH_DATE" %in% names(waiver_long_df)) {
    waiver_long_df$MONTH_DATE
  } else {
    stop("Selected waiver panel is missing `MONTH_DATE`.")
  }

  county_month <- waiver_long_df |>
    transmute(
      county_fips = as.integer(waiver_county_fips),
      month_date = floor_date(as.Date(waiver_month), unit = "month")
    ) |>
    filter(!is.na(county_fips), !is.na(month_date)) |>
    distinct() |>
    arrange(county_fips, month_date)

  spell_bounds <- county_month |>
    group_by(county_fips) |>
    mutate(
      prev_month = lag(month_date),
      new_spell = is.na(prev_month) | month_date != (prev_month %m+% months(1L)),
      spell_id = cumsum(new_spell)
    ) |>
    group_by(county_fips, spell_id) |>
    summarise(
      spell_start = min(month_date),
      spell_end = max(month_date),
      .groups = "drop"
    ) |>
    mutate(
      spell_start_month = month(spell_start),
      treatment_start_year = year(spell_start) + if_else(spell_start_month >= 7L, 1L, 0L),
      treatment_end_year = year(spell_end)
    )

  annual_treatment_years <- spell_bounds |>
    filter(treatment_start_year <= treatment_end_year) |>
    mutate(n_years = treatment_end_year - treatment_start_year + 1L) |>
    uncount(n_years) |>
    group_by(county_fips, spell_id) |>
    mutate(year = treatment_start_year + row_number() - 1L) |>
    ungroup() |>
    distinct(county_fips, year)

  first_treated_year_2014 <- annual_treatment_years |>
    filter(year >= 2014) |>
    group_by(county_fips) |>
    summarise(eventYear2_shifted = min(year), .groups = "drop")

  list(
    spell_bounds = spell_bounds,
    annual_treatment_years = annual_treatment_years,
    first_treated_year_2014 = first_treated_year_2014
  )
}

shifted_timing <- build_shifted_treatment_years(waiver_long)

build_timing_panel <- function(panel_df, timing_definition, shifted_event_years) {
  if (identical(timing_definition, "current_any_month")) {
    return(
      panel_df |>
        mutate(
          timing_definition = timing_definition,
          eventYear2_current = as.integer(eventYear2),
          eventYear2_alt = as.integer(NA)
        )
    )
  }

  panel_df |>
    left_join(shifted_event_years, by = "county_fips") |>
    mutate(
      timing_definition = timing_definition,
      eventYear2_current = as.integer(eventYear2),
      eventYear2_alt = eventYear2_shifted,
      eventYear2 = eventYear2_shifted,
      tau2 = year - eventYear2,
      treated = !is.na(eventYear2)
    ) |>
    select(-eventYear2_shifted)
}

build_benchmark_sample <- function(panel_df) {
  panel_df |>
    mutate(
      lowq = total_ds + chain_convenience_store,
      rent = rent / 1000,
      meanInc = meanInc / 1000,
      zl = dplyr::lag(urate),
      z = urate,
      no_stores = (total_ds + chain_super_market + chain_convenience_store + chain_multi_category) == 0,
      state_fips = county_fips %/% 1000
    ) |>
    filter(year %in% 2014:2019) |>
    mutate(
      tau2 = if_else(is.na(tau2), -1000, tau2),
      eventYear2 = if_else(is.na(eventYear2), 10000L, as.integer(eventYear2)),
      treated_group = eventYear2 != 10000L
    ) |>
    group_by(state_fips) |>
    mutate(treated_state = sum(treated_group) > 0) |>
    group_by(county_fips) |>
    mutate(treated_county = sum(treated_group) > 0) |>
    ungroup() |>
    filter(year - eventYear2 >= -3, treated_state, treated_county) |>
    mutate(state_year = paste(state, year))
}

build_stock_panel <- function(panel_df, store_count_df) {
  stock_panel <- store_count_df |>
    transmute(
      county_fips = as.integer(county_fips),
      year = as.integer(year),
      chain = as.character(chain),
      count = as.integer(count)
    ) |>
    mutate(
      chain = case_when(
        chain %in% supermarket_chains ~ "chain_super_market",
        chain %in% club_store_chains ~ "chain_club_store",
        chain %in% convenience_chains ~ "chain_convenience_store",
        chain %in% multi_category_chains ~ "chain_multi_category",
        TRUE ~ chain
      )
    ) |>
    filter(
      chain %in% c(
        "chain_dollar_general",
        "chain_dollar_tree",
        "chain_family_dollar",
        "chain_super_market",
        "chain_convenience_store",
        "chain_multi_category",
        "chain_medium_grocery",
        "chain_small_grocery",
        "chain_produce",
        "chain_farmers_market"
      )
    ) |>
    group_by(county_fips, year, chain) |>
    summarise(count = sum(count, na.rm = TRUE), .groups = "drop") |>
    mutate(chain = paste0(chain, "_stock")) |>
    pivot_wider(names_from = chain, values_from = count, values_fill = 0) |>
    ensure_columns(stock_outcome_columns, fill_value = 0L) |>
    mutate(
      total_ds_stock = chain_dollar_general_stock + chain_dollar_tree_stock + chain_family_dollar_stock
    )

  panel_df |>
    select(county_fips, year) |>
    distinct() |>
    left_join(stock_panel, by = c("county_fips", "year")) |>
    mutate(across(any_of(stock_outcome_columns), ~ coalesce(.x, 0L)))
}

build_stock_sample <- function(panel_df, store_count_df) {
  stock_panel <- build_stock_panel(panel_df, store_count_df)

  panel_df |>
    select(-any_of(stock_outcome_columns)) |>
    left_join(stock_panel, by = c("county_fips", "year")) |>
    mutate(
      lowq = total_ds_stock + chain_convenience_store_stock,
      rent = rent / 1000,
      meanInc = meanInc / 1000,
      zl = dplyr::lag(urate),
      z = urate,
      no_stores = (
        total_ds_stock +
          chain_super_market_stock +
          chain_convenience_store_stock +
          chain_multi_category_stock
      ) == 0,
      state_fips = county_fips %/% 1000
    ) |>
    filter(year %in% 2014:2019) |>
    mutate(
      tau2 = if_else(is.na(tau2), -1000, tau2),
      eventYear2 = if_else(is.na(eventYear2), 10000L, as.integer(eventYear2)),
      treated_group = eventYear2 != 10000L
    ) |>
    group_by(state_fips) |>
    mutate(treated_state = sum(treated_group) > 0) |>
    group_by(county_fips) |>
    mutate(treated_county = sum(treated_group) > 0) |>
    ungroup() |>
    filter(year - eventYear2 >= -3, treated_state, treated_county) |>
    mutate(state_year = paste(state, year))
}

build_lpm_sample <- function(panel_df) {
  build_benchmark_sample(panel_df) |>
    mutate(
      total_ds_entry = as.integer(total_ds > 0),
      chain_super_market_entry = as.integer(chain_super_market > 0),
      chain_convenience_store_entry = as.integer(chain_convenience_store > 0),
      chain_multi_category_entry = as.integer(chain_multi_category > 0),
      chain_medium_grocery_entry = as.integer(chain_medium_grocery > 0),
      chain_small_grocery_entry = as.integer(chain_small_grocery > 0),
      chain_produce_entry = as.integer(chain_produce > 0),
      chain_farmers_market_entry = as.integer(chain_farmers_market > 0)
    )
}

build_poisson_sample <- function(panel_df, store_count_df) {
  stock_panel <- build_stock_panel(panel_df, store_count_df)

  panel_df |>
    select(-any_of(stock_outcome_columns)) |>
    left_join(stock_panel, by = c("county_fips", "year")) |>
    mutate(
      rent = rent / 1000,
      meanInc = meanInc / 1000
    ) |>
    filter(year %in% 2013:2019) |>
    mutate(
      g_first_treat = if_else(is.na(eventYear2), 0L, as.integer(eventYear2)),
      treated_group = g_first_treat > 0L
    ) |>
    filter(g_first_treat == 0L | year - g_first_treat >= -3) |>
    filter(is.finite(g_first_treat), g_first_treat >= 0L)
}

extract_fixest_event_profile <- function(model, timing_definition, specification) {
  event_coeftable <- as.data.frame(coeftable(model))
  event_coeftable$term <- rownames(event_coeftable)
  rownames(event_coeftable) <- NULL

  event_confint <- as.data.frame(confint(model))
  event_confint$term <- rownames(event_confint)
  rownames(event_confint) <- NULL
  names(event_confint)[1:2] <- c("conf_low", "conf_high")

  event_coeftable |>
    filter(grepl("^year::", term)) |>
    left_join(event_confint, by = "term") |>
    transmute(
      specification = specification,
      timing_definition = timing_definition,
      event_time = as.integer(sub("^year::", "", term)),
      estimate = Estimate,
      std_error = `Std. Error`,
      p_value = `Pr(>|t|)`,
      conf_low = conf_low,
      conf_high = conf_high
    ) |>
    arrange(event_time)
}

extract_fixest_att <- function(model, timing_definition, specification) {
  att_matrix <- aggregate(model, agg = "att")

  tibble(
    specification = specification,
    timing_definition = timing_definition,
    estimate = as.numeric(att_matrix[1, "Estimate"]),
    std_error = as.numeric(att_matrix[1, "Std. Error"]),
    p_value = as.numeric(att_matrix[1, "Pr(>|t|)"]),
    conf_low = estimate - 1.96 * std_error,
    conf_high = estimate + 1.96 * std_error
  )
}

configure_diff_diff <- function() {
  python_path_override <- Sys.getenv("SNAP_DOLLAR_ENTRY_PYTHON", unset = "")
  local_python <- file.path(repo_root, ".venv-diffdiff-arm", "bin", "python")

  if (nzchar(python_path_override)) {
    reticulate::use_python(python_path_override, required = TRUE)
    return(invisible(NULL))
  }

  if (file.exists(local_python)) {
    reticulate::use_python(local_python, required = TRUE)
    return(invisible(NULL))
  }

  stop(
    paste0(
      "No compatible Python interpreter was found for diff-diff. ",
      "Set SNAP_DOLLAR_ENTRY_PYTHON to an arm64 interpreter with diff-diff ",
      "installed, or create the repo-local environment at ",
      local_python,
      "."
    )
  )
}

get_diff_diff_module <- local({
  diff_diff_module <- NULL

  function() {
    if (is.null(diff_diff_module)) {
      configure_diff_diff()
      diff_diff_module <<- reticulate::import("diff_diff", delay_load = FALSE)
    }

    diff_diff_module
  }
})

fit_poisson_model <- function(sample_df) {
  diff_diff <- get_diff_diff_module()

  model_frame <- sample_df |>
    transmute(
      county_fips = county_fips,
      year = year,
      g_first_treat = as.integer(g_first_treat),
      outcome = total_ds_stock,
      population = population,
      wage = wage,
      meanInc = meanInc,
      rent = rent,
      urate = urate
    ) |>
    filter(
      is.finite(g_first_treat),
      g_first_treat >= 0L,
      is.finite(outcome),
      outcome >= 0,
      if_all(all_of(c("population", "wage", "meanInc", "rent", "urate")), is.finite)
    )

  estimator <- diff_diff$WooldridgeDiD(
    method = "poisson",
    control_group = "never_treated",
    cluster = "county_fips",
    alpha = 0.05
  )

  results <- estimator$fit(
    data = model_frame,
    outcome = "outcome",
    unit = "county_fips",
    time = "year",
    cohort = "g_first_treat",
    xtvar = c("population", "wage", "meanInc", "rent", "urate")
  )

  list(estimator = estimator, results = results, model_frame = model_frame)
}

extract_poisson_outputs <- function(model_bundle, timing_definition, specification) {
  results <- model_bundle$results

  results$aggregate("event")
  event_df <- sanitize_effect_df(normalize_results_df(reticulate::py_to_r(results$to_dataframe("event"))))
  simple_df <- sanitize_effect_df(normalize_results_df(reticulate::py_to_r(results$to_dataframe("simple"))))

  event_profile <- event_df |>
    transmute(
      specification = specification,
      timing_definition = timing_definition,
      event_time = as.integer(relative_period),
      estimate = att,
      std_error = se,
      p_value = p_value,
      conf_low = conf_int_lo,
      conf_high = conf_int_hi
    ) |>
    arrange(event_time)

  att_summary <- tibble(
    specification = specification,
    timing_definition = timing_definition,
    estimate = simple_df$att[[1]],
    std_error = simple_df$se[[1]],
    p_value = simple_df$p_value[[1]],
    conf_low = simple_df$conf_int_lo[[1]],
    conf_high = simple_df$conf_int_hi[[1]]
  )

  list(event_profile = event_profile, att_summary = att_summary)
}

fit_specifications <- function(panel_df, timing_definition) {
  benchmark_sample <- build_benchmark_sample(panel_df)
  lpm_sample <- build_lpm_sample(panel_df)
  stock_sample <- build_stock_sample(panel_df, store_count)
  poisson_sample <- build_poisson_sample(panel_df, store_count)

  ihs_model <- feols(
    log(total_ds + sqrt(total_ds^2 + 1)) ~
      sunab(eventYear2, year, ref.p = -1) +
      population + wage + meanInc + rent + urate |
      county_fips + year,
    data = benchmark_sample,
    cluster = ~county_fips
  )

  stock_model <- feols(
    log(total_ds_stock + sqrt(total_ds_stock^2 + 1)) ~
      sunab(eventYear2, year, ref.p = -1) +
      population + wage + meanInc + rent + urate |
      county_fips + year,
    data = stock_sample,
    cluster = ~county_fips
  )

  lpm_model <- feols(
    total_ds_entry ~
      sunab(eventYear2, year, ref.p = -1) +
      population + wage + meanInc + rent + urate |
      county_fips + year,
    data = lpm_sample,
    cluster = ~county_fips
  )

  poisson_model <- fit_poisson_model(poisson_sample)

  event_profiles <- bind_rows(
    extract_fixest_event_profile(ihs_model, timing_definition, "IHS total_ds"),
    extract_fixest_event_profile(stock_model, timing_definition, "IHS total_ds_stock"),
    extract_fixest_event_profile(lpm_model, timing_definition, "LPM total_ds_entry"),
    extract_poisson_outputs(poisson_model, timing_definition, "Poisson total_ds_stock")$event_profile
  )

  att_summaries <- bind_rows(
    extract_fixest_att(ihs_model, timing_definition, "IHS total_ds"),
    extract_fixest_att(stock_model, timing_definition, "IHS total_ds_stock"),
    extract_fixest_att(lpm_model, timing_definition, "LPM total_ds_entry"),
    extract_poisson_outputs(poisson_model, timing_definition, "Poisson total_ds_stock")$att_summary
  )

  sample_summaries <- bind_rows(
    tibble(
      specification = "IHS total_ds",
      timing_definition = timing_definition,
      n_obs = nrow(benchmark_sample),
      n_counties = n_distinct(benchmark_sample$county_fips),
      n_states = n_distinct(benchmark_sample$state_fips),
      n_treated_counties = n_distinct(benchmark_sample$county_fips[benchmark_sample$eventYear2 != 10000L]),
      min_event_year = min(benchmark_sample$eventYear2[benchmark_sample$eventYear2 != 10000L]),
      max_event_year = max(benchmark_sample$eventYear2[benchmark_sample$eventYear2 != 10000L])
    ),
    tibble(
      specification = "IHS total_ds_stock",
      timing_definition = timing_definition,
      n_obs = nrow(stock_sample),
      n_counties = n_distinct(stock_sample$county_fips),
      n_states = n_distinct(stock_sample$state_fips),
      n_treated_counties = n_distinct(stock_sample$county_fips[stock_sample$eventYear2 != 10000L]),
      min_event_year = min(stock_sample$eventYear2[stock_sample$eventYear2 != 10000L]),
      max_event_year = max(stock_sample$eventYear2[stock_sample$eventYear2 != 10000L])
    ),
    tibble(
      specification = "LPM total_ds_entry",
      timing_definition = timing_definition,
      n_obs = nrow(lpm_sample),
      n_counties = n_distinct(lpm_sample$county_fips),
      n_states = n_distinct(lpm_sample$state_fips),
      n_treated_counties = n_distinct(lpm_sample$county_fips[lpm_sample$eventYear2 != 10000L]),
      min_event_year = min(lpm_sample$eventYear2[lpm_sample$eventYear2 != 10000L]),
      max_event_year = max(lpm_sample$eventYear2[lpm_sample$eventYear2 != 10000L])
    ),
    tibble(
      specification = "Poisson total_ds_stock",
      timing_definition = timing_definition,
      n_obs = nrow(poisson_sample),
      n_counties = n_distinct(poisson_sample$county_fips),
      n_states = NA_integer_,
      n_treated_counties = n_distinct(poisson_sample$county_fips[poisson_sample$g_first_treat > 0L]),
      min_event_year = min(poisson_sample$g_first_treat[poisson_sample$g_first_treat > 0L]),
      max_event_year = max(poisson_sample$g_first_treat[poisson_sample$g_first_treat > 0L])
    )
  )

  list(
    event_profiles = event_profiles,
    att_summaries = att_summaries,
    sample_summaries = sample_summaries
  )
}

timing_panels <- list(
  current_any_month = build_timing_panel(
    analysis_panel_current,
    "current_any_month",
    shifted_timing$first_treated_year_2014
  ),
  half_year_rollover = build_timing_panel(
    analysis_panel_current,
    "half_year_rollover",
    shifted_timing$first_treated_year_2014
  )
)

comparison_results <- lapply(names(timing_panels), function(timing_definition) {
  fit_specifications(timing_panels[[timing_definition]], timing_definition)
})
names(comparison_results) <- names(timing_panels)

event_profiles <- bind_rows(lapply(comparison_results, `[[`, "event_profiles"))
att_summaries <- bind_rows(lapply(comparison_results, `[[`, "att_summaries"))
sample_summaries <- bind_rows(lapply(comparison_results, `[[`, "sample_summaries"))

current_cohorts <- analysis_panel_current |>
  distinct(county_fips, eventYear2) |>
  rename(eventYear2_current = eventYear2)

shifted_cohorts <- shifted_timing$first_treated_year_2014 |>
  rename(eventYear2_alt = eventYear2_shifted)

first_spell_diagnostics <- shifted_timing$spell_bounds |>
  group_by(county_fips) |>
  slice_min(spell_start, n = 1, with_ties = FALSE) |>
  ungroup() |>
  transmute(
    county_fips,
    first_spell_start = spell_start,
    first_spell_start_month = spell_start_month,
    first_spell_end = spell_end,
    first_spell_rollover_year = treatment_start_year
  )

cohort_shift_summary <- current_cohorts |>
  left_join(shifted_cohorts, by = "county_fips") |>
  left_join(first_spell_diagnostics, by = "county_fips") |>
  mutate(
    shift_years = eventYear2_alt - eventYear2_current,
    shift_status = case_when(
      is.na(eventYear2_current) & is.na(eventYear2_alt) ~ "never_treated_both",
      is.na(eventYear2_current) & !is.na(eventYear2_alt) ~ "treated_alt_only",
      !is.na(eventYear2_current) & is.na(eventYear2_alt) ~ "treated_current_only",
      shift_years == 0 ~ "unchanged",
      shift_years > 0 ~ "shifted_later",
      shift_years < 0 ~ "shifted_earlier"
    )
  )

shift_distribution <- cohort_shift_summary |>
  count(shift_status, shift_years, sort = TRUE)

selected_event_times <- c(-3L, -2L, 0L, 1L, 2L, 3L, 4L, 5L)

selected_effects <- event_profiles |>
  filter(event_time %in% selected_event_times) |>
  arrange(specification, timing_definition, event_time)

att_wide <- att_summaries |>
  select(specification, timing_definition, estimate, std_error, p_value, conf_low, conf_high) |>
  pivot_wider(
    names_from = timing_definition,
    values_from = c(estimate, std_error, p_value, conf_low, conf_high)
  ) |>
  mutate(
    att_change = estimate_half_year_rollover - estimate_current_any_month
  )

event_plot <- ggplot(
  event_profiles,
  aes(
    x = event_time,
    y = estimate,
    color = timing_definition,
    group = timing_definition
  )
) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey50") +
  geom_vline(xintercept = -0.5, linewidth = 0.4, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.4) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.8) +
  facet_wrap(~ specification, scales = "free_y") +
  scale_color_manual(
    values = c(
      current_any_month = "#1B4F72",
      half_year_rollover = "#B03A2E"
    ),
    labels = c(
      current_any_month = "Current any-month timing",
      half_year_rollover = "Half-year rollover timing"
    )
  ) +
  scale_x_continuous(breaks = sort(unique(event_profiles$event_time))) +
  labs(
    title = "Dollar Store Event Studies by Treatment Timing Definition",
    subtitle = "County reduced forms under current any-month timing and a July-December rollover alternative",
    x = "Event time",
    y = "Estimate",
    color = "Timing definition"
  ) +
  theme_im(base_size = 11)

plot_path <- next_available_path(
  file.path(plot_dir, "3_2_15_event_study_total_ds_timing_comparison.pdf")
)
ggsave(
  filename = plot_path,
  plot = event_plot,
  width = 11,
  height = 8.5,
  units = "in"
)

write.csv(
  att_summaries,
  next_available_path(file.path(table_dir, "3_2_15_event_study_total_ds_timing_comparison_att.csv")),
  row.names = FALSE
)
write.csv(
  att_wide,
  next_available_path(file.path(table_dir, "3_2_15_event_study_total_ds_timing_comparison_att_wide.csv")),
  row.names = FALSE
)
write.csv(
  selected_effects,
  next_available_path(file.path(table_dir, "3_2_15_event_study_total_ds_timing_comparison_selected_effects.csv")),
  row.names = FALSE
)
write.csv(
  sample_summaries,
  next_available_path(file.path(table_dir, "3_2_15_event_study_total_ds_timing_comparison_sample_summary.csv")),
  row.names = FALSE
)
write.csv(
  shift_distribution,
  next_available_path(file.path(table_dir, "3_2_15_event_study_total_ds_timing_comparison_shift_distribution.csv")),
  row.names = FALSE
)
write.csv(
  cohort_shift_summary,
  next_available_path(file.path(table_dir, "3_2_15_event_study_total_ds_timing_comparison_county_shifts.csv")),
  row.names = FALSE
)
write.csv(
  event_profiles,
  next_available_path(file.path(table_dir, "3_2_15_event_study_total_ds_timing_comparison_event_profiles.csv")),
  row.names = FALSE
)

cat("Treatment timing comparison complete.\n")
cat(sprintf("Event-study comparison plot: %s\n", plot_path))
cat(sprintf("ATT summary rows: %s\n", nrow(att_summaries)))
cat(sprintf("Counties with shifted cohorts: %s\n", sum(cohort_shift_summary$shift_status == "shifted_later", na.rm = TRUE)))
