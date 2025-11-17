
#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_2_add_covariates.R
# Previous author:  -
# Current author:   Inder Majumdar
# Last Updated:    November 16, 2025
# Description: Add Covariates to the narrowed panel from 1_0_1
#
# Change log:       
#///////////////////////////////////////////////////////////////////////////////



# Load Packages
library(tidyverse)
library(stringr)
library(purrr)
library(scales)
library(zoo)


# Set data path
file_path <- readLines("2_processed_data/processed_path.txt")[1]
filesave  <- paste(file_path, "/waiver_data_long.csv", sep = "")
waivers   <- read.csv(filesave)

# Shared helper

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

# Wage Data

wages <- read_csv('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/prices/Wages_V2.csv') |>
  select(YEAR = year, county_fips, wage, wage_st)

# Store Count

store_count <- read_csv('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/SNAP/store_count.csv') |>
  rename('YEAR' = 'year')

# Snap Clean

# 

# 1) Wages Merge  --------------------------------------------------------------

waivers |>
  mutate(county_fips = as.character(county_fips)) -> waivers

waivers <- left_join(waivers, wages, by = c('YEAR', 'county_fips'))

waivers |>
  filter(is.na(wage)) |>
  count() # What do we do with these?

# 2) Store count merge  --------------------------------------------------------

supermarkets <- c("chain_ingles_markets", 
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
                  "chain_roundys")
club <- c("chain_costco", 
          "chain_sams_club", 
          "chain_bjs")



