# ==============================================================================
# Results visualization
# ==============================================================================
# Reusable plots for observed vs simulated biomass and climate/biomass series.
# ==============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

plot_observed_vs_simulated <- function(df) {
  required <- c("observed_biomass", "simulated_biomass")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop("Missing plotting columns: ", paste(missing, collapse = ", "))
  }

  ggplot(df, aes(x = observed_biomass, y = simulated_biomass)) +
    geom_point(size = 2.2) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed") +
    labs(
      x = expression(Observed~biomass~(kg~DM~ha^{-1})),
      y = expression(Simulated~biomass~(kg~DM~ha^{-1}))
    ) +
    theme_minimal(base_size = 12)
}

plot_annual_biomass <- function(df) {
  required <- c("year", "site", "observed_biomass", "simulated_biomass")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop("Missing plotting columns: ", paste(missing, collapse = ", "))
  }

  long <- bind_rows(
    df %>% transmute(year, site, series = "Observed biomass",
                     biomass = observed_biomass),
    df %>% transmute(year, site, series = "Simulated biomass",
                     biomass = simulated_biomass)
  )

  ggplot(long, aes(year, biomass, linetype = series, shape = series)) +
    geom_line() +
    geom_point(size = 2) +
    facet_wrap(~site, scales = "free_y") +
    labs(
      x = "Year",
      y = expression(Biomass~(kg~DM~ha^{-1})),
      linetype = NULL,
      shape = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom")
}
