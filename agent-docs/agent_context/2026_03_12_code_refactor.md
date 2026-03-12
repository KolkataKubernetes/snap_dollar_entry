# Refactoring the codebase from Legacy to new file structure

- I'd like to refactor the old code for this repo to match the new file structure I have put forth. The old file structure and relevant source materials are found in the "legacy" subfolder.
- I want you to take the source code in @legacy/. and fill in the .R files I have outlined in the main part of the repo.
- Validation is acheived if we can programatically achieve the regression results in @legacy/Box/code/02 - Descriptives & Motivation US.R .
- I want a relative pathing regime, not hardcoded paths. This should be achieved by referencing the filepath txt file in  0_inputs
- I want you make sure each code's preamble and R file map section are filled out based on the code that is written
- It's also important that each code file shares the same commenting/sectioning structure. I wrote the structure for @1_0_0_SNAP_waiver_ingest.R, and want all code to follow that structure. Sections should be delineated by '#(n) section  --------------------------------' etc.
- I have a preference for tidyverse commands over Base R - the code should reflect this. 
- Where I feel comfortable, I've copied in code from the associated source file to aid your efforts.
- After the first few files, I stopped copying code snippets and just referenced the relevant code file in the legacy subfolder - because I think you'd get the point. 
- The script in ~/Research/snap_dollar_entry/legacy/Box/code/02 - Descriptives & Motivation US.R is large and unweildy. Following the format of other scripts, I want you to break out each of the descriptive visual/tables into a set of distinct scripts in 1_1_descriptives, and the regressions into 1_2_reduced_form. You can save intermediate data products using the 2_processed_data root as discussed.

## On outputs for each script.
The following scripts should have their outputs in the processed_data outputs folder: 
- 1_0_0_SNAP_waiver_ingest.R
- 1_0_1_SNAP_retailer_ingest.R
2_processed_data contains a processed root .txt file that should be used to achieve a relative pathing output. I want the processed data to follow a similar naming convention to the input data.


## File-specific targets
- You should look 


## Target Steps
- Learn the new file structure (basically the new file structure not in the legacy subfolder)
- Iterate with me on a spec plan to develop a file-by-file specific refactoring plan
- Clarify an ambiguities with respect to inputs and outputs
- Execute the refactoring plan

