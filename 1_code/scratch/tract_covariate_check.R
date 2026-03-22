#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        tract_covariate_check.R
# current author:  Inder Majumdar
# Last Updated:     March 21, 2026
# Description:      Basic data audit to ensure covariate coverage.
# INPUTS:           `2_9_4_us_analysis_panel_tract.rds'
# OUTPUTS:          None.
#///////////////////////////////////////////////////////////////////////////////

covariates_tract <- readRDS('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/2_processed_data/2_9_analysis/2_9_4_us_analysis_panel_tract.rds')

panel_tract_summary <- readRDS('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/2_processed_data/2_9_analysis/2_9_5_us_analysis_panel_tract_summary.rds')

acs_tract_match_summary <- readRDS('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/2_processed_data/2_1_acs/2_1_10_acs_tract_2010_2020_match_summary.rds')



# What's driving the county-level discrepency? 
library(tidyverse)
acs_tract_raw <- readRDS("/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/2_processed_data/2_1_acs/2_1_8_acs_tract_2010_2020_raw.rds")

## First confirm that year = ACS source year

acs_tract_raw |>
  mutate(yearcheck = year == acs_source_year) |>
  filter(yearcheck == FALSE)
### Good. 

## Where has the join failed? By year, state

acs_tract_raw |> 
  filter(is.na(GEOID), year %in% 2011:2019) |> 
  count(year, sort = FALSE)

acs_tract_raw |>
  filter(is.na(GEOID), year %in% 2011:2019) |>
  count(state_abbrev, year)

## Identify specific mismatches at the county level
acs_tract_raw |>
  filter(is.na(GEOID), year %in% 2011:2019) |>
  distinct(tract_fips, county_fips, state_abbrev) |>
  arrange(state_abbrev, county_fips, tract_fips) |>
  count(county_fips, state_abbrev)


## Audit this across years

acs_tract_raw |>
  filter(county_fips == "36065", year %in% 2011:2019) |>
  select(year, tract_fips, GEOID, NAME) |>
  arrange(year, tract_fips) |>
  filter(is.na(GEOID))


## Classify unmatched tract codes across years

acs_tract_raw |>
  filter(is.na(GEOID), year %in% 2011:2019) |>
  distinct(tract_fips, county_fips, state_abbrev) |>
  mutate(
    tract_code = stringr::str_sub(tract_fips, 6, 11),
    tract_class = case_when(
      stringr::str_detect(tract_code, "^94") ~ "94xx_ai_area_associated",
      stringr::str_detect(tract_code, "^98") ~ "98xx_special_land_use",
      stringr::str_detect(tract_code, "^99") ~ "99xx_water",
      TRUE ~ "other"
    )
  ) |>
  count(tract_class, sort = TRUE)

acs_tract_raw |>
  filter(is.na(GEOID), year %in% 2011:2019) |>
  distinct(tract_fips, county_fips, state_abbrev) |>
  mutate(
    tract_code = stringr::str_sub(tract_fips, 6, 11),
    tract_class = case_when(
      stringr::str_detect(tract_code, "^94") ~ "94xx_ai_area_associated",
      stringr::str_detect(tract_code, "^98") ~ "98xx_special_land_use",
      stringr::str_detect(tract_code, "^99") ~ "99xx_water",
      TRUE ~ "other"
    )
  ) |>
  arrange(tract_class, state_abbrev, county_fips, tract_fips)


## Classify unmatched tract codes across years

acs_tract_raw |>
  filter(is.na(GEOID), year %in% 2011:2019) |>
  distinct(tract_fips, county_fips, state_abbrev) |>
  mutate(
    tract_code = stringr::str_sub(tract_fips, 6, 11),
    tract_class = case_when(
      stringr::str_detect(tract_code, "^94") ~ "94xx_ai_area_associated",
      stringr::str_detect(tract_code, "^98") ~ "98xx_special_land_use",
      stringr::str_detect(tract_code, "^99") ~ "99xx_water",
      TRUE ~ "other"
    )
  ) |>
  filter(tract_class == "other")




  
