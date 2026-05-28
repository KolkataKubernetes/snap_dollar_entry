#///////////////////////////////////////////////////////////////////////////////
#----  0. Setup                                                             ----
#///////////////////////////////////////////////////////////////////////////////
library(data.table)
library(did)
library(dplyr)
library(ggplot2)

ihs = function(x) { log(x + sqrt(x^2 + 1)) }

fit_cs = function(df, outcome, controls, control_group) {
  keep = complete.cases(df[, c("county_fips", "year", "eventYear2", "population", "wage", "meanInc", "rent", "urate", outcome), with = FALSE])
  df = df[keep]
  
  fit = att_gt(
    yname = outcome,
    tname = "year",
    idname = "county_fips",
    gname = "eventYear2",
    xformla = controls,
    data = df,
    panel = TRUE,
    allow_unbalanced_panel = TRUE,
    control_group = control_group,
    est_method = "reg",
    base_period = "universal",
    bstrap = FALSE,
    cband = FALSE
  )
  
  aggte(
    fit,
    type = "dynamic",
    min_e = -3,
    max_e = 5,
    na.rm = TRUE,
    bstrap = FALSE,
    cband = FALSE
  )
}

cs_to_df = function(es) {
  data.table(
    x = es$egt,
    estimate = es$att.egt,
    se = es$se.egt
  )[!is.na(se)][
    ,
    `:=`(
      ci_low = estimate - 1.96 * se,
      ci_high = estimate + 1.96 * se
    )
  ]
}

# Load samples (data = only treated, panel = only treated + never treated)
git_root = "."
processed_root = trimws(gsub("^['\"]|['\"]$", "", readLines("2_processed_data/processed_root.txt", warn = FALSE)[1]))
input_root = trimws(gsub("^['\"]|['\"]$", "", readLines("0_inputs/input_root.txt", warn = FALSE)[1]))
analysis_panel = readRDS(file.path(processed_root, "2_9_analysis", "2_9_0_us_analysis_panel.rds"))
analysis_panel = data.table(analysis_panel)
analysis_panel = analysis_panel[year %in% 2014:2019]
analysis_panel[, state_fips := county_fips %/% 1000]
analysis_panel[, treated_group := !is.na(eventYear2)]
analysis_panel[, treated_state := any(treated_group), by = state_fips]
analysis_panel[, treated_county := any(treated_group), by = county_fips]

data = copy(analysis_panel)
data = data[treated_state == TRUE & treated_county == TRUE]

panel = copy(analysis_panel)
panel[is.na(eventYear2), eventYear2 := 0]
table(panel$eventYear2)
table(panel$eventYear2, panel$year)

# RUCC data (for heterogeneity analysis)
rucc = readxl::read_xlsx(file.path(input_root, "0_7_Ruralurbancontinuumcodes2023.xlsx"))
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
controls = ~ population + wage + meanInc + rent + urate
control_group = "notyettreated"

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

out_dir = file.path(git_root, "3_outputs", "3_2_reduced_form", "3_2_0_county")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

