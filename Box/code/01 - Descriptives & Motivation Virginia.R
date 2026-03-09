#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        01 - Virginia: Descriptives & Motivation.R
# Previous author:  -
# Current author:   Alejandro Herrera
# Creation date:    July 8, 2025
# Description:      How does ABAWD waivers affect entry?
#                   What is the underlying mechanism?
# Sample:           Virginia
#
# Change log:       
#///////////////////////////////////////////////////////////////////////////////

# Directory
  rm(list=ls())
  current_path = dirname(rstudioapi::getActiveDocumentContext()$path)
  setwd(current_path)
  setwd('..')
  gc()

# Libraries
  require(data.table)
  library(readr)
  library(dplyr)
  library(purrr)
  library(ggplot2)
  library(fixest)
  library(rdrobust)        
  


#*******************************************************************************
#----                             R file map                                ----
# 1. Load the data and import controls
# 2. Clean and prepare the data for regressions
# 3. Construct Treatment and merge controls
# 5. Run event study analysis and generate results
#*******************************************************************************

#///////////////////////////////////////////////////////////////////////////////
#----  1. Loading the data                                                  ----
#///////////////////////////////////////////////////////////////////////////////
# Snap =========================================================================
  snap = fread('data/snap/snap_clean.csv')
  
  counties = unique(snap$county_fips)
  counties = counties[counties %/% 1000 == 51]
  unique(snap$chain)

# Group non dollar stores ======================================================
  # For Supermarkets
  snap = snap[chain %in% c("chain_ingles_markets", 
                           "chain_winn-dixie", 
                           "chain_stop_&_shop", 
                           "chain_albertsons", 
                           "chain_fred_meyer", 
                           "chain_trader_joes", 
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
                           "chain_smart_&_final", 
                           "chain_wild_oats", 
                           "chain_meijer", 
                           "chain_giant_eagle", 
                           "chain_he_butt", 
                           "chain_stater_bros", 
                           "chain_roundys"),
              chain := 'chain_super_market']
  
  # For Club Stores
  snap = snap[chain %in% c("chain_costco", 
                           "chain_sams_club", 
                           "chain_bjs"),
              chain := 'chain_club_store']
  
  # For Convenience Stores
  snap = snap[chain %in% c("chain_seven_eleven", 
                           "chain_circle_k", 
                           "chain_speedway"),
              chain := 'chain_convenience_store']
  
  # For Multi-category (optional, depending on your classification)
  snap = snap[chain %in% c("chain_wal-mart", 
                           "chain_target"),
              chain := 'chain_multi_category']
  
  table(snap$chain)
  table(snap$chain, snap$authorization_year)

  
# Wages ========================================================================
  wages = fread('data/prices/Wages_V2.csv')

# Abawd ========================================================================
  aba = fread('data/virginia_abawd/snap_timelimits.csv')

# Count of stores  =============================================================
  storeCount = fread('data/snap/store_count.csv')
  
# Load other variables  ========================================================
  population =fread('data/acs/population.csv')
  acs03 = readRDS('data/acs/Append_CountyDP03.rds')
  acs04 = readRDS('data/acs/Append_CountyDP04.rds')
  
  fp = fread('data/prices/Prices.csv')
  setnames(fp, c('B20002_001'), c('income'))
  
  fp = fp[,.(GEOID, year, income, rent)]
  fp = fp[, rent:=rent*1]
  fp = fp[, county_fips:=as.numeric(GEOID)]
  
  u = fread('data/acs/Unemployment.csv')

# ==============================================================================
# What are the cuts for virginia

  # 2019: 5.4, over March '16 to Feb '18   (2)
  # 2018: 5.5, over Jan   '16 to Dec '17   (1)
  # 2017: 6.5, over May   '14 to Apr '16   (2)
  # 2016: 6.9, over May   '13 to Apr '15 (2)
  # 2015: 8.1, over Jan   '13 to Dec '14 (1)
  # 2014: 9.4, over Nov   '11 to Oct '13 (2)
  # 2013: State-wide
  # 2012: State-wide
  # 2011: State-wide
  
  
#///////////////////////////////////////////////////////////////////////////////
#----  2. SNAP Counts                                                       ----
#///////////////////////////////////////////////////////////////////////////////   
  tab = storeCount[, .(count=sum(count)), by='chain,year']
  tab = tab[chain %in% c('chain_dollar_general',
                         'chain_family_dollar',
                         'chain_dollar_tree')]
  ggplot(tab, aes(x=year, y=count, group=chain, color=chain)) + 
    geom_line() +
    geom_point() +
    scale_x_continuous(breaks = unique(tab$year)) +
    theme(legend.position = "bottom",
          axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))    
  snap = snap[State=='VA']

