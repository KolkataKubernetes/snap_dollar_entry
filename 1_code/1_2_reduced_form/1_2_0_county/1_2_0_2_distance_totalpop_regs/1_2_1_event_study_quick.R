#///////////////////////////////////////////////////////////////////////////////
#----  0. Setup                                                             ----
#///////////////////////////////////////////////////////////////////////////////
library(data.table)
library(fixest)
library(dplyr)
library(ggplot2)

ihs = function(x) { log(x + sqrt(x^2 + 1)) }

# Load samples (data = only treated, panel = only treated + never treated)
  processed_root = file.path(box_root, 'data', '2_processed_data')
  input_root = file.path(box_root, 'data', '0_inputs')
  data = readRDS(file.path(processed_root, "2_9_analysis", "2_9_2_event_study_sample.rds"))
  data = data.table(data)

  panel = readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))
  panel = data.table(panel)
  panel = panel[year %in% 2014:2019]
  panel = panel[tau2 >= -3 | is.na(tau2)]
  panel = panel[is.na(eventYear2), eventYear2:=9999]
  table(panel$eventYear2)
  table(panel$eventYear2, panel$year)

# RUCC data (for heterogeneity analysis)
  rucc = read_xlsx(file.path(input_root, "0_7_Ruralurbancontinuumcodes2023.xlsx"))
  rucc = data.table(rucc)
  rucc[, county_fips := as.numeric(FIPS)]

  panel = merge(panel, rucc[,.(county_fips, rucc = RUCC_2023)], by='county_fips')
  data = merge(data, rucc[,.(county_fips, rucc = RUCC_2023)], by='county_fips')

  panel[, metro := rucc %in% 1:3]
  data[, metro := rucc %in% 1:3]

  # safeguard: Panel and data should be balanced (N=1)
  panel[, .N, by = .(county_fips, year)][, table(N)]
  data[, .N, by = .(county_fips, year)][, table(N)]

  # safeguard: no missings in rucc
  mean(is.na(data$rucc))
  mean(is.na(panel$rucc))

  samples = list("data" = data, "panel" = panel)

#///////////////////////////////////////////////////////////////////////////////
#----  Loop over samples                                                    ----
#///////////////////////////////////////////////////////////////////////////////
controls  = "population + wage + meanInc + rent + urate"
fe        = "county_fips + year"
sunab_arg = "sunab(eventYear2, year, ref.p = -1)"

outcomes = c("total_ds",
             "chain_super_market",
             "chain_convenience_store",
             "chain_multi_category",
             "chain_medium_grocery",
             "chain_small_grocery",
             "chain_produce",
             "chain_farmers_market")

outcome_labels = c(
  "total_ds"                 = "Dollar Stores",
  "chain_super_market"       = "Supermarkets",
  "chain_convenience_store"  = "Convenience Stores",
  "chain_multi_category"     = "Multi-Category Stores",
  "chain_medium_grocery"     = "Medium Grocery",
  "chain_small_grocery"      = "Small Grocery",
  "chain_produce"            = "Produce Stores",
  "chain_farmers_market"     = "Farmers Markets"
)

pre_trend_pattern = "year::-[2-9]|year::-[0-9]{2}"
out_dir = file.path(git_root, "3_outputs/3_2_reduced_form/3_2_0_county")

