# Independent validation, after analysis/rendering. Does not source 01_analyze.R.
stopifnot(requireNamespace("jsonlite", quietly = TRUE), requireNamespace("digest", quietly = TRUE))
w <- read.csv("data/raw/CES0500000003.csv", na.strings = c("", "."))
p <- read.csv("data/raw/CPIAUCSL.csv", na.strings = c("", "."))
z <- merge(w, p, by = "observation_date", all = TRUE)
z <- z[z$observation_date >= "2019-01-01", ]; z <- z[order(z$observation_date), ]
end <- tail(z[complete.cases(z), ], 1)
d <- read.csv("data/cleaned/monthly_wages_prices.csv", na.strings = c("", "."))
f <- jsonlite::fromJSON("results/tables/key_statistics.json")
c <- read.csv("results/tables/baseline_comparison.csv")
checks <- list()
check <- function(nm, condition) {
  pass <- isTRUE(condition); checks[[length(checks) + 1L]] <<- data.frame(check = nm, passed = pass)
  if (!pass) stop("Failed: ", nm)
}
check("unique monthly records", !anyDuplicated(d$date))
check("full consecutive monthly grid", identical(as.character(seq(as.Date(d$date[1]), as.Date(tail(d$date, 1)), by = "month")), d$date))
check("latest common month", tail(d$date, 1) == end$observation_date)
match_raw <- match(d$date, z$observation_date)
check("earnings match raw source", isTRUE(all.equal(d$hourly_wage, z$CES0500000003[match_raw])))
check("CPI match raw source", isTRUE(all.equal(d$cpi, z$CPIAUCSL[match_raw])))
check("missingness preserved", sum(!d$complete_pair) == sum(!complete.cases(d[c("hourly_wage", "cpi")])))
for (i in seq_len(nrow(c))) {
  base <- z[z$observation_date == c$baseline[i], ]
  a <- end$CES0500000003 / base$CES0500000003; b <- end$CPIAUCSL / base$CPIAUCSL
  check(paste("pay growth", c$baseline[i]), abs(100 * (a - 1) - c$wage_change_pct[i]) < 1e-9)
  check(paste("price growth", c$baseline[i]), abs(100 * (b - 1) - c$price_change_pct[i]) < 1e-9)
  check(paste("real change", c$baseline[i]), abs(100 * (a / b - 1) - c$real_change_pct[i]) < 1e-9)
}
paths <- jsonlite::fromJSON("results/tables/interactive_data.json", simplifyVector = FALSE)
for (base_date in names(paths)) {
  x <- paths[[base_date]]; a <- z[z$observation_date == base_date, ]; raw <- z[match(unlist(x$date), z$observation_date), ]
  real <- 100 * ((raw$CES0500000003 / raw$CPIAUCSL) / (a$CES0500000003 / a$CPIAUCSL) - 1)
  actual <- vapply(x$real, function(v) if (is.null(v)) NA_real_ else as.numeric(v), numeric(1))
  check(paste("interactive path", base_date), length(actual) == length(real) && identical(is.na(actual), is.na(real)) && max(abs(actual - real), na.rm = TRUE) < 1e-9)
}
check("default real result matches article", abs(c$real_change_pct[c$baseline == "2021-01-01"] - f$real_2021) < 1e-9)
check("20 versus 25 example is minus 4 percent", abs(100 * (1.2 / 1.25 - 1) + 4) < 1e-12)
manifest <- jsonlite::fromJSON("data/raw/source_manifest.json", simplifyVector = FALSE)
for (m in manifest) check(paste("source checksum", m$file), digest::digest(file = file.path("data/raw", m$file), algo = "sha256") == m$sha256)
write.csv(do.call(rbind, checks), "results/tables/validation.csv", row.names = FALSE)
message(length(checks), " checks passed.")
