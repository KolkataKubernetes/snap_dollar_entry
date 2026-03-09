#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        00 - Prepping ACS.R
# Previous author:  -
# Current author:   Alejandro Herrera
# Creation date:    July 8, 2025
# Description:      Prep ACS: unemployment, income, snap population, shap share.
#
# Change log:       
#///////////////////////////////////////////////////////////////////////////////

# Directory
  rm(list=ls())
  current_path = dirname(rstudioapi::getActiveDocumentContext()$path)
  setwd(current_path)
  setwd('../..')
  gc()

# Libraries
  library(data.table)
  library(parallel)
  library(dplyr)
  library(glmnet)


#*******************************************************************************
#----                             R file map                                ----
# 1. Download variables
# 2. Save information
#*******************************************************************************
# Load The Data
  library(data.table)
  library(parallel)
  library(stargazer)
  
  library(tidycensus)
  library(data.table)
  library(dplyr)
  
# Directory
  rm(list=ls())
  current_path = dirname(rstudioapi::getActiveDocumentContext()$path)
  setwd(current_path)
  setwd('..')
  
#///////////////////////////////////////////////////////////////////////////////
#----  1. Loading the data                                                  ----
#///////////////////////////////////////////////////////////////////////////////
# Load once, cache for speed
  acs_vars <- lapply(2005:2020, function(y) {
    load_variables(year = y, dataset = "acs5", cache = TRUE)[, year := y]
  })
  acs_vars <- rbindlist(acs_vars)  

# Define variables of interest
  vars <- c(
    income         = "B20002_001",    # Median income
    unemployed     = "B23025_005",    # Estimate!!Unemployed
    labor_force    = "B23025_003",    # Estimate!!Civilian labor force
    total_pop      = "B01003_001",    # Total population
    snap_hh        = "B22003_002",    # Households receiving SNAP
    total_hh       = "B22003_001",    # Total households
    rent           = "B25064_001",    # Median gross rent
    snap_pop       = "B19058_002",    # Persons in households receiving SNAP
    wages          = "B20017_001"     # Median earnings of full-time, year-round workers
    
  )

# Function to get and process data for a single year
  get_acs_year <- function(y) {
    dat <- get_acs(
      geography = "county",
      variables = vars,
      year = y,
      survey = "acs5",
      cache_table = TRUE,
      output = "wide"
    )
    
    dt <- as.data.table(dat)
    dt[, county_fips := as.numeric(GEOID)]
    dt[, year := y]
    
    dt <- dt[, .(
      county_fips,
      year,
      income        = incomeE,
      unemployed    = unemployedE,
      labor_force   = labor_forceE,
      total_pop     = total_popE,
      snap_hh       = snap_hhE,
      total_hh      = total_hhE,
      snap_pop      = snap_popE,
      rent          = rentE,
      wages         = wagesE
    )]
    
    dt[, unemployment := ifelse(labor_force > 0, unemployed / labor_force, NA)]
    dt[, snap_hh_share := ifelse(total_hh > 0, snap_hh / total_hh, NA)]
    dt[, snap_pop_share := ifelse(total_pop > 0, snap_pop / total_pop, NA)]
    
    return(dt)
  }

# Loop through 2009–2020
  years <- 2011:2020
  fp_list <- lapply(years, get_acs_year)

# Combine all years
  fp <- rbindlist(fp_list)
  
  fwrite(fp, 'data/acs/acs_2012_2020.csv')