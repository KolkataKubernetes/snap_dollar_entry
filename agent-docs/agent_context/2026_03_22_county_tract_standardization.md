# Standardizing the waiver pipeline to ensure cohesion between county and census tract level analysis
- In /Users/indermajumdar/Research/snap_dollar_entry/agent-docs/execplans/2026-03-19-waiver-geographies-execplan.md, we disaggregated our analysis to the census tract level and replicated the waiver/treatment assignment process at the census tract level. In doing this, we made a few key design decisions that may differ from the county level:
  - We narrowed the scope to include only the 48 contiguous US states and Washington D.C.
  - We ended the panel at 2019 inclusive, since 2020 requires a new vintage of census tract maps
  - We allowed ACS covariates to vary over time - in prior work, we only took the 2010 vintage of the 5 year ACS estimates. At the census tract level, we chose each ACS vintage year to match the panel year, using 5 year estimates.
  - There was an informal trick used to try and drop treated units that were first treated between 2010 and 2013, but that trick was unnecessary since in the reduced form we only filter on years between 2014 and 2019.
- my understanding is that we implemented the four above changes in the previous execplan from 3/19, but these changes have not yet been made at the county level.

## Planning phase
- First, confirm the status of each of the four differences above. Put differently, I'd like to confirm that the 4 changes outlined above have not been completed at the county level, but indeed have been completed at the census tract level
- Then, build a spec plan that details the exact files we will need to change and what changes will be made ONLY to ensure the above 4 are implemented.
## Execution
- Execution will be completed in four milestones, with each milestone aligning with one of the four changes listed above. My preference is the following setup (you may want to choose different names to ensure easier communication)
- Milestone 1: end the panel at 2019 inclusive, since 2020 requires a new vintage of census tract maps
- Milestone 2: There was an informal trick used to try and drop treated units that were first treated between 2010 and 2013, but that trick was unnecessary since in the reduced form we only filter on years between 2014 and 2019. Remove taht trick in the milestone, similar to how we did at the census tract level. 
- Milestone 3: Narrow the scope to include only the 48 contiguous US states and Washington D.C.
- Milestone 4: allow ACS covariates to vary over time using the same data sources as the census tract level (each ACS vintage matches the year of the observation)

## General Notes
- Logical changes to the code should ONLY mirror the above changes. We should not take other shortcuts or make other logical changes to the code - only the ones listed above - without explicit approval.
- I am making the above point explicit because this specific patch will be tricky to verify using outputs alone. At the end of milestones 1 + 2, there should be no change to the reduced form results. But milestone 3 and 4 will each create at least slight shifts in the estimation outcomes, which means we will have to be demanding about not changing the logical flow of other parts of the code.
