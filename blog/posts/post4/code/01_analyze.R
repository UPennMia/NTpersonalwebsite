# Run from this post's root directory: source("code/01_analyze.R")
# Base R only. The fixed end date keeps figures and prose reproducible.
for (p in c("data/cleaned", "results/figures", "results/tables"))
  dir.create(p, recursive = TRUE, showWarnings = FALSE)

load_series <- function(id) {
  f <- file.path("data/raw", paste0(id, ".csv"))
  if (!file.exists(f)) stop("Missing ", f, ". Run code/00_download_data.R first.")
  z <- read.csv(f, na.strings = c("", "."), check.names = FALSE)
  if (!identical(names(z), c("observation_date", id))) stop("Unexpected columns in ", f)
  z$date <- as.Date(z$observation_date)
  if (anyNA(z$date) || anyDuplicated(z$date)) stop("Invalid dates in ", f)
  z <- z[order(z$date), c("date", id)]
  names(z)[2] <- tolower(id)
  # A missing *value* remains NA; a missing *row* would corrupt the 12-month lag.
  month_number <- as.integer(format(z$date, "%Y")) * 12L + as.integer(format(z$date, "%m"))
  if (any(diff(month_number) != 1L)) stop("Missing calendar month in ", f)
  if (any(z[[2]][!is.na(z[[2]])] <= 0)) stop("Nonpositive observation in ", f)
  z
}

cpi <- load_series("CPIAUCSL")
unemployment <- load_series("UNRATE")
if (!("2026-08-01" %in% as.character(cpi$date) &&
      "2026-08-01" %in% as.character(unemployment$date)))
  stop("The snapshots must contain 2026-08. Rerun code/00_download_data.R.")

# Year-over-year CPI change; an index level is not an inflation rate.
n <- nrow(cpi)
cpi$inflation_yoy <- c(rep(NA_real_, 12L),
                       100 * (cpi$cpiaucsl[13L:n] / cpi$cpiaucsl[1L:(n-12L)] - 1))
d <- merge(cpi, unemployment, by = "date", all = FALSE)
d <- d[d$date >= as.Date("2015-01-01") & d$date <= as.Date("2026-08-01"),
       c("date", "cpiaucsl", "inflation_yoy", "unrate")]
names(d) <- c("date", "cpi_index", "inflation_yoy_pct", "unemployment_pct")
stopifnot(nrow(d) == 140L, !anyNA(d$date),
          all(is.finite(d$inflation_yoy_pct[!is.na(d$inflation_yoy_pct)])),
          all(is.finite(d$unemployment_pct[!is.na(d$unemployment_pct)])))
d$period <- ifelse(d$date < as.Date("2020-01-01"), "2015-2019",
                   ifelse(d$date < as.Date("2022-01-01"), "2020-2021", "2022-2026"))
write.csv(d, "data/cleaned/monthly_inflation_unemployment.csv", row.names = FALSE,
          na = "")
valid <- complete.cases(d[, c("inflation_yoy_pct", "unemployment_pct")])
stopifnot(sum(valid) == 139L,
          identical(as.character(d$date[!valid]), "2025-10-01"))

phase_names <- c("2015-2019", "2020-2021", "2022-2026")
period_stats <- do.call(rbind, lapply(phase_names, function(p) {
  v <- d[d$period == p & valid, ]
  data.frame(period = p, months = nrow(v),
             mean_inflation_pct = mean(v$inflation_yoy_pct),
             mean_unemployment_pct = mean(v$unemployment_pct),
             correlation = cor(v$inflation_yoy_pct, v$unemployment_pct))
}))
write.csv(period_stats, "results/tables/period_summary.csv", row.names = FALSE)

# A 36-calendar-month window; available pairs determine the correlation.
# October 2025 is left missing, not imputed, and each affected window has 35 pairs.
rolling <- do.call(rbind, lapply(36L:nrow(d), function(i) {
  v <- d[(i-35L):i, ]
  complete <- complete.cases(v[, c("inflation_yoy_pct", "unemployment_pct")])
  stopifnot(sum(complete) >= 30L)
  data.frame(date = d$date[i], available_months = sum(complete),
             correlation = cor(v$inflation_yoy_pct[complete],
                               v$unemployment_pct[complete]))
}))
write.csv(rolling, "results/tables/rolling_correlations.csv", row.names = FALSE)

