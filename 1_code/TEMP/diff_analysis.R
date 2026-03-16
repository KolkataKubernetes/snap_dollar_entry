library('tidyverse')

diff <- readRDS('/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/2_processed_data/2_0_waivers/2_0_5_waiver_panel_diff_summary.rds')

table(diff$long_key_comparison['match_flag'])

diff$summary

diff$summary[2,'benchmark_rows'] - diff$summary[2,'generated_rows'] 

diff$long_key_comparison |>
  filter(match_flag == FALSE) |>
  select(STATE) |>
  unique()



### legacy diff

compare_legacy_waiver_long_files_diff$key_comparison |>
  filter(match_flag == 'FALSE') |>
  select(STATE) |>
  unique()
  