#///////////////////////////////////////////////////////////////////////////////
#----  3. Cleaning the data                                                 ----
#///////////////////////////////////////////////////////////////////////////////
# ABAWD modifications --------------------------------------------------------
  aba <- melt(aba, 
              id.vars = c("countycode", "countyname"), 
              variable.name = "FiscalYear", 
              value.name = "Value")

# Geography
  aba <- aba[is.na(Value), Value:=0]
  aba <- aba[, county_fips:=countycode]
  aba <- aba[, county_fips:=as.character(county_fips)]
  aba <- aba[nchar(county_fips)==2, county_fips:=paste0('0',county_fips)]
  aba <- aba[nchar(county_fips)==1, county_fips:=paste0('00',county_fips)]
  aba <- aba[, county_fips:=paste0('51', county_fips)]
  aba <- aba[, county_fips:=as.numeric(county_fips)]
  treated_counties = unique(aba$county_fips)

# Time
  aba <- aba[, year:=gsub('^FY(\\d+).+$', '\\1', FiscalYear)]
  aba <- aba[, year:=as.numeric(year)]
  aba <- unique(aba[,.(county_fips, year, countyname, Value)])
  
  counties = aba$county_fips

# Entry counts ---------------------------------------------------------------
  entry <- snap[, .(entry=.N), by='authorization_year,county_fips,chain']
  setnames(entry, 'authorization_year', 'year')
  entry <- dcast(entry, year + county_fips ~ chain, value.var = 'entry', fill=0)
  entry <- entry[, total:= chain_dollar_general + chain_dollar_tree + chain_family_dollar]
  
  entry <- entry[, state:=substr(county_fips, 1,2)]
  entry <- entry[state=='51']
  
  grid = CJ(county_fips = counties, 
            year= 2000:2020, 
            unique = TRUE)
  entry = merge(grid, entry, by=c('county_fips','year'), all.x=T)



# Store Counts -----------------------------------------------------------------
  sc = storeCount[, chain:=paste0(chain, '_count')]
  sc = sc[!chain %in% c("chain_family_dollar_count", 
                        "chain_dollar_general_count", 
                        "chain_dollar_tree_count"), chain := 'chain_nods_count'] 
  sc = sc[, .(count=sum(count)), by='county_fips,chain,year']
  sc = dcast(sc, year + county_fips ~ chain, value.var = 'count', fill=0)
  sc = sc[, total_count:=chain_dollar_general_count+
            chain_dollar_tree_count+
            chain_family_dollar_count]
  sc = sc[, county_fips:=as.numeric(county_fips)]

# Merge ------------------------------------------------------------------------
  aba <- merge(aba, entry, by=c('year', 'county_fips'), all.y=T)
  setnames(aba, 'Value', 'treatment')
  
  aba <- merge(aba, sc, by=c('year', 'county_fips'), all.x=T)
  aba[is.na(aba)] <- 0
  length(unique(aba$county_fips))

# Add controls -----------------------------------------------------------------
  aba <- merge(aba, fp[,.(county_fips, year, income, rent)], all.x=T, 
               by=c('year', 'county_fips'))
  
  length(unique(aba$county_fips))

# Event Study Variables --------------------------------------------------------
  event1 = aba[treatment==1]
  event1 = event1[, minYear1:=min(year), by='county_fips']
  event1 = event1[minYear1==year]
  
  event2 = aba[treatment==1 & year>=2014]
  event2 = event2[, minYear2:=min(year), by='county_fips']
  event2 = event2[minYear2==year]

  
  aba = merge(aba, event1[,.(county_fips, eventYear1=minYear1)], by='county_fips', all.x=T)
  length(unique(aba$county_fips))
  
  
  aba = aba[year %in% 2010:2013, treatment:=1]
  aba = aba[!county_fips %in% treated_counties, `:=`(eventYear1=2010)]
  
  aba = aba[, tau1:= year - eventYear1]
  
  aba = merge(aba, event2[,.(county_fips, eventYear2=minYear2)], by='county_fips', all.x=T)
  aba = aba[, tau2:= year - eventYear2]
  length(unique(aba$county_fips))

# Treated ----------------------------------------------------------------------
  aba = aba[, treated:=county_fips %in% treated_counties ]

# Merge wage -------------------------------------------------------------------
  aba = merge(aba, wages, by=c('county_fips', 'year'), all.x=T)  
  aba = aba[, wage_st := mean(wage,na.rm=T), by='year']
  aba = aba[is.na(wage), wage:=wage_st]
  
  # aba = aba[county_fips!=0]
  length(unique(aba$county_fips))

