# ==============================================================================
# Parameter calibration
# ==============================================================================
# Utilities for comparing candidate parameter sets against field biomass.
# The original research workflow explored combinations of Ka, Kr and G.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

candidate_metrics <- function(simulated, observed) {
  ok <- complete.cases(simulated, observed)
  simulated <- simulated[ok]
  observed <- observed[ok]

  if (length(simulated) == 0) {
    return(data.frame(MAE = NA_real_, RMSE = NA_real_, bias = NA_real_, R2 = NA_real_))
  }

  mae <- mean(abs(simulated - observed))
  rmse <- sqrt(mean((simulated - observed)^2))
  bias <- mean(simulated - observed)

  r2 <- if (length(simulated) >= 2 && stats::sd(observed) > 0) {
    summary(stats::lm(simulated ~ observed))$r.squared
  } else {
    NA_real_
  }

  data.frame(MAE = mae, RMSE = rmse, bias = bias, R2 = r2)
}

evaluate_candidate_table <- function(df) {
  required <- c("id", "combo", "simulated_biomass", "observed_biomass")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop("Missing calibration columns: ", paste(missing, collapse = ", "))
  }

  df %>%
    group_by(id, combo) %>%
    group_modify(~ candidate_metrics(.x$simulated_biomass, .x$observed_biomass)) %>%
    ungroup() %>%
    arrange(id, MAE)
}

# Parameter values used for final analyses should be documented separately from
# this generic evaluation code. Keeping data and parameter choices outside the
# function makes the workflow easier to audit and reproduce.
