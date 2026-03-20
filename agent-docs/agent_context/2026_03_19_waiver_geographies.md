# How to geocode SNAP Waivers?
- I'd like to geocode SNAP Waiver conferral at the census tract level. The idea here is to replicate our current analysis and descriptives, but have the unit of analysis be census tract and not coounty.
- I would like to build out our exact pipeline as closely as possible to what we have in the code pipeline, but have two different sets of reduced form and descriptive outcomes - one for the county level and one for the census tract level.
   - Take care to follow the correct naming convention that we've already set up across the file system. The number prefixes should match such that I'm able to make "apples to apples" comparisons between the county and census tract level descriptives.
- I've included all of the geography shapefiles you would need in the inputs folder (URL is in input_root.txt). To complete, this, I manually went through the SNAP waiver consolidated long RDS and verified the geographies that we would need using the loc_type denomination, and how to convert them to census tract. A few notes on implementation:  
  - Some of them are Zipped so you'll need to handle unzipping accordingly.
  - There's a chance that I missed a loc_type when pulling together the data. If this is the case, please let me know and call out the issue accordingly in the planning phase.
  - I'd like execution to be broken into two steps. First, let's build out the full analysis panel pre-covariate at the census tract level, and confirm that no waiver conferrals have been dropped. Obviously we expect the number of rows in the census tract full analysis panel will be larger than the initial ingest and county-level waiver full analysis panel.
  - The second step should be then to match covariates at the census tract level and confirm that we obtain a complete match. Since we want to match at the census tract level, we'll want to download the covariates such that we can match covariate values to the census tract level.
  - We will use tidycensus to pull tract-level ACS 5-year estimates for 2010. To match the county-level Sun-Abraham specification, tract-level controls should be:
    - meanInc: DP03_0063E (mean household income)
    - urate: B23025_005E / B23025_003E
    - population: B11001_001E. Document explicitly that this matches the incumbent county pipeline’s population field, which is actually total households rather than total population.
    - rent: 12 * B25062_001E / B25061_001E
    - wage: use the incumbent county-level wage object from the census pipeline
    - we also need to carry forward the county pipeline’s unused income field for parity, use: income: B20002_001E
    - Note that in the county-level regressions, it looks like we used DP03_0063E. I'd like us to replace that at the census tract level by defining mean household earnings as B20003_001E/B20003_002E, but that is something we should narrow down in planning.

## Geography types are:
- County: Identify census tract using State x County FIPS code combination
- Boro: Pennsylvania only ("Borough").Census Places -> Census Tract (1st stab: Shapefile intersect)
- Plantation: Maine only: US Census County Subdivision 
- Unorganized: Maine only: County subdivision
- LMA: MAine only. Geospatial intersect/ -  https://maine.hub.arcgis.com/datasets/maine::maine-labor-market-areas/explore?location=45.214270%2C-69.006134%2C7
- Community District: NY only. https://hub.arcgis.com/datasets/DCP::nyc-community-districts/about
- Borough: Pennsylvania only. See Boro
- Township: Pennsylvania only. Census County subdivision.
- County/Town: Nantucket, MA only. It's referred to as a Town and County. Just use the State x County FIPS code
- State: State FIPS code.
- Metropolitan Division: Philadelphia, PA only. BLS states that the Philadelphia division consists of Bucks, Chester, Delaware, Montgomery, and Philadelphia Counties only (https://www.bls.gov/regions/mid-atlantic/data/xg-tables/ro3fx9527.htm?utm_source=chatgpt.com).
- Other: Need to really clean this up.
    - OTHER: Only applies to Philadelphia Metropolitan Division. 
    - Other: This is a borough. See instructions for "Boro".
- NECTA: NECTAs are built from towns, which are census designated places. So I want to create a NECTA delineation file, which maps each NECTA to a set of towns. Towns are county subdivisions. I can then use census block -> county subdivision mappings to then build population weighted census tract definitions (?). "Check Metropolitan And Micropolitan Statistical Areas And Related Statistical Areas" census files?
- Island: Hawaii only. Remove 
- Borough and Census Area: Alaska only. Remove
- Native Village Statistical Area: Alaska only. Remove
- City: Belongs to either County Subdivision or Places. VT, AZ, CO, MA, PA, WA, RI, NY, and VA all have waivers assigned at the city level; all of them exept for VT have cities counted as places, whereas VT has it as county subdivision. Rhode Island looks like it's town designations are either in the County Subdivision or Places file. For Rhode Island, unclear - need help where you should verify which we need to use Places or County Subdivision for Rhode Island ONLY.
- Reservation Areas: American Indian Areas in the census.
- Reservation: See Reservation Area
- Town: County subdivision
- All geography files are in 0_8_geographies.

## Validation Criteria
- It's important that every waiver be geospatially matched, and no waiver conferral gets dropped
- It's also important that every covariate matches at the census tract level, except for the ones that we match intentionally at the county level.
  - 5 digit FIPS codes for the county level and 11 digit FIPS codes at the census tract level should be used to conduct all matches.
## Design notes
- I'd like to have the county and census panel building scripts built seperately to avoid any issues with 
- If you are going to edit any scripts that already exist, make sure you comment the additions so we know explicitly what changes were made any why they were made. 
- I prefer readable and transparent code to efficiency gains that potentially interfere with readability.
- For calculated covariate fields, I want you to make sure to include the fields used for those calculations as covariates
- Some of the geography matching will require geospatial intersections. Use R's SF package to get this done. And make sure you specifiy an appropriate CRS that doesn't distort area intersections - and propose the one that will be ussed during the planning phase.
- Where possible, I include the URL links for each geography for you to verify provenance. But I have already downloaded the shapefiles so you don't need to waste time doing that.
- An open ambiguity I have is whether to use DP03_0063E for mean household income. Can you check if that's available for 2010 at the census tract level?
