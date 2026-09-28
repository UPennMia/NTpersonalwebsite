# Run from this post's root directory: source("code/00_download_data.R")
# FRED's public graph CSV links do not require an API key.
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
series <- c("CPIAUCSL", "UNRATE")
for (id in series) {
  url <- paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", id)
  target <- file.path("data/raw", paste0(id, ".csv"))
  temporary <- tempfile(fileext = ".csv")
  tryCatch({
    download.file(url, temporary, mode = "wb", quiet = TRUE)
    x <- read.csv(temporary, na.strings = c("", "."), check.names = FALSE)
    stopifnot(identical(names(x), c("observation_date", id)),
              inherits(as.Date(x$observation_date), "Date"),
              any(x$observation_date == "2014-01-01"),
              any(x$observation_date == "2026-08-01"))
    if (!file.copy(temporary, target, overwrite = TRUE)) stop("Could not save ", target)
    cat(id, ": ", nrow(x), "rows; latest date ", tail(x$observation_date, 1), "\n", sep = "")
  }, finally = unlink(temporary))
}
cat("FRED CSV snapshots saved in data/raw/. Now run source('code/01_analyze.R').\n")

