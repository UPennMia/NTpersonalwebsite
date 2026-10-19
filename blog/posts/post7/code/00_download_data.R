# Optional refresh. Normal rendering uses the included snapshots.
stopifnot(requireNamespace("jsonlite", quietly = TRUE), requireNamespace("digest", quietly = TRUE))
options(timeout = max(180, getOption("timeout")))
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
stage <- tempfile("blog7-fred-"); dir.create(stage)
series <- c("CPIAUCSL", "CES0500000003")
manifest <- lapply(series, function(id) {
  url <- paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", id, "&cosd=2019-01-01")
  f <- file.path(stage, paste0(id, ".csv"))
  download.file(url, f, mode = "wb", quiet = TRUE)
  x <- read.csv(f, na.strings = c("", "."), check.names = FALSE)
  if (!all(c("observation_date", id) %in% names(x)) || nrow(x) < 36) stop("Unexpected FRED response; snapshots were not replaced.")
  list(file = basename(f), series = id, url = url,
       retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
       sha256 = digest::digest(file = f, algo = "sha256"))
})
jsonlite::write_json(manifest, file.path(stage, "source_manifest.json"), auto_unbox = TRUE, pretty = TRUE)
for (f in c(paste0(series, ".csv"), "source_manifest.json")) {
  if (!file.copy(file.path(stage, f), file.path("data/raw", f), overwrite = TRUE)) stop("Could not save ", f)
}
unlink(stage, recursive = TRUE)
message("Saved updated FRED responses. Render index.qmd to rebuild the analysis.")
