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
