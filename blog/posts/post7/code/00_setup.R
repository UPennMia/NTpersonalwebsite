required <- c("jsonlite", "digest", "base64enc", "htmltools", "knitr", "rmarkdown")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
stopifnot(all(vapply(required, requireNamespace, logical(1), quietly = TRUE)))
