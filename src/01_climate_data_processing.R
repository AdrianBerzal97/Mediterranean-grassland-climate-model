# ==============================================================================
# Climate data processing
# ==============================================================================
# Prepares daily climate data for the ecohydrological grassland model.
# Local file paths and raw-data downloads are intentionally excluded.
#
# Expected core columns:
# id, date, pr, tasmax, tasmin, solar_rad, model, projection
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

FINAL_GCMS <- c(
  "ACCESS_CM2", "CNRM_ESM2_1", "EC_Earth3_Veg",
  "MIROC6", "MPI_ESM1_2_HR", "MRI_ESM2_0"
)

SSP_SCENARIOS <- c("ssp126", "ssp245", "ssp370", "ssp585")

standardise_climate_data <- function(df) {
  required <- c("id", "date", "pr", "tasmax", "tasmin", "solar_rad", "projection")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop("Missing climate columns: ", paste(missing, collapse = ", "))
  }

  df %>%
    mutate(
      id = as.character(id),
      date = ymd(date),
      pr = as.numeric(pr),
      tasmax = as.numeric(tasmax),
      tasmin = as.numeric(tasmin),
      solar_rad = as.numeric(solar_rad),
      tasmean = if ("tasmean" %in% names(.)) as.numeric(tasmean) else
        (tasmax + tasmin) / 2,
      year = year(date),
      month = month(date),
      day = day(date),
      hyd_year = if_else(month >= 9L, year + 1L, year)
    ) %>%
    arrange(id, projection, date)
}

check_temperature_order <- function(df) {
  bad <- df %>% filter(!is.na(tasmax), !is.na(tasmin), tasmax < tasmin)
  if (nrow(bad) > 0) {
    warning(nrow(bad), " rows have tasmax < tasmin. Review source data.")
  }
  invisible(bad)
}

check_missing_climate_values <- function(df) {
  variables <- intersect(
    c("pr", "tasmin", "tasmax", "tasmean", "solar_rad", "ET0"),
    names(df)
  )

  data.frame(
    variable = variables,
    n_missing = vapply(variables, function(x) sum(is.na(df[[x]])), integer(1))
  )
}

add_soil_properties <- function(climate_df, soil_df) {
  if (!"id" %in% names(soil_df)) stop("soil_df must contain an `id` column.")

  climate_df %>%
    mutate(id = as.character(id)) %>%
    left_join(soil_df %>% mutate(id = as.character(id)), by = "id")
}

annual_climate_summary <- function(df, year_min = 2016, year_max = 2025) {
  df %>%
    filter(
      year >= year_min,
      year <= year_max,
      projection %in% c("obs", SSP_SCENARIOS)
    ) %>%
    group_by(id, projection, year) %>%
    summarise(
      precipitation_annual = sum(pr, na.rm = TRUE),
      temperature_mean_annual = mean(tasmean, na.rm = TRUE),
      .groups = "drop"
    )
}

# Example:
# climate <- read.csv("data/climate_daily.csv")
# climate <- standardise_climate_data(climate)
# check_temperature_order(climate)
# check_missing_climate_values(climate)
