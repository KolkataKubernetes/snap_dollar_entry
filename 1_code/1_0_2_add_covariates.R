
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
waivers   <- read.csv(filesave) |>
  mutate(county_fips = str_pad(as.character(county_fips), width = 5, pad = "0"))

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
  select(YEAR = year, county_fips, wage, wage_st) |>
  mutate(county_fips = str_pad(as.character(county_fips), width = 5, pad = "0"))

# Store Count

store_count <- read_csv('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/SNAP/store_count.csv') |>
  rename('YEAR' = 'year') |>
  mutate(county_fips = str_pad(as.character(county_fips), width = 5, pad = "0"))

# income, rent data

income_rent <- read_csv('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/prices/Prices.csv') |> 
  rename('county_fips' = 'GEOID', 'income' = 'B20002_001E_mean', 'YEAR' = 'year') |>
  select(county_fips, YEAR, income, rent_mean) |>
  mutate(county_fips = str_pad(as.character(county_fips), width = 5, pad = "0"))

# Unemployment

unemployment <- read_csv('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/acs/unemployment.csv') |>
  mutate(county_fips = str_pad(as.character(GEOID), width = 5, pad = "0")) |>
  select(YEAR = year, county_fips, unemployment_rate, snap_rate)

# 1) Wages Merge  --------------------------------------------------------------

waivers |>
  mutate(county_fips = as.character(county_fips)) -> waivers

waivers <- left_join(waivers, wages, by = c('YEAR', 'county_fips'))

waivers |>
  filter(is.na(wage)) |>
  count() # What do we do with these?

# 2) Store count merge  --------------------------------------------------------

supermarket <- c("chain_ingles_markets", 
                  "chain_winn-dixie", 
                  "chain_stop_&_shop", 
                  "chain_albertsons", 
                  "chain_fred_meyer", 
                  "chain_trader_joe_s", 
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
                  "chain_roundys",
                  "chain_roundy_s",
                  "chain_raley_s")

club <- c("chain_costco", 
          "chain_sam_s_club", 
          "chain_bjs")

convenience <- c("chain_seven_eleven", 
                 "chain_circle_k", 
                 "chain_speedway")

multi_category <- c("chain_wal-mart", 
                    "chain_target")

dollar <- c('chain_dollar_general',
            'chain_family_dollar',
            'chain_dollar_tree')

store_count |>
  group_by(county_fips, YEAR) |>
  mutate(chain_type = case_when(
    chain %in% supermarket ~ 'chain_supermarket',
    chain %in% club ~ 'chain_club',
    chain %in% convenience ~ 'chain_convenience', 
    chain %in% multi_category ~ 'chain_multicategory',
    chain %in% dollar ~ 'chain_dollar',
    TRUE ~ 'other'
  )) |>
  ungroup() |>
  group_by(county_fips, YEAR, chain_type) |>
  summarise(total_count = sum(count), .groups = "drop") -> store_type_count

store_type_count |>
  spread(chain_type, total_count) -> store_type_count_wide

waivers <- left_join(waivers, store_type_count_wide, by = c('YEAR', 'county_fips'))

# 3) income, rent merge  -------------------------------------------------------

waivers <- left_join(waivers, income_rent, by = c('YEAR', 'county_fips'))

# 4) unemployment  -------------------------------------------------------

waivers <- left_join(waivers, unemployment, by = c('YEAR', 'county_fips'))


write_csv(waivers, '/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/waivers/waiver_data_long_covariates.csv')


