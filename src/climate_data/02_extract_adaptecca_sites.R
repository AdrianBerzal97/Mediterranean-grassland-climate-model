# Spatial NetCDF extraction for the SIMPAST study sites (portfolio adaptation).
# Usage: Rscript src/climate_data/02_extract_adaptecca_sites.R <input.nc> <variable> <output.csv>
# Requires terra, ncdf4. Output uses layer indices, not invented calendar dates.
suppressPackageStartupMessages({library(terra); library(ncdf4)})
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: Rscript 02_extract_adaptecca_sites.R <input.nc> <tasmax|tasmin|tas|pr|rsds> <output.csv>")
path <- args[1]; variable <- args[2]; output <- args[3]
if (!file.exists(path)) stop("File not found")
if (!variable %in% c("tasmax", "tasmin", "tas", "pr", "rsds")) stop("Unsupported variable")
sites <- data.frame(site = c("Piñuecar", "Colmenar Viejo", "Tielmes"),
  lon = c(-3.605052, -3.772985, -3.295980),
  lat = c(41.037396, 40.614862, 40.221771))
nc <- ncdf4::nc_open(path)
if (!variable %in% names(nc$var)) {ncdf4::nc_close(nc); stop("Variable absent from NetCDF")}
units_att <- ncdf4::ncatt_get(nc, variable, "units")
units <- if (isTRUE(units_att$hasatt)) as.character(units_att$value) else NA_character_
time_att <- ncdf4::ncatt_get(nc, "time", "calendar")
calendar <- if (isTRUE(time_att$hasatt)) as.character(time_att$value) else "unspecified"
time_units_att <- ncdf4::ncatt_get(nc, "time", "units")
time_units <- if (isTRUE(time_units_att$hasatt)) as.character(time_units_att$value) else NA_character_
ncdf4::nc_close(nc)
r <- terra::rast(path, subds = variable)
if (!nzchar(terra::crs(r))) stop("Missing spatial CRS: inspect lon/lat and grid mapping before extraction")
pts <- terra::vect(sites, geom = c("lon", "lat"), crs = "EPSG:4326")
pts <- terra::project(pts, terra::crs(r))
ext <- terra::ext(r)
xy <- terra::crds(pts)
if (any(xy[,1] < ext$xmin | xy[,1] > ext$xmax | xy[,2] < ext$ymin | xy[,2] > ext$ymax)) stop("Study point outside raster extent")
v <- as.matrix(terra::extract(r, pts, ID = FALSE))
if (ncol(v) != terra::nlyr(r)) stop("Unexpected number of layers")
# No date conversion: CF non-Gregorian calendars require explicit handling.
# No unit conversion: inspect units before feeding data to SIMPAST.
out <- data.frame(site = rep(sites$site, each = ncol(v)),
  layer = rep(seq_len(ncol(v)), times = nrow(v)),
  value = as.vector(t(v)), variable = variable, units = units,
  calendar = calendar, time_units = time_units, source_file = basename(path))
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write.csv(out, output, row.names = FALSE)
message("Extracted values saved. Validate dates, units and missing values before SIMPAST input.")
