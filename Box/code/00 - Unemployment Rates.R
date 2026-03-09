#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        00 - Unemployment Rates.R
# Previous author:  -
# Current author:   Alejandro Herrera
# Creation date:    August 01, 2025
# Description:      Generate an unemployment series by county-year 
#                   From 2012 - 2020
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
  library(zoo)
  library(lubridate)
  


#*******************************************************************************
#----                             R file map                                ----
# 1. Load the data from BLS 
# 2. Create the averages
#*******************************************************************************

#///////////////////////////////////////////////////////////////////////////////
#----  1. Loading the data                                                  ----
#///////////////////////////////////////////////////////////////////////////////

#  Load the files
   #remotes::install_github("jjchern/laus@v0.0.4") #LAUS TILL 2019
  
   dt = laus::county_month_nsa
   dt = data.table(dt)
   setnames(dt, 'unemployment rate','unemployment_rate')
   
#///////////////////////////////////////////////////////////////////////////////
#----  2. Create the state and county averages                              ----
#///////////////////////////////////////////////////////////////////////////////   
  # Month variable
   dt[, date := as.Date(paste(year, month, "01", sep = "-"))]
   setorder(dt, date)
   
   # Last 12 months averages  ==================================================
   unique_dates <- sort(unique(dt$date))
   
   for (current_date in unique_dates) {
     # Define 12-month window (current month back to 11 months prior)
     window_start <- current_date - months(11)
     
     # National average (for last 12 months)
     avg_val <- dt[date >= window_start & date <= current_date, 
                   mean(unemployment_rate, na.rm = TRUE)]
     dt[date == current_date, nat_unemployment_rate_12m := avg_val]
     
     # County average (for the last 12 months)
     dt[date >= window_start & date <= current_date, 
        cnt_unemployment_rate_12m := mean(nat_unemployment_rate_12m), 
        by = .(state_fips, county_fips)]
   }
   
   # Last 24 months averages ===================================================
   for (current_date in unique_dates) {
     # Define 24-month window (current month back to 23 months prior)
     window_start <- current_date - months(23)
     
     # National average (for last 24 months)
     avg_val <- dt[date >= window_start & date <= current_date, 
                   mean(unemployment_rate, na.rm = TRUE)]
     dt[date == current_date, nat_unemployment_rate_24m := avg_val]
     
     # County average (for the last 24 months)
     dt[date >= window_start & date <= current_date, 
        cnt_unemployment_rate_24m := mean(nat_unemployment_rate_24m), 
        by = .(state_fips, county_fips)]
   }

   
  # Get lagged variables =======================================================
   setorder(dt, date)
   dt[, `:=`(
     cnt_unemployment_rate_12m_lag = shift(cnt_unemployment_rate_12m, 12, type = 'lag'),
     cnt_unemployment_rate_24m_lag = shift(cnt_unemployment_rate_24m, 12, type = 'lag'),
     nat_unemployment_rate_12m10_lag = 0.1 * shift(nat_unemployment_rate_12m, 12, type = 'lag'),
     nat_unemployment_rate_24m20_lag = 0.2 * shift(nat_unemployment_rate_24m, 12, type = 'lag')
   ), by = .(state_fips, county_fips)]
   

  # Save =======================================================================
     fwrite(dt, 'data/BLS LAU/BLS LAU.csv')