latest <- d[d$date == as.Date("2026-08-01"), ]
highest_inflation <- d[which.max(d$inflation_yoy_pct), ]
highest_unemployment <- d[which.max(d$unemployment_pct), ]
facts <- data.frame(
  metric = c("latest_inflation", "latest_unemployment", "peak_inflation",
             "peak_unemployment", "overall_correlation", "latest_rolling_correlation",
             "complete_months"),
  value = c(latest$inflation_yoy_pct, latest$unemployment_pct,
            highest_inflation$inflation_yoy_pct, highest_unemployment$unemployment_pct,
            cor(d$inflation_yoy_pct[valid], d$unemployment_pct[valid]),
            tail(rolling$correlation, 1), sum(valid)),
  date = c(rep("2026-08-01", 2), as.character(highest_inflation$date),
           as.character(highest_unemployment$date), "2015-01 to 2026-08",
           "2026-08-01", "2015-01 to 2026-08"))
write.csv(facts, "results/tables/key_facts.csv", row.names = FALSE)

start_plot <- function(file) {
  png(file, width = 1700, height = 1100, res = 180, type = "cairo", bg = "white")
  par(family = "sans", cex.axis = 1.05, cex.lab = 1.12, cex.main = 1.22)
}
blue <- "#2367A3"; red <- "#CA5735"; green <- "#208A78"
start_plot("results/figures/01_timeline.png")
par(mfrow = c(2, 1), mar = c(2.2, 5.4, 3.5, 1.5), oma = c(3, 0, 0, 0))
plot(d$date, d$inflation_yoy_pct, type = "l", lwd = 2.5, col = red,
     xlab = "", ylab = "Inflation (% y/y)",
     main = "Inflation surged after the pandemic and then eased")
abline(h = 0, col = "gray75", lty = 3)
plot(d$date, d$unemployment_pct, type = "l", lwd = 2.5, col = blue,
     xlab = "", ylab = "Unemployment (%)",
     main = "Unemployment spiked first, then fell")
mtext("Month, January 2015 to August 2026", side = 1, line = 2, outer = TRUE)
dev.off()

start_plot("results/figures/02_scatter.png")
par(mar = c(5.5, 5.7, 4.2, 1.6))
phase_cols <- c("2015-2019" = blue, "2020-2021" = red, "2022-2026" = green)
plot(d$unemployment_pct[valid], d$inflation_yoy_pct[valid],
     pch = 19, cex = 1.05, col = adjustcolor(phase_cols[d$period[valid]], alpha.f = 0.78),
     xlab = "Unemployment rate (%)", ylab = "CPI inflation (% over 12 months)",
     main = "Different episodes tell different parts of the story",
     xlim = c(2.8, 15.6), ylim = c(-0.5, 9.7))
legend("topright", legend = phase_names, col = phase_cols, pch = 19,
       bty = "n", title = "Period", cex = 0.9)
mark <- function(when, label, position) {
  row <- d[d$date == as.Date(when), ]
  points(row$unemployment_pct, row$inflation_yoy_pct,
         pch = 21, bg = phase_cols[row$period], cex = 1.7, lwd = 1.2)
  text(row$unemployment_pct, row$inflation_yoy_pct, labels = label,
       pos = position, offset = 0.65, cex = 0.8)
}
mark("2020-04-01", "Apr 2020", 2)
mark("2022-06-01", "Jun 2022", 4)
mark("2026-08-01", "Aug 2026", 2)
dev.off()

start_plot("results/figures/03_rolling_correlation.png")
par(mar = c(5.3, 5.7, 4.4, 1.6))
plot(rolling$date, rolling$correlation, type = "l", lwd = 2.6, col = "#784CA8",
     ylim = c(-1, 0.5), xlab = "Window ending month",
     ylab = "Correlation of monthly observations",
     main = "The inflation-unemployment relationship changed over time")
abline(h = 0, col = "gray45", lty = 2)
mtext("36 calendar months per window; 2025-10 missing (not estimated)",
      side = 1, line = 3.8, cex = 0.75, col = "gray35")
dev.off()

cat(sprintf("Analyzed %d complete months; 2025-10 remains missing.\n", sum(valid)))
cat(sprintf("Latest (Aug 2026): inflation %.2f%%, unemployment %.1f%%.\n",
            latest$inflation_yoy_pct, latest$unemployment_pct))
cat(sprintf("Peaks: inflation %.2f%% (%s); unemployment %.1f%% (%s).\n",
            highest_inflation$inflation_yoy_pct, highest_inflation$date,
            highest_unemployment$unemployment_pct, highest_unemployment$date))
cat("Generated cleaned data, 3 charts and 3 result tables.\n")
