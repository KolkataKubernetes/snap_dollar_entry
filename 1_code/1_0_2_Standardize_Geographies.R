#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_2_Standardize_Geographies.R
# Previous author:  -
# Current author:   Alejandro Herrera
# Creation date:    September 21, 2025
# Description:      Aggregate RA data.
#
# Change log:       
#///////////////////////////////////////////////////////////////////////////////



# Setup ------------------------------------------------------------------------
rm(list=ls())
current_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(current_path)
setwd('..')
gc()

# Box Directory ----------------------------------------------------------------
condition = current_path == "C:/Users/aleja/Research/snap_dollar_entry/1_code"
user_index = condition+1
file_path <- readLines("2_processed_data/processed_path.txt")[user_index]


# Libraries --------------------------------------------------------------------
library(data.table)
library(sf)
library(tigris)     
options(tigris_use_cache = TRUE, tigris_year = 2010)  

# Functions --------------------------------------------------------------------
theme_econ <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.title.x = element_text(margin = margin(t = 8)),
      axis.title.y = element_text(margin = margin(r = 8)),
      plot.title.position = "plot",
      legend.position = "top",
      legend.title = element_blank()
    )
}


#*******************************************************************************
#----                             R file map                                ----
# 0 Load the waiver data
# 1 Reshape at the county level
#*******************************************************************************


#///////////////////////////////////////////////////////////////////////////////
#----  0 Load the waiver data                                               ----
#///////////////////////////////////////////////////////////////////////////////
# Waiver data ----
  filesave  <- paste(file_path, "/waiver_data_consolidated.csv", sep = "")
  dt <- fread(filesave)
  table(dt$LOC_TYPE)/nrow(dt)*100
  
# Geographies dictionary 2010 ----
  geo = fread('https://www2.census.gov/geo/docs/reference/codes/files/national_county.txt')
  setnames(geo, c("STATE", "STATEFP", "COUNTYFP", "COUNTYNAME", "CLASSFP"))
  
  geo[, STATEFP := sprintf("%02d", as.integer(STATEFP))]
  geo[, COUNTYFP := sprintf("%03d", as.integer(COUNTYFP))]
  geo[, FIPS := paste0(STATEFP, COUNTYFP)]

# Fish cities ------------------------------------------------------------------  
  states = dt[LOC_TYPE %in% c('City', 'Town')]$STATE_ABBREV
  states = unique(states)
  states = states[!is.na(states)]
  cities = places(state = states, year = 2015, cb = TRUE, class = "sf")
  cities = as.data.table(cities)
  
# Notes ------------------------------------------------------------------------
  # Why is entire state yielding above 1 values
  table(dt$ENTIRE_STATE>1)
  # > table(dt$ENTIRE_STATE>1)
  # FALSE  TRUE 
  # 4997    46 
  
  table(dt$ENTIRE_STATE>1, dt$LOC_TYPE)
  
  # Why location state 
  table(dt$ENTIRE_STATE==1, dt$LOC_TYPE != 'State')
  # table(dt$ENTIRE_STATE==1, dt$LOC_TYPE != 'State')
  # FALSE TRUE
  # FALSE     2 4934
  # TRUE     88   18 
  
  # Likely typos from the manual code entry


#///////////////////////////////////////////////////////////////////////////////
#----  1 Reshape geography at county level                                  ----
#///////////////////////////////////////////////////////////////////////////////
# Subset to relevant variables for reshape -------------------------------------
  dt = dt[, `:=`(DATE_START=as.Date(DATE_START),
                 DATE_END=as.Date(DATE_END))]
  dt = dt[,. (YEAR, 
              STATE, 
              STATE_ABBREV, 
              ENTIRE_STATE, 
              LOC, 
              LOC_TYPE, 
              DATE_START, DATE_END, 
              SOURCE_DOC)]
  table(dt$ENTIRE_STATE)
  
# Reshape ----------------------------------------------------------------------
  dt = dt[
    , .(
      MONTH_DATE = seq(from = DATE_START, to = DATE_END, by = "1 month")
    ),
    by = .(STATE, STATE_ABBREV, ENTIRE_STATE, LOC, LOC_TYPE, SOURCE_DOC, DATE_START, DATE_END)
  ]

  dt[, YEAR := year(MONTH_DATE)]

