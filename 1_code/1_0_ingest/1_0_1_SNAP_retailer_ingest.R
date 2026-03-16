#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_1_SNAP_retailer_ingest.R
# Previous author:  Alejandro Herrera
# Current author:   Alejandro Herrera + Codex
# Last Updated:     March 16, 2026
# Description:      Clean SNAP retailer data and build the county-year store
#                   count panel used by the benchmark analysis.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `0_5_SNAP/0_5_2_Historical SNAP Retailer Locator Data-20231231.csv`
#                   `0_3_county_list/0_3_uscounties.csv`
# OUTPUTS:          `2_5_SNAP/2_5_0_snap_clean.rds`
#                   `2_5_SNAP/2_5_1_store_count.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file:
# - legacy/Box/code/00 - Cleaning SNAP.R

library(data.table)
library(lubridate)
library(readr)
library(stringr)

source("1_code/shared_ingest_helpers.R")

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

snap_path <- file.path(input_root, "0_5_SNAP", "0_5_2_Historical SNAP Retailer Locator Data-20231231.csv")
county_path <- file.path(input_root, "0_3_county_list", "0_3_uscounties.csv")
snap_output_dir <- ensure_dir(file.path(processed_root, "2_5_SNAP"))

store_patterns <- c(
  "dollar general" = "dollar general",
  "dollar tree" = "dollar tree",
  "family dollar" = "family dollar",
  "7-eleven" = "seven eleven",
  "circle k" = "circle k",
  "speedway" = "speedway",
  "albertsons" = "albertsons",
  "aldi" = "aldi",
  "bashas markets" = "bashas markets",
  "delhaize america" = "delhaize america",
  "fred meyer" = "fred meyer",
  "giant eagle" = "giant eagle",
  "giant food" = "giant food",
  "great a & p tea co" = "great a & p tea co",
  "he butt" = "he butt",
  "hannaford bros" = "hannaford bros",
  "hy vee food stores" = "hy vee food stores",
  "ingles markets" = "ingles markets",
  "kroger" = "kroger",
  "lone star funds" = "lone star funds",
  "publix" = "publix",
  "raley's" = "raley's",
  "roundy's" = "roundy's",
  "ruddick corp" = "ruddick corp",
  "safeway" = "safeway",
  "save a lot" = "save a lot",
  "save mart" = "save mart",
  "smart & final" = "smart & final",
  "stater bros" = "stater bros",
  "stop & shop" = "stop & shop",
  "supervalu" = "supervalu",
  "trader joe's" = "trader joe's",
  "weis markets" = "weis markets",
  "whole foods" = "whole foods",
  "wild oats" = "wild oats",
  "winn-dixie" = "winn-dixie",
  "meijer" = "meijer",
  "target" = "target",
  "wal.*mart" = "wal-mart",
  "bj's" = "bj's",
  "costco" = "costco",
  "sam's club" = "sam's club"
)

snap <- data.table::fread(snap_path, encoding = "UTF-8")
county <- data.table::fread(county_path)

snap[, `Store Name` := str_to_lower(trimws(`Store Name`))]
snap[, chain := "placeholder"]

for (pattern in names(store_patterns)) {
  snap[grepl(pattern, `Store Name`, ignore.case = TRUE), chain := store_patterns[[pattern]]]
}

snap[`Store Type` == "Convenience Store" & chain == "placeholder", chain := "convenience_store"]
snap[`Store Type` == "Supermarket" & chain == "placeholder", chain := "super_market"]
snap[`Store Type` == "Farmers' Market" & chain == "placeholder", chain := "farmers_market"]
snap[`Store Type` == "Large Grocery Store" & chain == "placeholder", chain := "large_grocery"]
snap[`Store Type` == "Medium Grocery Store" & chain == "placeholder", chain := "medium_grocery"]
snap[`Store Type` == "Small Grocery Store" & chain == "placeholder", chain := "small_grocery"]
snap[`Store Type` == "Fruits/Veg Specialty" & chain == "placeholder", chain := "produce"]

snap[, dollarStore := grepl("(dollar tree|dollar general|family dollar)", `Store Name`)]
snap[, chain := paste0("chain_", chain)]
snap[, chain := gsub("[' ]", "_", chain)]
snap <- snap[chain != "chain_placeholder"]

county[, county := toupper(county)]
county[, keep := .N == 1, by = .(county, state_id)]
county <- county[keep == TRUE, .(county, state_id, county_fips)]

snap <- merge(
  snap,
  county[, .(County = county, State = state_id, county_fips)],
  by = c("County", "State"),
  all.x = TRUE
)

snap[, county_fips := normalize_fips(county_fips)]
snap[, `Authorization Date` := as.Date(`Authorization Date`, format = "%m/%d/%Y")]
snap[, `End Date` := as.Date(`End Date`, format = "%m/%d/%Y")]
snap[, authorization_year := year(`Authorization Date`)]
snap[, end_year := year(`End Date`)]
snap[is.na(end_year), end_year := 2024L]
snap[, store_row_id := .I]

store_count <- snap[
  !is.na(county_fips) & !is.na(authorization_year) & !is.na(end_year),
  .(year = seq.int(authorization_year[[1]], end_year[[1]])),
  by = .(store_row_id, county_fips, chain)
][
  ,
  .(count = .N),
  by = .(county_fips, chain, year)
]

snap[, store_row_id := NULL]

saveRDS(tibble::as_tibble(snap), file.path(snap_output_dir, "2_5_0_snap_clean.rds"))
saveRDS(tibble::as_tibble(store_count), file.path(snap_output_dir, "2_5_1_store_count.rds"))

message(sprintf("Saved SNAP ingest outputs to %s", snap_output_dir))