for (samp_name in names(samples)) {
  
  samp = copy(samples[[samp_name]])
  samp_label = ifelse(samp_name == "panel", "With Never Treated", "Only Treated")
  cat("\n\n====", samp_name, "====\n")
  
  samp[, total_ds_ihs := ihs(total_ds)]
  samp[, total_ds_indicator := as.integer(total_ds > 0)]
  for (nm in outcomes) {
    samp[, (paste0(nm, "_indicator")) := as.integer(get(nm) > 0)]
  }
  
  #/////////////////////////////////////////////////////////////////////////////
  #----  1. Dollar-Store Entry: Three Specifications                        ----
  #/////////////////////////////////////////////////////////////////////////////
  
  m1 = fit_cs(samp, "total_ds_ihs", controls, control_group)
  m2 = fit_cs(samp, "total_ds", controls, control_group)
  m3 = fit_cs(samp, "total_ds_indicator", controls, control_group)
  
  cat("\n-- Dynamic summaries:", samp_name, "--\n")
  print(cs_to_df(m1)[x < 0])
  print(cs_to_df(m2)[x < 0])
  print(cs_to_df(m3)[x < 0])
  
  plot_three_specs = bind_rows(
    cs_to_df(m1)[, spec := "IHS"],
    cs_to_df(m2)[, spec := "Levels"],
    cs_to_df(m3)[, spec := "Indicator"]
  )
  
  p_three_specs = ggplot(plot_three_specs, aes(x = x, y = estimate, color = spec, shape = spec)) +
    geom_point(position = position_dodge(width = 0.35)) +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                  width = 0.2, position = position_dodge(width = 0.35)) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_vline(xintercept = -1, linetype = "dotted", color = "red") +
    labs(x = "Relative Year", y = "Estimate",
         title = paste("Effect on Dollar-Store Entry -", samp_label),
         color = "Specification", shape = "Specification") +
    theme_bw()
  
  ggsave(file.path(out_dir, paste0("1_2_1b_es_quick_three_specs_", samp_name, "_cs.png")),
         plot = p_three_specs, width = 9, height = 6)
  
  #/////////////////////////////////////////////////////////////////////////////
  #----  2. Entry by Format: Indicator Models                               ----
  #/////////////////////////////////////////////////////////////////////////////
  
  models = lapply(setNames(outcomes, outcomes), function(y) {
    fit_cs(samp, paste0(y, "_indicator"), controls, control_group)
  })
  
  att_table = rbindlist(lapply(names(models), function(nm) {
    es = models[[nm]]
    data.table(
      outcome = nm,
      att = es$overall.att,
      se = es$overall.se,
      ci_low = es$overall.att - 1.96 * es$overall.se,
      ci_high = es$overall.att + 1.96 * es$overall.se
    )
  }))
  
  cat("\n-- ATT table:", samp_name, "--\n")
  print(att_table)
  
  write.table(
    att_table,
    file = file.path(out_dir, paste0("1_2_1b_es_quick_att_", samp_name, "_cs.txt")),
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  
  for (nm in names(models)) {
    plot_data_nm = cs_to_df(models[[nm]])
    
    p_nm = ggplot(plot_data_nm, aes(x = x, y = estimate)) +
      geom_point() +
      geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2) +
      geom_hline(yintercept = 0, linetype = "dashed") +
      geom_vline(xintercept = -1, linetype = "dotted", color = "red") +
      labs(x = "Relative Year", y = "Estimate",
           title = paste(nm, "-", samp_label)) +
      theme_bw()
    
    ggsave(file.path(out_dir, paste0("1_2_1b_es_quick_att_", samp_name, "_", nm, "_cs.png")),
           plot = p_nm, width = 9, height = 6)
  }
  
  plot_data = lapply(names(models), function(nm) {
    df = cs_to_df(models[[nm]])
    df$outcome = nm
    df
  }) |> bind_rows()
  
  p = ggplot(plot_data, aes(x = x, y = estimate)) +
    geom_point() +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_vline(xintercept = -1, linetype = "dotted", color = "red") +
    facet_wrap(~outcome, scales = "free_y", labeller = as_labeller(outcome_labels)) +
    labs(x = "Relative Year", y = "Estimate on Entry by Format",
         title = paste("Entry by Format -", samp_label)) +
    theme_bw()
  
  ggsave(file.path(out_dir, paste0("1_2_1b_es_quick_att_", samp_name, "_all_formats_cs.png")),
         plot = p, width = 9, height = 6)
  
  #/////////////////////////////////////////////////////////////////////////////
  #----  3. Entry by Format × RUCC (Metro vs Non-Metro)                     ----
  #/////////////////////////////////////////////////////////////////////////////
  
  plot_data_rucc_all = list()
  
  for (metro_val in c(TRUE, FALSE)) {
    
    metro_label = ifelse(metro_val, "Metro", "NonMetro")
    samp_metro  = samp[metro == metro_val]
    cat("\n--", metro_label, "(", samp_name, ") --\n")
    
    models_rucc = lapply(setNames(outcomes, outcomes), function(y) {
      fit_cs(samp_metro, paste0(y, "_indicator"), controls, control_group)
    })
    
    att_table_rucc = rbindlist(lapply(names(models_rucc), function(nm) {
      es = models_rucc[[nm]]
      data.table(
        outcome = nm,
        att = es$overall.att,
        se = es$overall.se,
        ci_low = es$overall.att - 1.96 * es$overall.se,
        ci_high = es$overall.att + 1.96 * es$overall.se
      )
    }))
    
    cat("\n-- ATT table:", samp_name, metro_label, "--\n")
    print(att_table_rucc)
    
    write.table(
      att_table_rucc,
      file = file.path(out_dir, paste0("1_2_1b_es_quick_att_", samp_name, "_", metro_label, "_cs.txt")),
      sep = "\t",
      row.names = FALSE,
      quote = FALSE
    )
    
    plot_data_rucc = lapply(names(models_rucc), function(nm) {
      df = cs_to_df(models_rucc[[nm]])
      df$outcome = nm
      df
    }) |> bind_rows()
    plot_data_rucc$metro_group = metro_label
    plot_data_rucc_all[[metro_label]] = plot_data_rucc
  }
  
  plot_data_rucc_combined = bind_rows(plot_data_rucc_all)
  
  p_rucc = ggplot(plot_data_rucc_combined,
                  aes(x = x, y = estimate, color = metro_group, shape = metro_group)) +
    geom_point(position = position_dodge(width = 0.4)) +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                  width = 0.2, position = position_dodge(width = 0.4)) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_vline(xintercept = -1, linetype = "dotted", color = "red") +
    facet_wrap(~outcome, scales = "free_y", labeller = as_labeller(outcome_labels)) +
    labs(x = "Relative Year", y = "Estimate on Entry by Format",
         title = paste("Entry by Format -", samp_label, "- Metro vs Non-Metro"),
         color = "RUCC Group", shape = "RUCC Group") +
    theme_bw()
  
  ggsave(file.path(out_dir, paste0("1_2_1b_es_quick_att_", samp_name, "_metro_comparison_cs.png")),
         plot = p_rucc, width = 9, height = 6)
}
