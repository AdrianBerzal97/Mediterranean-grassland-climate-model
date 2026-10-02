# ==============================================================================
# Ecohydrological grassland model
# ==============================================================================
# Purpose
# -------
# Core functions used to simulate daily water availability and grassland biomass.
#
# This script contains the scientific model only. Data import, local paths,
# parameter calibration, model evaluation, and figure generation are intentionally
# kept in separate scripts to improve reproducibility and maintainability.
#
# Main components
#   1. Reference evapotranspiration (ET0)
#   2. Soil water content (SWC) and soil water availability (SWA)
#   3. Water-, radiation-, and temperature-limited biomass production
#   4. Daily pasture biomass accumulation
#
# Expected units are inherited from the original research workflow. They should
# be documented explicitly in the repository data dictionary before reuse.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

# ------------------------------------------------------------------------------
# 1. Reference evapotranspiration
# ------------------------------------------------------------------------------

#' Calculate daily reference evapotranspiration
#'
#' This reproduces the equation used in the original workflow:
#' ET0 = 0.0023 * (Tmean + 17.78) * solar_rad * sqrt(Tmax - Tmin)
#'
#' @param tasmean Mean daily air temperature.
#' @param tasmax Maximum daily air temperature.
#' @param tasmin Minimum daily air temperature.
#' @param solar_rad Daily solar radiation.
#'
#' @return Numeric vector with daily ET0.
calculate_et0 <- function(tasmean, tasmax, tasmin, solar_rad) {

  temperature_range <- tasmax - tasmin

  if (any(temperature_range < 0, na.rm = TRUE)) {
    warning(
      "Some tasmax values are lower than tasmin. ",
      "Check the input data before calculating ET0."
    )
  }

  0.0023 *
    (tasmean + 17.78) *
    solar_rad *
    sqrt(pmax(temperature_range, 0))
}


# ------------------------------------------------------------------------------
# 2. Hydrological year
# ------------------------------------------------------------------------------

#' Add hydrological year
#'
#' The hydrological year starts on 1 September. Therefore, dates from September
#' to December are assigned to the following calendar year.
#'
#' @param df Data frame containing a `date` column.
#'
#' @return Data frame with a new `hyd_year` column.
add_hydrological_year <- function(df) {

  stopifnot("date" %in% names(df))

  df %>%
    mutate(
      date = as.Date(date),
      hyd_year = if_else(
        as.integer(format(date, "%m")) >= 9L,
        as.integer(format(date, "%Y")) + 1L,
        as.integer(format(date, "%Y"))
      )
    )
}


# ------------------------------------------------------------------------------
# 3. Soil water balance
# ------------------------------------------------------------------------------

#' Calculate daily soil water content
#'
#' The first day is initialized from Wt_1. Subsequent days depend on the
#' previous day's soil water content, precipitation, and ET0. Soil water content
#' is constrained between Wmin and Wmax.
#'
#' IMPORTANT: `df` must represent one continuous time series (e.g. one site and
#' one projection) and must already be sorted by date.
#'
#' @param df Data frame containing Wt_1, pr, ET0, Wmin, and Wmax.
#'
#' @return Data frame with a new `SWC` column.
calculate_swc <- function(df) {

  required <- c("Wt_1", "pr", "ET0", "Wmin", "Wmax")
  missing <- setdiff(required, names(df))

  if (length(missing) > 0) {
    stop("Missing columns for SWC calculation: ", paste(missing, collapse = ", "))
  }

  if (nrow(df) == 0) {
    df$SWC <- numeric(0)
    return(df)
  }

  swc <- numeric(nrow(df))

  initial_balance <- df$Wt_1[1] + df$pr[1] - df$ET0[1]
  swc[1] <- max(df$Wmin[1], min(initial_balance, df$Wmax[1]))

  if (nrow(df) > 1) {
    for (i in 2:nrow(df)) {
      daily_balance <- swc[i - 1] + df$pr[i] - df$ET0[i]
      swc[i] <- max(df$Wmin[i], min(daily_balance, df$Wmax[i]))
    }
  }

  df$SWC <- swc
  df
}


#' Calculate soil water availability
#'
#' @param df Data frame containing SWC, Wpwp, and Wmax.
#'
#' @return Data frame with a new `SWA` column.
calculate_swa <- function(df) {

  required <- c("SWC", "Wpwp", "Wmax")
  missing <- setdiff(required, names(df))

  if (length(missing) > 0) {
    stop("Missing columns for SWA calculation: ", paste(missing, collapse = ", "))
  }

  df %>%
    mutate(
      SWA = pmax(
        0,
        pmin(SWC - Wpwp, Wmax - Wpwp)
      )
    )
}


# ------------------------------------------------------------------------------
# 4. Environmental limitation functions
# ------------------------------------------------------------------------------

#' Temperature growth factor
#'
#' Piecewise response used in the original model:
#'   T <= T1       -> 0
#'   T1 < T <= T2  -> linear increase from 0 to 1
#'   T2 < T <= T3  -> 1
#'   T3 < T <= T4  -> linear decrease from 1 to 0
#'   T > T4        -> 0
#'
#' @return Numeric temperature limitation factor between 0 and 1.
temperature_growth_factor <- function(T, T1, T2, T3, T4) {

  ifelse(
    T <= T1, 0,
    ifelse(
      T <= T2, (T - T1) / (T2 - T1),
      ifelse(
        T <= T3, 1,
        ifelse(T <= T4, (T4 - T) / (T4 - T3), 0)
      )
    )
  )
}


