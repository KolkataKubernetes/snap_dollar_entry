#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        snap_retailer_check.R
# current author:  Inder Majumdar
# Last Updated:     March 21, 2026
# Description:      Basic data audits to ensure that all SNAP retailers have been matched to a census tract
# INPUTS:           `2_5_2_snap_clean_with_tracts.rds'
# OUTPUTS:          None.
#///////////////////////////////////////////////////////////////////////////////


# Data audit: check SNAP retailer to census tract mapping

library('tidyverse')

## Data

snap_clean_with_tracts <- readRDS('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/2_processed_data/2_5_SNAP/2_5_2_snap_clean_with_tracts.rds')

## Diagnostics

diagnose <- readRDS('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/2_processed_data/2_5_SNAP/2_5_4_snap_tract_match_diagnostics.rds')


## Confirm that the only ignored FIPS is in GUAM
snap_clean_with_tracts |>
  filter(ignored_fips == TRUE) |>
  count(state_fips_original, sort = TRUE)

### But how am I getting 31,000 rows here? Are there other State FIPS I'm not picking up on? 
table(diagnose$out_of_scope_rows)

snap_clean_with_tracts |>
  mutate(
    out_reason = case_when(
      ignored_fips ~ "ignored_fips",
      !in_scope & is.na(county_fips_original) ~ "missing_county_fips_original",
      !in_scope ~ "county_not_in_scope",
      TRUE ~ "in_scope"
    )
  ) |>
  filter(out_reason != 'in_scope') |>
  count(out_reason, state_fips_original, State, County, sort = TRUE) |>
  summarise(sum = sum(n))


## How many SNAP retailers have tract-implied counties that mismatch the county explicitly listed in the SNAP retailer panel?

snap_clean_with_tracts |>
  filter(county_fips_match == FALSE) |>
  summarise(count = n())






