
#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_3_add_treatment_stability.R
# Previous author:  -
# Current author:   Inder Majumdar
# Last Updated:    November 17, 2025
# Description: 
#
# Change log:       
#///////////////////////////////////////////////////////////////////////////////



# Load Packages
library(tidyverse)
library(stringr)
library(purrr)
library(scales)
library(zoo)


# Set data path
file_path <- readLines("2_processed_data/processed_path.txt")[1]
filesave  <- paste(file_path, "/waiver_data_long_covariates.csv", sep = "")
waivers   <- read.csv(filesave) |>
  mutate(county_fips = str_pad(as.character(county_fips), width = 5, pad = "0"))

# Shared helper

theme_econ <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.title.x = element_text(margin = margin(t = 8)),
      axis.title.y = element_text(margin = margin(r = 8)),
      plot.title.position = "plot",
      legend.position = "top",
      legend.title = element_blank()
    )
}

# 1) Identify first treatment year  --------------------------------------------------------------

first_treat <- waivers |>
  group_by(county_fips) |>
  summarise(
    t0 = min(YEAR[waiver == 1], na.rm = TRUE), .groups = "drop"
  )


waivers <- waivers |> left_join(first_treat, by = "county_fips")

# 2) Test for treatment turn-off  --------------------------------------------------------------

treatment_stability <- waivers |>
  group_by(county_fips) |>
  summarise(
    t0 = unique(t0),
    ever_reverted = any(waiver == 0 & YEAR > t0),
    .groups = "drop"
  )

table(treatment_stability$ever_reverted)


# 3) Pull FIPS Codes for stable treatments  --------------------------------------------------------------

stable_counties <- treatment_stability |>
  filter(!ever_reverted) |>
  pull(county_fips)

waivers_stable <- waivers |>
  filter(county_fips %in% stable_counties)



# 4) When did treatment turn on?  --------------------------------------------------------------

waivers_stable |>
  count(t0) |>
  arrange(t0)


# 5) Quick Callaway Sant'anna  --------------------------------------------------------------

waivers_stable |>
  mutate(t0 = ifelse(is.infinite(t0), NA, t0)) |>
  mutate(unit_id = as.numeric(factor(county_fips))) -> waivers_stable

write_csv(waivers_stable,'/Users/indermajumdar/Downloads/waivers_stable.csv')



waivers_cs <- read_csv('/Users/indermajumdar/Downloads/waivers_stable.csv')


# 1. Make sure ID is numeric (it already is in your file, but be explicit)
waivers_cs <- waivers_cs |>
  mutate(
    unit_id = as.numeric(unit_id),
    # 2. Recode never-treated: t0 must be 0 for those units
    g = if_else(is.na(t0), 0L, as.integer(t0))
  )

# Quick sanity checks:
waivers_cs |>
  count(unit_id) |> count(n)      # should show n = 7 only

waivers_cs |>
  count(unit_id, YEAR) |>
  filter(n > 1)                   # should return 0 rows

att_cs <- att_gt(
  yname   = "chain_dollar",
  tname   = "YEAR",
  idname  = "unit_id",
  gname   = "g",
  xformla = ~ population + income + rent_mean + unemployment_rate + wage,
  data    = waivers_cs,
  panel   = TRUE,               # your file is balanced
  control_group = "nevertreated",
  est_method    = "dr"
)

summary(att_cs)

es_cs <- aggte(att_cs, type = "dynamic", na.rm = TRUE)
summary(es_cs)

ggdid(es_cs) +
  labs(
    x = "Years Relative to waiver",
    y = "ATT on number of dollar stores",
    title = "Dollar Stores"
  ) +
  theme_minimal(base_size = 14)

waivers_cs %>%
  group_by(g) %>%
  summarise(
    n_pre = sum(!is.na(chain_dollar) & YEAR < g),
    n_post = sum(!is.na(chain_dollar) & YEAR >= g)
  )