#' Calculate daily biomass-production terms
#'
#' Reproduces the BioW, BioRad, Fc, BioRec, and BioSIM calculations used in the
#' original research workflow.
#'
#' @param df Data frame containing ET0, SWA, Ka, solar_rad, Kr, tasmean,
#'   T1, T2, T3, T4, and Kpg.
#'
#' @return Data frame with BioW, BioRad, Fc, BioRec, and BioSIM.
calculate_biomass_terms <- function(df) {

  required <- c(
    "ET0", "SWA", "Ka", "solar_rad", "Kr", "tasmean",
    "T1", "T2", "T3", "T4", "Kpg"
  )
  missing <- setdiff(required, names(df))

  if (length(missing) > 0) {
    stop(
      "Missing columns for biomass calculation: ",
      paste(missing, collapse = ", ")
    )
  }

  df %>%
    mutate(
      BioW = pmin(ET0, SWA) * Ka,
      BioRad = (2.45 * solar_rad) * Kr,
      Fc = temperature_growth_factor(tasmean, T1, T2, T3, T4),
      BioRec = pmax(BioW, BioRad) * Fc,
      BioSIM = pmin(BioW, BioRad, BioRec) * (1 - Kpg)
    )
}


# ------------------------------------------------------------------------------
# 5. Daily pasture dynamics
# ------------------------------------------------------------------------------

#' Prepare state variables used by the pasture model
#'
#' @param df Input data frame.
#'
#' @return Data frame containing LAId, Cov, B, SumB, and Pasture columns.
prepare_pasture_columns <- function(df) {

  state_variables <- c("LAId", "Cov", "B", "SumB", "Pasture")

  for (variable in state_variables) {
    if (!variable %in% names(df)) {
      df[[variable]] <- NA_real_
    }
  }

  df
}


#' Simulate daily pasture biomass for one continuous projection
#'
#' The pasture state is propagated day by day. On 1 September, the pasture
#' stock is reset according to parameter G, matching the original research
#' workflow.
#'
#' @param df Data frame for one site/projection, sorted by date.
#' @param initial_pasture Initial pasture biomass. Default = 450.
#'
#' @return Data frame containing Pasture, LAId, Cov, B, and SumB.
simulate_pasture_projection <- function(df, initial_pasture = 450) {

  required <- c("date", "BioSIM", "Kf", "Ke", "Cover0", "SumB0", "G")
  missing <- setdiff(required, names(df))

  if (length(missing) > 0) {
    stop(
      "Missing columns for pasture simulation: ",
      paste(missing, collapse = ", ")
    )
  }

  if (nrow(df) == 0) {
    return(prepare_pasture_columns(df))
  }

  df$date <- as.Date(df$date)
  df <- df %>% arrange(date)
  df <- prepare_pasture_columns(df)

  for (i in seq_len(nrow(df))) {

    if (i == 1) {

      df$Pasture[i] <- initial_pasture
      df$LAId[i] <- df$Pasture[i] * df$Kf[i] / 10000
      df$Cov[i] <- 1 - exp(-df$Ke[i] * df$LAId[i])
      df$B[i] <- df$BioSIM[i] * df$Cover0[i]
      df$SumB[i] <- df$B[i] + df$SumB0[i]

    } else {

      is_hydrological_reset <- format(df$date[i], "%m-%d") == "09-01"

      df$B[i] <- df$BioSIM[i] * df$Cov[i - 1]

      if (is_hydrological_reset) {
        df$Pasture[i] <- df$G[i] * df$Pasture[i - 1]
      } else {
        df$Pasture[i] <- df$Pasture[i - 1] + df$B[i]
      }

      df$LAId[i] <- df$Pasture[i] * df$Kf[i] / 10000
      df$Cov[i] <- 1 - exp(-df$Ke[i] * df$LAId[i])
      df$SumB[i] <- df$B[i] + df$SumB[i - 1]
    }
  }

  df
}


# ------------------------------------------------------------------------------
# 6. Convenience wrapper for the environmental component
# ------------------------------------------------------------------------------

#' Run the environmental component of the ecohydrological model
#'
#' This helper calculates ET0 (when requested), SWC, SWA, and the biomass
#' limitation terms for one continuous time series.
#'
#' It deliberately does not decide how observations and SSP projections should
#' be chained. That transition logic belongs in the workflow/calibration script.
#'
#' @param df Input data frame, sorted by date.
#' @param recalculate_et0 Logical. Recalculate ET0 from temperature and radiation?
#'
#' @return Data frame with environmental and biomass variables.
run_environmental_model <- function(df, recalculate_et0 = FALSE) {

  df <- df %>% arrange(date)

  if (recalculate_et0) {
    required_et0 <- c("tasmean", "tasmax", "tasmin", "solar_rad")
    missing_et0 <- setdiff(required_et0, names(df))

    if (length(missing_et0) > 0) {
      stop(
        "Missing columns for ET0 calculation: ",
        paste(missing_et0, collapse = ", ")
      )
    }

    df$ET0 <- calculate_et0(
      tasmean = df$tasmean,
      tasmax = df$tasmax,
      tasmin = df$tasmin,
      solar_rad = df$solar_rad
    )
  }

  if (!"ET0" %in% names(df)) {
    stop("ET0 is missing. Supply ET0 or set recalculate_et0 = TRUE.")
  }

  df %>%
    calculate_swc() %>%
    calculate_swa() %>%
    calculate_biomass_terms()
}
