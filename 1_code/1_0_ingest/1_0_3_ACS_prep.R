#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_3_ACS_prep.R
# Previous author:  Alejandro Herrera
# Current author:   Alejandro Herrera + Codex
# Last Updated:     March 16, 2026
# Description:      Promote the benchmark ACS and population inputs into the
#                   processed ingest layout.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `0_1_acs/0_1_2_acs_2012_2020.csv`
#                   `0_1_acs/0_1_3_population.csv`
#                   `0_1_acs/0_1_4_Append_CountyDP03.rds`
#                   `0_1_acs/0_1_5_Append_CountyDP04.rds`
# OUTPUTS:          `2_1_acs/2_1_1_acs_2012_2020.rds`
#                   `2_1_acs/2_1_2_population.rds`
#                   `2_1_acs/2_1_3_Append_CountyDP03.rds`
#                   `2_1_acs/2_1_4_Append_CountyDP04.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file:
# - legacy/Box/code/00 - Prepping ACS .R

library(readr)

source("1_code/shared_ingest_helpers.R")

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

acs_input_dir <- file.path(input_root, "0_1_acs")
acs_output_dir <- ensure_dir(file.path(processed_root, "2_1_acs"))

acs_panel <- readr::read_csv(file.path(acs_input_dir, "0_1_2_acs_2012_2020.csv"), show_col_types = FALSE)
population_panel <- readr::read_csv(file.path(acs_input_dir, "0_1_3_population.csv"), show_col_types = FALSE)
acs03_panel <- readRDS(file.path(acs_input_dir, "0_1_4_Append_CountyDP03.rds"))
acs04_panel <- readRDS(file.path(acs_input_dir, "0_1_5_Append_CountyDP04.rds"))

saveRDS(acs_panel, file.path(acs_output_dir, "2_1_1_acs_2012_2020.rds"))
saveRDS(population_panel, file.path(acs_output_dir, "2_1_2_population.rds"))
saveRDS(acs03_panel, file.path(acs_output_dir, "2_1_3_Append_CountyDP03.rds"))
saveRDS(acs04_panel, file.path(acs_output_dir, "2_1_4_Append_CountyDP04.rds"))

message(sprintf("Saved ACS ingest outputs to %s", acs_output_dir))