# Merge total of households ----------------------------------------------------
  aba = merge(aba, acs03[,.(county_fips=as.numeric(GEOID_COUNTY), year, totalHH, meanInc, medianInc)],
              by=c('county_fips', 'year'),
              all.x=T)
  length(unique(aba$county_fips))
  
  
  aba = merge(aba, population[,.(county_fips=GEOID, year, population=estimate)],
              by=c('county_fips', 'year'),
              all.x=T)
  length(unique(aba$county_fips))

# Merge the unemployment
  aba = merge(aba, u[,.(county_fips=GEOID, year, urate=unemployment_rate)],
              by=c('county_fips', 'year'),
              all.x=T)
  length(unique(aba$county_fips))

#///////////////////////////////////////////////////////////////////////////////
#----  4. Analysis Count  2014-2019                                         ----
#///////////////////////////////////////////////////////////////////////////////
# Set the relevant data
  aba = aba[county_fips!='51000']
  aba = aba[, lowq := total + chain_convenience_store]
  aba = aba[, rent:=rent/1000]
  aba = aba[, meanInc:=meanInc/1000]
  
  aba = aba[, zl := shift(urate, type = 'lag') ]
  aba = aba[, z := urate]
  
  aba1 = aba[year %in% 2014:2019]
  
  aba1 = aba1[is.na(tau2), tau2:=-1000]
  aba1 = aba1[is.na(eventYear2), eventYear2:= 10000]
  ihs = function(y){log(y+sqrt(y^2+1))}

# By type of stores
  png("figures/va_tfwe_sa.ds_stores.png", width = 800, height = 600)
  res_twfe_1 <- feols(ihs(total) ~ i(tau2, ref = c(-1,-1000)) + wage + meanInc + rent + urate| county_fips+year, data = aba1)
  res_sa20_1 <- feols(ihs(total) ~ sunab(eventYear2, year)  + wage + meanInc + rent + urate| county_fips + year, data = aba1)
  iplot(list(res_twfe_1, res_sa20_1), sep = 0.2, main='')
  legend("topleft", col = c(1, 2), pch = c(20, 17), 
         legend = c("TWFE", "Sun & Abraham (2021)"))
  dev.off()
  
  
  png("figures/va_tfwe_sa.super_market.png", width = 800, height = 600)
  res_twfe_2 <- feols(ihs(chain_super_market) ~ i(tau2, ref = c(-1,-1000)) + wage + meanInc + rent+ urate | county_fips+year, data = aba1)
  res_sa20_2 <- feols(ihs(chain_super_market) ~ sunab(eventYear2, year)  + wage + meanInc + rent+ urate | county_fips + year, data = aba1)
  iplot(list(res_twfe_2, res_sa20_2), sep = 0.2, main = "")
  legend("topleft", col = c(1, 2), pch = c(20, 17), 
         legend = c("TWFE", "Sun & Abraham (2021)"))
  dev.off()
  
  png("figures/va_tfwe_sa.convenience.png", width = 800, height = 600)
  res_twfe_3 <- feols(ihs(chain_convenience_store) ~ i(tau2, ref = c(-1,-1000)) + wage + meanInc + rent+ urate | county_fips+year, data = aba1)
  res_sa20_3 <- feols(ihs(chain_convenience_store) ~ sunab(eventYear2, year)  + wage + meanInc + rent+ urate | county_fips + year, data = aba1)
  iplot(list(res_twfe_3, res_sa20_3), sep = 0.2, main = "")
  legend("topleft", col = c(1, 2), pch = c(20, 17), 
         legend = c("TWFE", "Sun & Abraham (2021)"))
  dev.off()
  
  
  png("figures/va_tfwe_sa.multicategory.png", width = 800, height = 600)
  res_twfe_4 <- feols(ihs(chain_multi_category) ~ i(tau2, ref = c(-1,-1000)) + wage + meanInc + rent+ urate | county_fips+year, data = aba1)
  res_sa20_4 <- feols(ihs(chain_multi_category) ~ sunab(eventYear2, year)  + wage + meanInc + rent+ urate | county_fips + year, data = aba1)
  iplot(list(res_twfe_4, res_sa20_4), sep = 0.2, main = "")
  legend("topleft", col = c(1, 2), pch = c(20, 17), 
         legend = c("TWFE", "Sun & Abraham (2021)"))
  dev.off()
  

# Column 1
  summary(res_sa20_1, agg = "att")
# Column 2
  summary(res_sa20_2, agg = "att")
# Column 3
  summary(res_sa20_3, agg = "att")
# Column 4
  summary(res_sa20_4, agg = "att")
  
