# Optional authenticated way to reproduce the exact IPUMS extract.
# Run from the repository root AFTER setting IPUMS_API_KEY in your R environment.
if (!requireNamespace("ipumsr", quietly = TRUE)) {
  stop('Install ipumsr: install.packages("ipumsr")', call. = FALSE)
}
if (!nzchar(Sys.getenv("IPUMS_API_KEY"))) {
  stop("Set IPUMS_API_KEY privately. See README.md; never add it to Git.", call. = FALSE)
}
if (!file.exists("blog/posts/post3/index.qmd")) {
  stop("Run this script from the repository root.", call. = FALSE)
}
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
request <- ipumsr::define_extract_micro(
  collection = "cps",
  description = "Blog 3: March 2019 and 2024 Basic Monthly labor force by age and sex",
  samples = c("cps2019_03b", "cps2024_03b"),
  variables = c("AGE", "SEX", "LABFORCE", "WTFINL")
)
submitted <- ipumsr::submit_extract(request)
completed <- ipumsr::wait_for_extract(submitted)
ddi_path <- ipumsr::download_extract(completed, download_dir = "data/raw")
message("Downloaded the IPUMS extract to: ", ddi_path)
