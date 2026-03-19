# How to geocode SNAP Waivers?

- Time horizon is between 2010 and 2020. Use the 2010 Census tract definitions, and 2010 FIPS codes.
- I've included all of the geographies you would need in the inputs folder (URL is in input_root.txt). Some of them are Zipped so you'll need to handle that accordingly.
  - Also take care to follow the correct naming convention that we've already set up across the file system
- s
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
- City: Belongs to either County Subdivision or Places. VT, AZ, CO, MA, PA, WA, RI, NY, and VA all have waivers assigned at the city level; all of them exept for VT have cities counted as places, whereas VT has it as county subdivision. Rhode Island looks like it's town designations are either in the County Subdivision or Places file. For Rhode Island, unclear - need help.
- Reservation Areas: American Indian Areas in the census.
- Reservation: See Reservation Area
- Town: County subdivision