#///////////////////////////////////////////////////////////////////////////////
#----  2 Map FIPS code                                                      ----
#///////////////////////////////////////////////////////////////////////////////
# Manual fixes of typos --------------------------------------------------------
  dt[, LOC := gsub("\\bBiaden\\b", "Bladen", LOC)]
  dt[, LOC := gsub("\\bBighorn\\b", "Big Horn", LOC)]
  dt[, LOC := gsub("\\bCarterel\\b", "Carteret", LOC)]
  dt[, LOC := gsub("\\bCentra Costa\\b", "Contra Costa", LOC)]
  dt[, LOC := gsub("\\bDublin\\b", "Duplin", LOC)]
  dt[, LOC := gsub("\\bFemont\\b", "Fremont", LOC)]
  dt[, LOC := gsub("\\bIona\\b", "Ionia", LOC)]
  dt[, LOC := gsub("\\bLunenberg\\b", "Lunenburg", LOC)]
  dt[, LOC := gsub("\\bMclean\\b", "McLean", LOC)]
  dt[, LOC := gsub("\\bRollette\\b", "Rolette", LOC)]
  dt[, LOC := gsub("\\bTiaga\\b", "Tioga", LOC)]
  dt[, LOC := gsub("\\bUpsher\\b", "Upshur", LOC)]
  dt[, LOC := gsub("\\bWyth\\b", "Wythe", LOC)]
  dt[, LOC := gsub("\\bBaltimore City\\b", "Baltimore", LOC)]
  
  
# Standardize the strings ------------------------------------------------------
  # Waiver data
  dt[, LOC:=tolower(LOC)]
  dt[, LOC:=stringr::str_to_title(LOC)]
  dt[LOC_TYPE == 'County', LOC := paste(LOC, 'County')]
  dt[, LOC := gsub('City County', 'City', LOC)]
  
  # Geographies
  geo[, COUNTYNAME:=tolower(COUNTYNAME)]
  geo[, COUNTYNAME := stringr::str_to_title(COUNTYNAME)]
  geo[, COUNTYNAME := gsub('City County', 'City', COUNTYNAME)]
  
  # Final touches
  dt[LOC == 'Petersburg County' & STATE_ABBREV == 'VA', LOC :='Petersburg City']
  dt[LOC == 'Williamsburg County' & STATE_ABBREV == 'VA', LOC :='Williamsburg City']
  dt[LOC == 'Martinsville County' & STATE_ABBREV == 'VA', LOC :='Martinsville City']

  
# Maping each state to their X_s counties --------------------------------------
  table(dt$ENTIRE_STATE)
  dt_state = dt[ENTIRE_STATE == 1]
  dt_state = merge(dt_state, 
                   geo[,.(STATE, COUNTYNAME, FIPS)], 
                   by.x = 'STATE_ABBREV', 
                   by.y='STATE', 
                   all.x=T,
                   allow.cartesian = T)
  
  dt_state[, LOC := COUNTYNAME]
  dt_state[, LOC_TYPE := 'County']
  mean(is.na(dt_state$LOC))
  
  dt_state$COUNTYNAME = NULL
  
# String match for counties ----------------------------------------------------
  dt_county = dt[LOC_TYPE == 'County']
  
  # Prepare the match (I use this to check what is not matching)
  county_list = unique(dt_county[,.(STATE_ABBREV, LOC)])
  county_list = merge(county_list,
                      geo[,.(STATE, COUNTYNAME, FIPS)],
                      by.x = c('LOC','STATE_ABBREV'),
                      by.y = c('COUNTYNAME', 'STATE'),
                      all.x=T)
  
  # Note: Two counties have no information
  county_list[is.na(FIPS)][,.(LOC, STATE_ABBREV)]
  # 1:     Dickinson County           VA
  # 2: Oglala Lakota County           SD
  
  # Get FIPS for each county
  dt_county = merge(dt_county, 
                    geo[,.(STATE, COUNTYNAME, FIPS)],
                    by.x = c('LOC','STATE_ABBREV'),
                    by.y = c('COUNTYNAME', 'STATE'),
                    all.x=T)

# Work with Towns and Cities 
  dt_city = dt[LOC_TYPE %in% c('City', 'Town')]
  city_list = unique(dt_city[,.(STATE_ABBREV, LOC, LOC_TYPE)])
  

# Plug referenced documents ----------------------------------------------------
  dt = dt[LOC_TYPE != 'County']
  dt = rbind(dt, dt_county, fill = T)
  
  dt = dt[ENTIRE_STATE != 1]
  dt = rbind(dt, dt_state, fill = T)
  
#///////////////////////////////////////////////////////////////////////////////
#----  3 Save                                                               ----
#///////////////////////////////////////////////////////////////////////////////
  new_file = gsub('waiver_data_consolidated', 
                  'waived_data_consolidated_long',
                  filesave)
  fwrite(dt, new_file)