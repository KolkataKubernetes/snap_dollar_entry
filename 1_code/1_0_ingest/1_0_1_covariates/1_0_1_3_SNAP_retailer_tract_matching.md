# SNAP Retailer to Census Tract Matching

This note documents how `1_0_1_3_SNAP_retailer_tract_panel.R` assigns the cleaned SNAP retailer panel to 2010 Census tracts.

It is an implementation note for maintainers. The script remains the source of truth.

## Inputs

- `2_5_SNAP/2_5_0_snap_clean.rds`
- `0_inputs/input_root.txt`
- `2_processed_data/processed_root.txt`
- local tract shapefiles under `0_8_geographies/`
- `0_3_county_list/national_county.txt`

## Upstream Context

`2_5_0_snap_clean.rds` comes from `1_0_1_0_SNAP_retailer_ingest.R`.

That upstream script already:

- cleans retailer names and store types
- derives retailer chain labels
- attempts to append `county_fips` by string-matching SNAP `County` and `State` against `national_county.txt`
- preserves `Latitude` and `Longitude`

The tract script does not geocode addresses. It uses the existing point coordinates.

## Tract Universe

The tract universe is loaded through `tract_ingest_helpers.R`.

That helper:

- reads the benchmark county analysis panel
- builds the county scope from the panel's `county_fips`
- loads only the 2010 tract shapefiles needed for that scope

This means tract assignment is done against the benchmark county-analysis geography, not against an ad hoc national tract file assembled inside the retailer script.

## Current Matching Hierarchy

The current tract assignment logic is state-first and spatial-first.

### Step 1: Validate the retailer state label

The script reads `national_county.txt` and extracts a state lookup from its first two columns:

- `state_abbrev`
- `state_fips`

For each retailer row, the script standardizes `State` and tries to match it to that lookup.

This creates:

- `state_abbrev_original`
- `state_fips_validated`
- `state_label_match`

Rows without a valid state match are not sent through the tract matcher.

### Step 2: Apply explicit territory exclusions

The tract branch ignores state FIPS:

- `60`
- `66`
- `69`
- `72`
- `78`

If `state_fips_validated` is one of those codes, the row is marked `ignored_fips = TRUE` and is excluded from tract assignment.

### Step 3: Define in-scope rows for the tract matcher

A retailer row is currently considered in scope when:

- its state label matches the state lookup
- the validated state is present in the tract universe loaded from the benchmark county panel
- it is not one of the ignored territory FIPS

This is different from the first Milestone 1 pass, which used the upstream derived `county_fips` as the gate into scope.

### Step 4: Restrict the first spatial join to the validated state

The script runs the tract intersection state by state.

For a given retailer row:

- the validated `state_fips` determines which tract layer is searched
- the point is converted to `sf` from `Longitude` and `Latitude`
- the point is joined to that state's tract polygons using `st_intersects`

If the point intersects more than one tract, the script keeps one deterministic tract assignment by sorting on `tract_fips` and taking the first row for that store.

These direct assignments receive:

- `assignment_rule = "point_in_polygon"`

### Step 5: Run nearest-tract fallback when direct intersection fails

If a store point does not intersect a tract directly, the script falls back to nearest-tract assignment within the validated state.

The fallback target is always a tract, not a county.

The county only affects which candidate tract set is searched.

Fallback logic:

1. If `county_fips_original` exists from the upstream county string match, search only tracts in that county.
2. If `county_fips_original` is missing, search all tracts in the validated state.

Fallback assignments receive:

- `assignment_rule = "nearest_tract_fallback"`

## Key Output Columns

The main store-level artifact is `2_5_2_snap_clean_with_tracts.rds`.

Important geography fields:

- `county_fips_original`: county FIPS carried from the upstream retailer ingest, if the `County`/`State` string match succeeded
- `state_fips_original`: state FIPS implied by `county_fips_original`
- `state_abbrev_original`: cleaned retailer `State`
- `state_fips_validated`: state FIPS obtained from the state lookup in `national_county.txt`
- `state_label_match`: whether the retailer `State` matched the lookup
- `ignored_fips`: whether the validated state is one of the excluded territory codes
- `in_scope`: whether the row is eligible for tract assignment under the tract matcher
- `tract_fips`: assigned 2010 tract FIPS
- `county_fips`: county prefix implied by the assigned tract if a tract was assigned; otherwise the upstream county FIPS when present
- `assignment_rule`: `point_in_polygon` or `nearest_tract_fallback`
- `state_fips_match`: whether the assigned tract's state matches the validated retailer state
- `county_fips_match`: whether the assigned tract's county matches the upstream county FIPS when the upstream county match exists

## Diagnostics

The summary artifact is `2_5_4_snap_tract_match_diagnostics.rds`.

Current top-line fields include:

- `state_label_matched_rows`
- `state_label_unmatched_rows`
- `ignored_fips_rows`
- `scope_rows`
- `matched_rows`
- `point_in_polygon_rows`
- `fallback_rows`
- `out_of_scope_rows`
- `state_mismatch_rows`
- `county_mismatch_rows`
- `unexpected_unmatched_rows`
- `assigned_missing_county_fips_rows`

Interpretation:

- `out_of_scope_rows` now reflects rows that failed state validation or were intentionally excluded as ignored territories
- `assigned_missing_county_fips_rows` counts rows that still received tract assignments even though the upstream county string match failed
- `county_mismatch_rows` only counts mismatches for rows where an upstream county FIPS exists

## Why the State-First Revision Was Added

The first Milestone 1 tract version used `county_fips_original` as a gate into tract scope.

That created many artificial out-of-scope rows because the upstream county match is based on exact string matching against `national_county.txt`. Rows with valid coordinates but missing upstream county FIPS never reached the tract matcher.

The current state-first version fixes that by:

- validating `State` separately from county matching
- using coordinates for the first tract assignment pass
- retaining the county match only as a fallback aid and diagnostic

## Remaining Audit Questions

The script is now materially better aligned with the tract design, but two audit areas remain important:

- fallback dependence: a large share of rows still require nearest-tract fallback
- county mismatches: some assigned tracts still disagree with the upstream county string match

The relevant artifacts for auditing those issues are:

- `2_5_2_snap_clean_with_tracts.rds`
- `2_5_3_store_count_tract.rds`
- `2_5_4_snap_tract_match_diagnostics.rds`
- `2_9_3_us_analysis_panel_tract_pre_covariates.rds`
