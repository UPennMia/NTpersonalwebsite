# Run once from the post5 directory. No API key is needed.
required <- c("sf", "ggplot2", "jsonlite", "knitr")
missing <- setdiff(required, rownames(installed.packages()))
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
stopifnot(all(required %in% rownames(installed.packages())))
