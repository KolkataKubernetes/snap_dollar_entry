#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        00 - Cleaning SNAP.R
# Previous author:  -
# Current author:   Alejandro Herrera
# Creation date:    July 8, 2025
# Description:      Prep administrative data into clean version + panel
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
# 1. Load snap data from FDA
# 2. Standardize the geography and clean the store names
# 3. Save the cleaned FDA data
# 4. Generate a panel of county-year-#stores
#*******************************************************************************
# Load The Data
  library(data.table)
  library(parallel)
  library(stargazer)
  
  library(plm)
  library(fixest)
  
# Directory
  rm(list=ls())
  current_path = dirname(rstudioapi::getActiveDocumentContext()$path)
  setwd(current_path)
  setwd('..')
  
  
# Directory
  rm(list=ls())
  current_path = dirname(rstudioapi::getActiveDocumentContext()$path)
  setwd(current_path)
  setwd('..')
  
# Parameters
  FullRun = T

#///////////////////////////////////////////////////////////////////////////////
#----  1. Loading the data                                                  ----
#///////////////////////////////////////////////////////////////////////////////
# SNAP
  snap = fread('data/SNAP/Historical SNAP Retailer Locator Data-20231231.csv')

# County Crosswalk
  county = fread('data/county_list/uscounties.csv')
  
#///////////////////////////////////////////////////////////////////////////////
#---- 2. Standardize the County + Identify Chain Stores                     ----
#///////////////////////////////////////////////////////////////////////////////
# 2.A. Identify different stores -----------------------------------------------
# Define store name patterns and corresponding standard chains
  store_patterns = c(
    'dollar general'       = 'dollar general',
    'dollar tree'          = 'dollar tree',
    'family dollar'        = 'family dollar',
    '7-eleven'             = 'seven eleven',
    'circle k'             = 'circle k',
    'speedway'             = 'speedway',
    'albertsons'           = 'albertsons',
    'aldi'                 = 'aldi',
    'bashas markets'       = 'bashas markets',
    'delhaize america'     = 'delhaize america',
    'fred meyer'           = 'fred meyer',
    'giant eagle'          = 'giant eagle',
    'giant food'           = 'giant food',
    'great a & p tea co'   = 'great a & p tea co',
    'he butt'              = 'he butt',
    'hannaford bros'       = 'hannaford bros',
    'hy vee food stores'   = 'hy vee food stores',
    'ingles markets'       = 'ingles markets',
    'kroger'               = 'kroger',
    'lone star funds'      = 'lone star funds',
    'publix'               = 'publix',
    "raley's"              = "raley's",
    "roundy's"             = "roundy's",
    'ruddick corp'         = 'ruddick corp',
    'safeway'              = 'safeway',
    'save a lot'           = 'save a lot',
    'save mart'            = 'save mart',
    'smart & final'        = 'smart & final',
    'stater bros'          = 'stater bros',
    'stop & shop'          = 'stop & shop',
    'supervalu'            = 'supervalu',
    "trader joe's"         = "trader joe's",
    'weis markets'         = 'weis markets',
    'whole foods'          = 'whole foods',
    'wild oats'            = 'wild oats',
    'winn-dixie'           = 'winn-dixie',
    'meijer'               = 'meijer',
    'target'               = 'target',
    'wal.*mart'            = 'wal-mart',
    "bj's"                 = "bj's",
    'costco'               = 'costco',
    "sam's club"           = "sam's club"
  )
  
# Standardize and classify
  snap[, `Store Name` := tolower(`Store Name`)]
  snap[, chain := 'placeholder']
  
  for (pattern in names(store_patterns)) {
    snap[grepl(pattern, `Store Name`, ignore.case = TRUE), chain := store_patterns[[pattern]]]
  }
  
  table(snap$chain, exclude = NA)
  
  tab = snap[chain=='placeholder']
  tab = tab[,.(N=.N), by='Store Name,Store Type']
  
# Label the placeholders
  snap = snap[`Store Type`=='Convenience Store' & chain=='placeholder', chain := 'convenience_store']
  snap = snap[`Store Type`=='Supermarket' & chain=='placeholder', chain := 'super_market']
  snap = snap[`Store Type`=="Farmers' Market" & chain=='placeholder', chain := 'farmers_market']
  snap = snap[`Store Type`=="Large Grocery Store" & chain=='placeholder', chain := 'large_grocery']
  snap = snap[`Store Type`=="Medium Grocery Store" & chain=='placeholder', chain := 'medium_grocery']
  snap = snap[`Store Type`=="Small Grocery Store" & chain=='placeholder', chain := 'small_grocery']
  snap = snap[`Store Type`=="Fruits/Veg Specialty" & chain=='placeholder', chain := 'produce']
  
# Mark dollar stores
  dollar_pattern = '(dollar tree|dollar general|family dollar)'
  snap[, dollarStore := grepl(dollar_pattern, `Store Name`)]
  
# Final formatting
  snap[, chain := paste0('chain_', chain)]
  snap[, chain := gsub("[' ]", "_", chain)]
  
# Filter out placeholder
  snap = snap[chain != 'chain_placeholder']
  
# 2.B Standardize County -------------------------------------------------------
# Standardize case
  county[, county := toupper(county)]
  
# Check overlap (optional diagnostics)
  mean(county$county %in% snap$County)
  mean(unique(snap$County) %in% county$county)  # ~96%
  
# Drop duplicates
  county[, keep := .N == 1, by = .(county, state_id)]
  county <- county[keep == TRUE, .(county, state_id, county_fips)]
  
# Merge to SNAP data
  snap <- merge(
    snap,
    county[, .(County = county, State = state_id, county_fips)],
    by = c("County", "State"),
    all.x = TRUE
  )
  
# Format FIPS code to 5 digits (left-pad with 0 if 4-digit)
  snap[, county_fips := sprintf("%05s", county_fips)]


#///////////////////////////////////////////////////////////////////////////////
#----  3. Make a panel, and save                                            ----
#///////////////////////////////////////////////////////////////////////////////
# Clean variables --------------------------------------------------------------
  snap = snap[, `Authorization Date`:=as.Date(`Authorization Date`, '%m/%d/%Y')]
  snap = snap[, `End Date`:=as.Date(`End Date`, '%m/%d/%Y')]
  snap = snap[, authorization_year:=year(`Authorization Date`)]
  snap = snap[, end_year:=year(`End Date`)]
  
  snap = snap[is.na(end_year), end_year:=2024]
  
  
# Count stores -----------------------------------------------------------------
  # 1. First entry, 2. Same brand stores, 3. Other ds 
  # 4. Presence of other retailers 
  tab = expand.grid(id = unique(snap$`Record ID`), year=min(snap$authorization_year):2025)
  tab = merge(tab, 
              snap[, .(id = `Record ID`, 
                       authorization_year, 
                       end_year, 
                       name=`Store Name`, 
                       type=`Store Type`,
                       chain,
                       county_fips)],
              all.x=T, by='id')
  tab = data.table(tab)
  tab = tab[authorization_year<= year & year<=end_year]  
  
  # First entry
  tab_chain = tab[, .(firstEntry=min(year)), by='county_fips,chain']
  tab_chain = tab_chain[chain=='chain_family_dollar']
  tab_chain = dcast(tab_chain, county_fips ~ chain, value.var = 'firstEntry')
  
  #  Count Stores
  tab = tab[, .(count=.N), by = 'county_fips,chain,year']
  
  fwrite(tab, 'Data/SNAP/store_count.csv')
  fwrite(snap, 'Data/SNAP/snap_clean.csv')