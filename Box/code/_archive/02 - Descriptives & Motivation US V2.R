#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        01 - Virginia: Descriptives & Motivation.R
# Previous author:  -
# Current_mean author:   Alejandro Herrera
# Creation date:    October 5, 2025
# Description:      How does ABAWD waivers affect entry?
#                   What is the underlying mechanism?
# Sample:           The united states
#
# Change log:       November 17, 2025 - Including Treatment Descriptives   
#                   Update to new input data
#///////////////////////////////////////////////////////////////////////////////

# Directory
  rm(list=ls())
  current_mean_path = dirname(rstudioapi::getActiveDocumentContext()$path)
  setwd(current_mean_path)
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
# Abawd ========================================================================
  aba_old = fread('data/virginia_abawd/snap_timelimits.csv')
  #aba = fread('data/waivers/waived_data_consolidated_long.csv')
  aba = fread('data/waivers/waiver_data_long_covariates.csv')
  
  

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
#----  3. Statistics on SNAP treatment                                      ----
#///////////////////////////////////////////////////////////////////////////////   
  aba = copy(aba) # Already balanced
  aba = aba[, shutting_off := shift(waiver,type = 'lead')==0 & waiver == 1, by='county_fips']
  mean(aba[waiver==1]$shutting_off, na.rm=T) #62% will shut off
  
  # Detect first treatment
  first_treat = aba[waiver==1 & YEAR>=2014][,.(first_treat = min(YEAR)), by='county_fips']
  aba = merge(aba, first_treat, by = 'county_fips', all.x=T)
  aba = aba[is.na(first_treat), first_treat := 9999]
  
  aba[, time_to_treat := YEAR - first_treat]
  aba[, treated_group := sum(waiver)>=0, by='county_fips']
  
  # Identify contiguous treatment
  aba[order(county_fips, YEAR), cluster := {
    treatment_change = c(1, diff(waiver) != 0 | diff(YEAR) != 1)
    cluster_id = cumsum(treatment_change & waiver == 1)
    ifelse(waiver == 1, cluster_id, NA)
  }, by = county_fips]
  
  # Count treatments by unit
  tab = aba[treated_group==T][,.(treatment_arrivals=length(unique(.SD$cluster))), by='county_fips']
  round(table(tab$treatment_arrivals)/nrow(tab),2)
  hist(tab$treatment_arrivals)
  
  # 1    2    3    4 
  # 0.13 0.32 0.48 0.07 
  
  # We need something else, or trim the data before the next treatment
  
  # Treatment before
  second_treatment = aba[cluster==2][,.(second_treatment = min(YEAR)),by='county_fips']
  aba = merge(aba, second_treatment, by=c('county_fips'), all.x=T)

#///////////////////////////////////////////////////////////////////////////////
#----  4. Analysis Count  2014-2019                                         ----
#///////////////////////////////////////////////////////////////////////////////
# Dealing with missings
  aba = aba[is.na(chain_club), chain_club :=0]
  aba = aba[is.na(chain_convenience ), chain_convenience:=0]
  aba = aba[is.na(chain_dollar ), chain_dollar  :=0]
  aba = aba[is.na(chain_multicategory), chain_multicategory :=0]
  aba = aba[is.na(chain_supermarket ), chain_supermarket  :=0]
  
  
# Set the relevant data
  aba = aba[, lowq := chain_dollar  + chain_convenience ]
  aba = aba[, rent_mean:=rent_mean/1000]
  aba = aba[, income:=income/1000]
  
  aba = aba[, zl := shift(unemployment_rate, type = 'lag') ]
  aba = aba[, z := unemployment_rate]
  aba = aba[, no_stores := (chain_dollar + chain_supermarket + chain_convenience  + chain_multicategory) == 0]

  #aba1 = aba[YEAR %in% 2014:2019]
  aba1 = aba[YEAR %in% 2014:2019]
  #aba1 = aba1[is.na(second_treatment) | YEAR < second_treatment]
  #aba1 = aba1[treated_group == T]
  ihs = function(y){log(y+sqrt(y^2+1))}
  
# By type of stores ===
  res_sa20_1 <- feols(ihs(chain_dollar)~ sunab(first_treat, YEAR, ref.p = 0)  + wage + income + rent_mean + unemployment_rate| 
                      county_fips + YEAR, 
                      data = aba1)
  iplot(res_sa20_1, sep = 0.2, main='')
  title("Sun and Abraham - Dollar Stores")
  summary(res_sa20_1) # 10.4k observations
  summary(res_sa20_1, agg = "att") #0.003%
  length(unique(aba1$county_fips)) #2219

  
  
  
  
  
  
  
  res_sa20_1 <- feols(log(lowq + 0.01)~ sunab(first_treat, YEAR, ref.p = 0)  + wage + income + rent_mean + unemployment_rate + zl| county_fips + YEAR, data = aba1)
  iplot(res_sa20_1, sep = 0.2, main='')
  title("Sun and Abraham - Convenience Stores")
  summary(res_sa20_1)
  summary(res_sa20_1, agg = "att")
  
  

  
  
  
  
  