for (samp_name in names(samples)) {

  samp = samples[[samp_name]]
  samp_label = ifelse(samp_name == "panel", "With Never Treated", "Only Treated")
  cat("\n\n====", samp_name, "====\n")

  #/////////////////////////////////////////////////////////////////////////////
  #----  1. Dollar-Store Entry: Three Specifications                        ----
  #/////////////////////////////////////////////////////////////////////////////

  # Regressions ----------------------------------------------------------------
  m1 = feols(as.formula(paste("ihs(total_ds) ~", sunab_arg, "+", controls, "|", fe)),
             data = samp, cluster = ~county_fips)

  m2 = feols(as.formula(paste("total_ds ~",       sunab_arg, "+", controls, "|", fe)),
             data = samp, cluster = ~county_fips)

  m3 = feols(as.formula(paste("total_ds > 0 ~",   sunab_arg, "+", controls, "|", fe)),
             data = samp, cluster = ~county_fips)

  # Pre-trend Wald tests -------------------------------------------------------
  cat("\n-- Wald tests:", samp_name, "--\n")
  print(wald(m1, keep = pre_trend_pattern, vcov = ~county_fips))
  print(wald(m2, keep = pre_trend_pattern, vcov = ~county_fips))
  print(wald(m3, keep = pre_trend_pattern, vcov = ~county_fips))

  # Combined event-study plot --------------------------------------------------
  png(file.path(out_dir, paste0("3_2_0_0_three_specs_", samp_name, ".png")),
      width = 800, height = 500)
  iplot(
    list("IHS" = m1, "Levels" = m2, "Indicator" = m3),
    sep  = 0.25,
    main = paste("Effect on Dollar-Store Entry -", samp_label)
  )
  legend("topleft",
         legend = c("IHS", "Levels", "Indicator"),
         col    = 1:3,
         pch    = 20,
         bty    = "n")
  dev.off()

  #/////////////////////////////////////////////////////////////////////////////
  #----  2. Entry by Format: Indicator Models                               ----
  #/////////////////////////////////////////////////////////////////////////////

  # Regressions ----------------------------------------------------------------
  models = lapply(setNames(outcomes, outcomes), function(y) {
    fml = as.formula(paste0(
      y, " > 0 ~ ", sunab_arg, " + ", controls, " | ", fe
    ))
    feols(fml, data = samp, cluster = ~county_fips)
  })

  # ATT summary table ----------------------------------------------------------
  cat("\n-- ATT table:", samp_name, "--\n")
  print(etable(models, agg = 'ATT'))

  etable(models, agg = 'ATT',
         tex = TRUE,
         file = file.path(out_dir, paste0("1_2_1_event_study_quick_att_", samp_name, ".txt")))

  # Individual event-study plots -----------------------------------------------
  for (nm in names(models)) {
    png(file.path(out_dir, paste0("3_2_0_1_regs_indicator_", samp_name, "_", nm, ".png")),
        width = 800, height = 500)
    iplot(models[[nm]], main = paste(nm, "-", samp_label))
    dev.off()
  }

  # Faceted ggplot across all formats ------------------------------------------
  plot_data = lapply(names(models), function(nm) {
    df         = as.data.frame(iplot(models[[nm]], only.params = TRUE)$prms)
    df$outcome = nm
    df
  }) |> bind_rows()

  p = ggplot(plot_data |> filter(!is_ref), aes(x = x, y = estimate)) +
    geom_point() +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2) +
    geom_hline(yintercept = 0,  linetype = "dashed") +
    geom_vline(xintercept = -1, linetype = "dotted", color = "red") +
    facet_wrap(~outcome, scales = "free_y", labeller = as_labeller(outcome_labels)) +
    labs(x = "Relative Year", y = "Estimate on Entry by Format",
         title = paste("Entry by Format -", samp_label)) +
    theme_bw()

  ggsave(file.path(out_dir, paste0("1_2_1_es_quick_att_", samp_name, "_all_formats.png")),
         plot = p, width = 9, height = 6)

  #/////////////////////////////////////////////////////////////////////////////
  #----  3. Entry by Format × RUCC (Metro vs Non-Metro)                     ----
  #/////////////////////////////////////////////////////////////////////////////

  plot_data_rucc_all = list()

  for (metro_val in c(TRUE, FALSE)) {

    metro_label = ifelse(metro_val, "Metro", "NonMetro")
    samp_metro  = samp[metro == metro_val]
    cat("\n--", metro_label, "(", samp_name, ") --\n")

    # Regressions by metro status -----------------------------------------------
    models_rucc = lapply(setNames(outcomes, outcomes), function(y) {
      fml = as.formula(paste0(
        y, " > 0 ~ ", sunab_arg, " + ", controls, " | ", fe
      ))
      feols(fml, data = samp_metro, cluster = ~county_fips)
    })

    # ATT summary table ---------------------------------------------------------
    cat("\n-- ATT table:", samp_name, metro_label, "--\n")
    print(etable(models_rucc, agg = 'ATT'))

    etable(models_rucc, agg = 'ATT',
           tex = TRUE,
           file = file.path(out_dir, paste0("1_2_1_es_quick_att_", samp_name, "_", metro_label, ".txt")))

    # Collect plot data ---------------------------------------------------------
    plot_data_rucc = lapply(names(models_rucc), function(nm) {
      df         = as.data.frame(iplot(models_rucc[[nm]], only.params = TRUE)$prms)
      df$outcome = nm
      df
    }) |> bind_rows()
    plot_data_rucc$metro_group = metro_label
    plot_data_rucc_all[[metro_label]] = plot_data_rucc
  }

  # Combined faceted plot: Metro vs Non-Metro -----------------------------------
  plot_data_rucc_combined = bind_rows(plot_data_rucc_all)

  p_rucc = ggplot(plot_data_rucc_combined |> filter(!is_ref),
                  aes(x = x, y = estimate, color = metro_group, shape = metro_group)) +
    geom_point(position = position_dodge(width = 0.4)) +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                  width = 0.2, position = position_dodge(width = 0.4)) +
    geom_hline(yintercept = 0,  linetype = "dashed") +
    geom_vline(xintercept = -1, linetype = "dotted", color = "red") +
    facet_wrap(~outcome, scales = "free_y", labeller = as_labeller(outcome_labels)) +
    labs(x = "Relative Year", y = "Estimate on Entry by Format",
         title = paste("Entry by Format -", samp_label, "- Metro vs Non-Metro"),
         color = "RUCC Group", shape = "RUCC Group") +
    theme_bw()

  ggsave(file.path(out_dir, paste0("1_2_1_es_quick_att_", samp_name, "_metro_comparison.png")),
         plot = p_rucc, width = 9, height = 6)
}
