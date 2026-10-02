# Data

Raw research data are **not distributed in this portfolio repository**.

The original analysis combines meteorological/climate data, soil properties,
field biomass observations and CMIP6 projections. Some source datasets may be
subject to institutional, provider or project-specific access and licensing
conditions.

## Expected inputs

The cleaned workflow expects, at minimum:

- daily precipitation
- daily minimum, maximum and/or mean temperature
- solar radiation
- site identifier
- climate model
- scenario/projection
- soil hydraulic parameters
- field biomass observations for model evaluation

The climate-change analysis uses six CMIP6 models:

- ACCESS-CM2
- CNRM-ESM2-1
- EC-Earth3-Veg
- MIROC6
- MPI-ESM1-2-HR
- MRI-ESM2-0

and four SSP scenarios:

- SSP1-2.6
- SSP2-4.5
- SSP3-7.0
- SSP5-8.5

To reproduce the published analysis, obtain the source data from their original
providers and adapt the import step to the local file structure.