#///////////////////////////////////////////////////////////////////////////////
#----  5. Regression instrumenting by unemployment                          ----
#///////////////////////////////////////////////////////////////////////////////
  aba1 = aba[year %in% 2014:2019]
  

  
  
  # Instrumental variable ------------------------------------------------------
  m1 <- feols(ihs(total) ~ wage + meanInc + rent | county_fips+year | treatment ~ z , data = aba1)
  m2 <- feols(ihs(total) ~ wage + meanInc + rent | county_fips+year | treatment ~ zl , data = aba1)
  m3 <- feols(ihs(total) ~ wage + meanInc + rent | county_fips+year | treatment ~ z , data = aba1[abs(z-10)<2])
  m4 <- feols(ihs(total) ~ wage + meanInc + rent | county_fips+year | treatment ~ zl , data =  aba1[abs(z-10)<2])
  etable(list(m1,m2,m3,m4), tex =T)
  
  # First stage of m1
  summary(m1, stage = 1)
  
  # First stage of m2
  summary(m2, stage = 1)
  
  # First stage of m3
  summary(m3, stage = 1)
  
  # First stage of m4
  summary(m4, stage = 1)

 
  # RD -------------------------------------------------------------------------
  rates <- c(
    "2014" = 9.4,
    "2015" = 8.1,
    "2016" = 6.9,
    "2017" = 6.5,
    "2018" = 5.5,
    "2019" = 5.4
  )
  setorder(aba1, year)  # Ensure it's ordered by year
  aba1[, urate_lag := shift(urate, n = 1, type = "lag")]
  
  aba1[, rate20 := rates[as.character(year)] ]
  aba1[, urate_fix := urate_lag-rate20]
  
  x   <- aba1$urate_fix                       # forcing variable
  y   <- ihs(aba1$total)                  # outcome
  
  cov <- aba1[, c("wage", "meanInc",        # any numeric matrix/data-frame works
                "rent")]
  rd_res <- rdrobust(y = aba1$treatment,
                     x = aba1$urate_fix,
                     c = 0)
  summary(rd_res)

  # Plot
  library(rdrobust)
  library(patchwork)
  library(ggplot2)
  
  # Collect all rdplots as ggplot objects
  p1 <- rdplot(y = aba1$treatment, x = aba1$urate_fix, c = 0,
               x.label = "Unemployment Rate (urate_fix)",
               y.label = "Probability of Treatment",
               title = "Treatment vs. Unemployment")$rdplot
  
  p2 <- rdplot(y = aba1$wage, x = aba1$urate_fix, c = 0,
               x.label = "Unemployment Rate (urate_fix)",
               y.label = "Wage",
               title = "Wage vs. Unemployment")$rdplot
  
  p3 <- rdplot(y = aba1$medianInc, x = aba1$urate_fix, c = 0,
               x.label = "Unemployment Rate (urate_fix)",
               y.label = "Income",
               title = "Income vs. Unemployment")$rdplot
  
  p4 <- rdplot(y = aba1$rent, x = aba1$urate_fix, c = 0,
               x.label = "Unemployment Rate (urate_fix)",
               y.label = "Rent",
               title = "Rent vs. Unemployment")$rdplot
  
  # Combine them in a 2x2 grid
  (p1 | p2) / (p3 | p4)
  ggsave("figures/cutoffs_virginia.pdf", width = 10, height = 8)
  
  # Including the observables
  rd <- rdrobust(y = y,
                 x = x,
                 covs = cov,         # <-- controls go here
                 c   = 0)            # cutoff (default 0)
  summary(rd)
  
#///////////////////////////////////////////////////////////////////////////////
#----  6. Balancing Tables                                                  ----
#///////////////////////////////////////////////////////////////////////////////

  check_balance <- function(dt, treatment_var, vars_to_check) {
    # Ensure data.table format
    dt <- as.data.table(dt)
    
    # Create output table
    balance_table <- lapply(vars_to_check, function(var) {
      # T-test
      ttest <- t.test(dt[[var]] ~ dt[[treatment_var]])
      
      # Means by group
      means <- dt[, .(mean_treated = mean(get(var), na.rm = TRUE)), by = get(treatment_var)][order(get)]
      mean_treated <- means[2, mean_treated]
      mean_control <- means[1, mean_treated]
      
      # Standardized difference
      sd_pooled <- sqrt(var(dt[[var]], na.rm = TRUE))
      std_diff <- (mean_treated - mean_control) / sd_pooled
      
      data.table(
        variable = var,
        mean_treated = mean_treated,
        mean_control = mean_control,
        std_diff = std_diff,
        p_value = ttest$p.value
      )
    })
    
    rbindlist(balance_table)
  }
  
  vars <- c("wage", "meanInc", "rent")
  check_balance(aba1, treatment_var = "treatment", vars_to_check = vars)
  check_balance(aba1[abs(urate_fix)<1], treatment_var = "treatment", vars_to_check = vars)
  