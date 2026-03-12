#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_0_SNAP_waiver_ingest.R
# Previous author:  -
# Current author:   Inder Majumdar + Codex
# Last Updated:    March 12, 2026
# Description:     Consolidate year-state CSV files into one large file for further analysis
## INPUTS:
## PROCEDURES: 
## OUTPUTS: 
#///////////////////////////////////////////////////////////////////////////////

# Reference file: ~/Research/snap_dollar_entry/legacy/1_code/1_0_0_SNAP_waiver_ingest.R

# An open question: Does this code generate the actual file that's used as an input for our analysis? There's a chance that either Alejandro 
# or I made manual edits to the consolidated waiver panel, and I don't know if that's what is being used in our reduced form analysis

# Setup ------------------------------------------------------------------------
# Load Packages
library('tidyverse')
library('zoo')


# Set data path

waiver_path = '/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/waivers/panels'

# Load Data

waiver_data <- tibble()

waiver_dir <- dir(waiver_path) 

for (file in waiver_dir) { 
  temp <- readxl::read_excel(paste(waiver_path, file, sep = "/")) 
  waiver_data <- rbind(waiver_data, temp)
}

rm(temp)

# (1) Transform Waivers in to "wide" format by date --------------------------------

waiver_data$DATE_START <- as_date(waiver_data$DATE_START)

waiver_data$DATE_END <- as_date(waiver_data$DATE_END)

# Drop NA rows for Date Start
waiver_data <- drop_na(waiver_data, DATE_START)

#Create a list of all month-year combos included in the data

months_between <- format(seq(from = as.yearmon(min(waiver_data$DATE_START)), to = as.yearmon(max(waiver_data$DATE_END)), by = 1/12), "%b_%Y")

# Create columns for each month between

for (item in months_between) {
  waiver_data[[paste(item)]] <- 0
}

# Fill columns based on dates data

for (i in 1:nrow(waiver_data)) {
  # Pull month-year sequence for each row
  months_between <- format(seq(from = as.yearmon(waiver_data$DATE_START[i]), to = as.yearmon(waiver_data$DATE_END[i]) , by = 1/12),"%b_%Y")
  for (j in 1:length(months_between)) {
    temp <- months_between[j]
    waiver_data[i, temp] <- 1
  }
}

rm(i,j,temp,item,months_between)

# (2) Save Waiver Data  --------------------------------

# (3) Clear Workspace  --------------------------------

rm(file, file_path, filesave, waiver_dir,waiver_path,waiver_data)





