# Optional: refresh pinned 2024 releases, preserving the original snapshots.
# For exact replication, use the supplied snapshots instead.
options(timeout = 180)
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
urls <- c(
  acs2024_5yr.json = "https://api.censusreporter.org/1.0/data/show/acs2024_5yr?table_ids=B19013,B17001&geo_ids=140%7C05000US42101,05000US42101",
  tracts_tiger2024.geojson = "https://api.censusreporter.org/1.0/geo/show/tiger2024?geo_ids=140%7C05000US42101")
for (filename in names(urls)) {
  dest <- file.path("data/raw", filename)
  tmp <- tempfile(fileext = ".json")
  download.file(urls[[filename]], tmp, mode = "wb", method = "libcurl")
  parsed <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  if (filename == "acs2024_5yr.json") stopifnot(parsed$release$id == "acs2024_5yr")
  else stopifnot(parsed$type == "FeatureCollection", length(parsed$features) > 0)
  if (file.exists(dest)) file.copy(dest, paste0(dest, ".previous"), overwrite = TRUE)
  stopifnot(file.copy(tmp, dest, overwrite = TRUE))
  unlink(tmp)
}
writeLines(paste("Retrieved UTC:", format(Sys.time(), tz = "UTC")), "data/raw/retrieved.txt")
