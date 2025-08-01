######################################################
# ETL: SNAP Waivers 

# Inder Majumdar
######################################################

##############
#Config
##############


# Load Packages
library('tidyverse')
library('ellmer')
library('gander')
library('zoo')

# Set the reference model for gander

options(.gander_chat = ellmer::chat_ollama(model = "llama3.2"))

# Set data path
waiver_path = '/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/waivers/panels'

##############
#Load Data
##############

waiver_data <- tibble()

waiver_dir <- dir(waiver_path) 

for (file in waiver_dir) { 
  temp <- readxl::read_excel(paste(waiver_path, file, sep = "/")) #Why isn't this working?
  # waiver_data <- waiver_data %>% 
  #  add_column(file = file, .data = character(1)) }
}



##############
#Scratch - Example to transform data
##############


sample_data_2015 <- readxl::read_excel('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/waivers/panels/2015_ABAWD_waiver.xlsx')

sample_data_2015$DATE_START <- as_date(sample_data_2015$DATE_START)

sample_data_2015$DATE_END <- as_date(sample_data_2015$DATE_END)

# Create a list of all month-year combos included in the data

months_between <- seq(from = as.yearmon(min(sample_data_2015$DATE_START)), to = as.yearmon(max(sample_data_2015$DATE_END)), by = 1/12)

# Create a column for each item in months_between

# Format each month as "Mon_YYYY", e.g., "Jan_2015"
months_between <- format(months_between, "%b_%Y")

# Create one column for each 

for (item in months_between) {
  sample_data_2015[[paste(item)]] <- 0
}

# For each row, construct a months_between list. For each item in the list, flip the corresponding column dummy value to 1.

for (i in 1:nrow(sample_data_2015)) {
  months_between <- format(seq(from = as.yearmon(sample_data_2015$DATE_START[i]), to = as.yearmon(sample_data_2015$DATE_END[i]) , by = 1/12),"%b_%Y")
  
  for (j in 1:length(months_between)) {
    temp <- months_between[j]
    sample_data_2015[i, temp] <- 1
  }
}






