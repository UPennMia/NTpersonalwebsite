# Render from this post's directory. No network requests in snapshot mode.
required <- c("jsonlite", "digest", "base64enc", "htmltools", "knitr")
if (!all(vapply(required, requireNamespace, logical(1), quietly = TRUE))) stop("Run source('code/00_setup.R') first.")
for (p in c("data/cleaned", "results/figures", "results/tables")) dir.create(p, recursive = TRUE, showWarnings = FALSE)
manifest <- jsonlite::fromJSON("data/raw/source_manifest.json", simplifyVector = FALSE)
for (m in manifest) stopifnot(digest::digest(file = file.path("data/raw", m$file), algo = "sha256") == m$sha256)
read_series <- function(id, name) {
  x <- read.csv(file.path("data/raw", paste0(id, ".csv")), na.strings = c("", "."), check.names = FALSE)
  stopifnot(all(c("observation_date", id) %in% names(x)))
  z <- data.frame(date = as.Date(x$observation_date), value = as.numeric(x[[id]]))
  z <- z[z$date >= as.Date("2019-01-01"), ]; names(z)[2] <- name
  stopifnot(!anyNA(z$date), !anyDuplicated(z$date), all(is.na(z[[name]]) | z[[name]] > 0))
  z
}
w <- read_series("CES0500000003", "hourly_wage")
p <- read_series("CPIAUCSL", "cpi")
joined <- merge(w, p, by = "date", all = TRUE)
last <- max(joined$date[complete.cases(joined)])
monthly <- data.frame(date = seq(as.Date("2019-01-01"), last, by = "month"))
monthly <- merge(monthly, joined, by = "date", all.x = TRUE)
monthly <- monthly[order(monthly$date), ]; monthly$complete_pair <- complete.cases(monthly[c("hourly_wage", "cpi")])
# Retain a full monthly grid so missing CPI creates a visible gap, not interpolation.
write.csv(monthly, "data/cleaned/monthly_wages_prices.csv", row.names = FALSE, na = "")
write.csv(monthly[!monthly$complete_pair, ], "results/tables/missing_months.csv", row.names = FALSE, na = "")
month_label <- function(x) paste(month.name[as.integer(format(as.Date(x), "%m"))], format(as.Date(x), "%Y"))
base_dates <- monthly$date[monthly$complete_pair & monthly$date < last]
make_window <- function(base_date) {
  base_date <- as.Date(base_date)
  ref <- monthly[monthly$date == base_date, ]; stopifnot(nrow(ref) == 1L, ref$complete_pair)
  z <- monthly[monthly$date >= base_date, ]
  z$wage_index <- 100 * z$hourly_wage / ref$hourly_wage
  z$price_index <- 100 * z$cpi / ref$cpi
  z$real_change_pct <- 100 * ((z$hourly_wage / z$cpi) / (ref$hourly_wage / ref$cpi) - 1)
  z$real_hourly_base_dollars <- z$hourly_wage * ref$cpi / z$cpi
  z$baseline <- base_date
  z
}
windows <- lapply(as.character(base_dates), make_window); names(windows) <- as.character(base_dates)
# Explicit, economically interpretable starting dates; no choice based on the final result.
presets <- as.Date(c("2019-12-01", "2021-01-01", "2022-06-01"))
comparison <- do.call(rbind, lapply(as.character(presets), function(b) {
  z <- windows[[b]]; e <- tail(z, 1)
  data.frame(baseline = b, end_month = as.character(last), wage_change_pct = e$wage_index - 100,
             price_change_pct = e$price_index - 100, real_change_pct = e$real_change_pct)
}))
write.csv(comparison, "results/tables/baseline_comparison.csv", row.names = FALSE)
current <- windows[["2021-01-01"]]
write.csv(current, "results/tables/default_baseline_path.csv", row.names = FALSE, na = "")
trough <- current[which.min(current$real_change_pct), ]
facts <- list(end = month_label(last), start = month_label(min(monthly$date)), n_months = nrow(monthly),
  n_complete = sum(monthly$complete_pair), n_missing = sum(!monthly$complete_pair), n_baselines = length(base_dates),
  wage_end = tail(monthly$hourly_wage, 1),
  wage_2021 = comparison$wage_change_pct[comparison$baseline == "2021-01-01"],
  price_2021 = comparison$price_change_pct[comparison$baseline == "2021-01-01"],
  real_2021 = comparison$real_change_pct[comparison$baseline == "2021-01-01"],
  real_2019 = comparison$real_change_pct[comparison$baseline == "2019-12-01"],
  real_2022 = comparison$real_change_pct[comparison$baseline == "2022-06-01"],
  trough_month = month_label(trough$date), trough_change = trough$real_change_pct,
  missing_labels = paste(month_label(monthly$date[!monthly$complete_pair]), collapse = ", "),
  retrieved = substr(manifest[[1]]$retrieved_utc, 1, 10))
jsonlite::write_json(facts, "results/tables/key_statistics.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)
fact <- function(nm) facts[[nm]]
fmt <- function(x, digits = 1) formatC(x, format = "f", digits = digits, big.mark = ",")
signed <- function(x) sprintf("%+.1f", x)
source("code/02_visualize.R", local = TRUE)
writeLines(capture.output(sessionInfo()), "results/sessionInfo.txt")
message("Rebuilt ", nrow(monthly), " monthly records and ", length(windows), " baseline comparisons.")
