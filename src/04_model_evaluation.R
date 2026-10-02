# ==============================================================================
# Model evaluation
# ==============================================================================
# Generic performance metrics for calibration and independent validation.
# ==============================================================================

model_metrics <- function(observed, simulated) {
  ok <- complete.cases(observed, simulated)
  observed <- observed[ok]
  simulated <- simulated[ok]

  if (length(observed) == 0) {
    stop("No complete observed/simulated pairs were supplied.")
  }

  error <- simulated - observed

  data.frame(
    n = length(observed),
    MAE = mean(abs(error)),
    RMSE = sqrt(mean(error^2)),
    bias = mean(error),
    R2 = if (length(observed) >= 2 && stats::sd(observed) > 0) {
      stats::cor(observed, simulated)^2
    } else {
      NA_real_
    }
  )
}

evaluate_by_site <- function(df) {
  required <- c("site", "observed_biomass", "simulated_biomass")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop("Missing evaluation columns: ", paste(missing, collapse = ", "))
  }

  split(df, df$site) |>
    lapply(function(x) model_metrics(x$observed_biomass, x$simulated_biomass)) |>
    Map(f = function(metrics, site_name) {
      cbind(site = site_name, metrics)
    }, site_name = names(split(df, df$site))) |>
    do.call(what = rbind)
}
