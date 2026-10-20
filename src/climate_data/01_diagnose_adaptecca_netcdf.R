# NetCDF inventory for manually downloaded AdapteCCa/THREDDS climate files.
# Usage: Rscript src/climate_data/01_diagnose_adaptecca_netcdf.R <input_dir> <output_csv>
# install.packages("ncdf4")
suppressPackageStartupMessages(library(ncdf4))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript 01_diagnose_adaptecca_netcdf.R <input_dir> <output_csv>")
if (!dir.exists(args[1])) stop("Input directory not found: ", args[1])
paths <- list.files(args[1], pattern = "\\.nc$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
if (!length(paths)) stop("No NetCDF files found")
att <- function(nc, var, name) {
  a <- ncdf4::ncatt_get(nc, var, name)
  if (isTRUE(a$hasatt)) paste(a$value, collapse = ";") else NA_character_
}
inspect <- function(path) {
  nc <- tryCatch(ncdf4::nc_open(path), error = function(e) e)
  if (inherits(nc, "error")) return(data.frame(file = basename(path), status = conditionMessage(nc), variable = NA_character_, units = NA_character_, dimensions = NA_character_, time_units = NA_character_, calendar = NA_character_, n_time = NA_integer_))
  on.exit(ncdf4::nc_close(nc))
  time_name <- names(nc$dim)[tolower(names(nc$dim)) == "time"]
  time_name <- if (length(time_name)) time_name[1] else NA_character_
  vars <- intersect(names(nc$var), c("tasmax", "tasmin", "tas", "pr", "rsds"))
  if (!length(vars)) vars <- names(nc$var)
  do.call(rbind, lapply(vars, function(v) {
    data.frame(file = basename(path), status = "opened", variable = v,
      units = att(nc, v, "units"),
      dimensions = paste(vapply(nc$var[[v]]$dim, function(d) paste0(d$name, "=", d$len), character(1)), collapse = ";"),
      time_units = if (is.na(time_name)) NA_character_ else att(nc, time_name, "units"),
      calendar = if (is.na(time_name)) NA_character_ else att(nc, time_name, "calendar"),
      n_time = if (is.na(time_name)) NA_integer_ else nc$dim[[time_name]]$len))
  }))
}
result <- do.call(rbind, lapply(paths, inspect))
dir.create(dirname(args[2]), recursive = TRUE, showWarnings = FALSE)
write.csv(result, args[2], row.names = FALSE, na = "")
print(result)
