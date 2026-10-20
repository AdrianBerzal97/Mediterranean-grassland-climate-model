# AdapteCCa climate input preparation for SIMPAST

The first SIMPAST article uses daily climate forcing to evaluate and project Mediterranean grassland biomass in **Piñuecar, Colmenar Viejo and Tielmes**. The climate-projection workflow includes six CMIP6 models and SSP1-2.6, SSP2-4.5, SSP3-7.0 and SSP5-8.5.

## Acquisition

The author downloaded the AdapteCCa NetCDF files **manually using the platform's THREDDS server**, rather than a scripted downloader. This directory therefore contains **diagnostic and spatial extraction tools**, not an automated download script. Preserve the original THREDDS file identifiers, model, scenario, variable, version, source URL and access date in private research records. Do not upload provider NetCDF files to this public repository.

## Scripts

- `01_diagnose_adaptecca_netcdf.R`: inspect local NetCDF files and export an inventory of variables, dimensions, units, time-unit attributes, calendar and time-axis length.
- `02_extract_adaptecca_sites.R`: extract a named NetCDF variable at the three study coordinates, using EPSG:4326 points transformed to the raster CRS. Exports **layer-indexed raw values** with metadata. This is **not** a SIMPAST-ready daily climate dataset.

Example commands (run locally after installing `ncdf4` and `terra`):

```bash
Rscript src/climate_data/01_diagnose_adaptecca_netcdf.R ./netcdf ./outputs/netcdf_inventory.csv
Rscript src/climate_data/02_extract_adaptecca_sites.R ./netcdf/tasmax_example.nc tasmax ./outputs/tasmax_sites.csv
```

## Study coordinates (latitude, longitude; WGS84)

| Site | Latitude | Longitude |
| --- | ---: | ---: |
| Piñuecar | 41.037396 | -3.605052 |
| Colmenar Viejo | 40.614862 | -3.772985 |
| Tielmes | 40.221771 | -3.295980 |

## Essential scientific checks before SIMPAST

1. Validate the CF time axis and calendar of each model, including any non-Gregorian calendar. **Do not assume** that layer indices are dates or that all models have 365/366-day years.
2. Verify coordinate reference systems, longitude convention and spatial alignment, and check whether nearest-cell extraction is appropriate for the study.
3. Check units using NetCDF metadata. Typical `tasmax`, `tasmin`, `tas` files may use K; `pr` may use kg m⁻² s⁻¹. Conversion depends on the file and time interval. Radiation inputs also require a separately verified source.
4. Check model/scenario/variable coverage, missing days, missing values, overlaps and historical-to-scenario transitions.
5. Transform validated series into the daily `id`, `date`, `pr`, `tasmax`, `tasmin`, `solar_rad`, `projection` schema expected by `src/01_climate_data_processing.R`. This conversion is **not** automated here.
6. Compare with published SIMPAST results before treating extracted values as validated forcing.

**Status:** portfolio adaptations based on the climate-processing methodology shared across the author's projects; not run or scientifically validated on the original NetCDF datasets. No API keys, original datasets or proprietary files are included.