# Clarifications: 

  - Which outputs are mandatory to reproduce exactly? Name the specific figures, tables, and regression outputs that define success.
    - Look at the Output inventory below. I want the outputs to be in a 3_outputs/. folder that you create, following the naming convention we have for the file structure (e.g. 3_0_0_table.format)
  - Should we match the legacy script’s numerical results exactly, or is “same substance with explainable differences” acceptable for some outputs?
    - It's important that the regs and descriptives match exactly. These are verified results. The only source of ambiguity that I anticipate is in the manual edits that may have occurred with the waiver panel - you will need to inspect differences manually and see what happened/potentially edit the waiver panel and document what manual edits you did CLEARLY!
  - Is the waiver panel in the legacy workflow based purely on raw source files, or were there manual edits to the consolidated waiver data that we need to preserve?
    - I'm not sure. You'll need to manually check what file was used in 02 - Descriptives & Motivation US.R and make sure the aggregation step from individual years to the across year panel are consistent. You can stop and flag me if you think there are replication issues that aren't strictly fixable through code.
  - What should be the canonical processed intermediate files in the new architecture? In particular, what analysis-ready panel do you want all descriptives and regressions to read from?
    - You'll have to build one and put it in 2_processed_data, making sure the right covariates are added per the script 02 - Descriptives & Motivation US.R.
  - For script splitting, do you want one script per figure/table, or a small number of grouped scripts per topic?
    - Let's start with one figure per table.
  - Should the new pipeline preserve the legacy sample restrictions exactly, including year windows, treated-county definitions, and event-time construction, even if the code structure changes?
    - Yes. We can get more granular later.
  - Where should final outputs live in the new repo structure? Right now the plan assumes processed intermediates under
    2_processed_data and final figures/tables in explicit output folders, but that should be fixed now rather than later.
    - /Users/indermajumdar/Research/snap_dollar_entry/3_outputs.
  - Do you want us to prefer tidyverse rewrites even when the legacy code uses data.table, or should we keep data.table where it is materially clearer or safer?
    - Defualt to tidyverse when cleaner/safer.
  
  # Output Inventory — `02 - Descriptives & Motivation US.R`
  
  ## Figures
  
  ### Workshop Descriptive Figures (always produced)
  
  | # | File Name | Description |
  |---|---|---|
  | 1 | `retailer_format_stock_index.jpeg` | Retailer format stock index (2010=100) for all counties |
  | 2 | `retailer_format_stock_index_rural.jpeg` | Retailer format stock index (2010=100) for rural counties |
  | 3 | `county_conferral_growth_rural_share.jpeg` | Number of counties with ABAWD waivers by year (rural vs urban vs total) |
  | 4 | `06_retail_format_pre_post.jpeg` | Pre/post conferral growth in retail format stock (treated counties, rural vs non-rural) |
  | 5 | `01_ds_stock_trend_by_waiver.jpeg` | Dollar store stock trend by waiver status (ever waived vs never waived counties) |
  
  ### Event Study Figures (only produced if `run_event_study = TRUE`)
  
  | # | File Name | Outcome |
  |---|---|---|
  | 6 | `event_study_ihs_total_ds.pdf` | Event study for dollar stores |
  | 7 | `event_study_ihs_chain_super_market.pdf` | Event study for supermarkets |
  | 8 | `event_study_ihs_chain_convenience_store.pdf` | Event study for convenience stores |
  | 9 | `event_study_ihs_chain_multi_category.pdf` | Event study for multi-category retailers |
  | 10 | `event_study_ihs_chain_medium_grocery.pdf` | Event study for medium grocery |
  | 11 | `event_study_ihs_chain_small_grocery.pdf` | Event study for small grocery |
  | 12 | `event_study_ihs_chain_produce.pdf` | Event study for produce outlets |
  | 13 | `event_study_ihs_chain_farmers_market.pdf` | Event study for farmers markets |
  
  
  ## Tables
  
  ### Event Study Regression Tables
  
  | # | File | Description |
  |---|---|---|
  | 1 | `tables/event_study_ihs_total_ds.tex` | ATT estimates for dollar stores |
  | 2 | `tables/event_study_ihs_chain_super_market.tex` | ATT estimates for supermarkets |
  | 3 | `tables/event_study_ihs_chain_convenience_store.tex` | ATT estimates for convenience stores |
  | 4 | `tables/event_study_ihs_chain_multi_category.tex` | ATT estimates for multi-category retailers |
  | 5 | `tables/event_study_ihs_chain_medium_grocery.tex` | ATT estimates for medium grocery |
  | 6 | `tables/event_study_ihs_chain_small_grocery.tex` | ATT estimates for small grocery |
  | 7 | `tables/event_study_ihs_chain_produce.tex` | ATT estimates for produce outlets |
  | 8 | `tables/event_study_ihs_chain_farmers_market.tex` | ATT estimates for farmers markets |
  
  ### Combined Regression Table
  
  | File | Description |
  |---|---|
  | `tables/event_study_ihs_all.tex` | Combined ATT table for all outcomes |
  
  ### Descriptive Statistics Table
  
  | File | Description |
  |---|---|
  | `tables/desc_stats_outcomes.tex` | Descriptive statistics for retail outlet counts |
  
  
  ## Regressions
  
  All regressions use the same specification:
  
  IHS(y_ct) ~ sunab(eventYear2, year) + population + wage + meanInc + rent + urate | county_fips + year
  
  Estimator: `fixest::feols()`
  
  | # | Outcome Variable | Label |
  |---|---|---|
  | 1 | `total_ds` | Dollar Stores |
  | 2 | `chain_super_market` | Supermarkets |
  | 3 | `chain_convenience_store` | Convenience Stores |
  | 4 | `chain_multi_category` | Multi-category |
  | 5 | `chain_medium_grocery` | Medium Grocery |
  | 6 | `chain_small_grocery` | Small Grocery |
  | 7 | `chain_produce` | Produce |
  | 8 | `chain_farmers_market` | Farmers Markets |
  
  
  # How to name new scripts:
  
- Each root folder is prefixed by a digit, and then each subfolder is similarly prefixed by a digit (digit followed by underscore). For example, population data is '/Users/indermajumdar/Library/CloudStorage/Box-Box/SNAP Dollar Entry/data/0_inputs/0_1_acs/0_1_3_population.csv', which shows the hierarchical naming convention. Follow a similar convention for all processed data and outputs.
- Another example is: /Users/indermajumdar/Research/snap_dollar_entry/1_code/1_0_ingest/1_0_0_SNAP_waiver_ingest.R.
- Processed intermediates should be .rds files.
