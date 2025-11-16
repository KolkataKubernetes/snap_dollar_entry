
#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_0_SNAP_waiver_ingest.R
# Previous author:  -
# Current author:   Inder Majumdar
# Last Updated:    November 16, 2025
# Description:     Consolidate year-state CSV files into one large file for further analysis
#
# Change log:       
#///////////////////////////////////////////////////////////////////////////////


# Setup ------------------------------------------------------------------------

# Load Packages
library('tidyverse')
library('ellmer')
library('gander')
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


# Data check: Is ENTIRE_STATE == 1 OR 0?

waiver_data |>
  filter(ENTIRE_STATE > 1) |>
  select(YEAR, STATE) |>
  unique()


# Transform Waivers in to "long" format by date --------------------------------

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

# Save waiver data 

file_path <- readLines("2_processed_data/processed_path.txt")[1]

filesave <- paste(file_path, "/waiver_data_consolidated.csv", sep = "")

write_csv(waiver_data, filesave)

