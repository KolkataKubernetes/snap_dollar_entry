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

# Set the reference model for gander

options(.gander_chat = ellmer::chat_openai(model = "gpt-4o-mini"))

# Set data path
waiver_path = '/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/waivers/panels'


##############
#Load Data
##############

paste(waiver_path,'2013_ABAWD_waiver.xlsx', sep = '/')


##############
#Scratch - Example to transform data
##############

sample_data_2015 <- read_csv(paste(waiver_path,'2015_ABAWD_waiver.xslx', sep = '/'))

sample_data_2015 <- readxl::read_excel('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/waivers/panels/2015_ABAWD_waiver.xlsx')

sample_data_2015$DATE_START <- as_date(sample_data_2015$DATE_START)

sample_data_2015$DATE_END <- as_date(sample_data_2015$DATE_END)

months_between <- min(sample_data_2015$DATE_START):max(sample_data_2015$DATE_END)














