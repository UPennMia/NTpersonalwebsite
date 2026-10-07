# Working directory: blog/posts/post5/. All inputs and outputs use relative paths.
required <- c("sf", "ggplot2", "jsonlite")
if (!all(required %in% rownames(installed.packages())))
  stop('Run source("code/00_setup.R") first.')
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(ggplot2))
for (d in c("data/cleaned", "results/figures", "results/tables"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
j <- jsonlite::fromJSON("data/raw/acs2024_5yr.json", simplifyVector = FALSE)
stopifnot(j$release$id == "acs2024_5yr")
# Census sentinel values are negative; convert those and null values to NA.
value <- function(z) if (is.null(z) || length(z) != 1 || !is.finite(z) || z < 0) NA_real_ else as.numeric(z)
extract <- function(id) {
  z <- j$data[[id]]
  data.frame(geoid = id, name = j$geography[[id]]$name,
    income = value(z$B19013$estimate$B19013001),
    income_moe = value(z$B19013$error$B19013001),
    poverty_universe = value(z$B17001$estimate$B17001001),
    below_poverty = value(z$B17001$estimate$B17001002),
    universe_moe = value(z$B17001$error$B17001001),
    below_poverty_moe = value(z$B17001$error$B17001002))
}
dat <- do.call(rbind, lapply(names(j$data), extract))
dat$poverty_pct <- with(dat, ifelse(poverty_universe > 0, 100 * below_poverty / poverty_universe, NA_real_))
city <- dat[dat$geoid == "05000US42101", ]
tract <- dat[grepl("^14000US42101", dat$geoid), ]
stopifnot(!anyDuplicated(tract$geoid), all(tract$poverty_pct >= 0 & tract$poverty_pct <= 100, na.rm = TRUE))
g <- st_read("data/raw/tracts_tiger2024.geojson", quiet = TRUE)
stopifnot(!anyDuplicated(g$geoid), setequal(g$geoid, tract$geoid))
g <- g[, "geoid"]
g <- cbind(g, tract[match(g$geoid, tract$geoid), setdiff(names(tract), "geoid")])
g <- st_transform(st_make_valid(g), 26918) # UTM 18N; meters, appropriate for Philadelphia.
stopifnot(all(st_is_valid(g)))
write.csv(tract, "data/cleaned/philadelphia_tracts.csv", row.names = FALSE, na = "")
write.csv(city, "results/tables/city_reference.csv", row.names = FALSE, na = "")
st_write(g, "data/cleaned/philadelphia_tracts.geojson", delete_dsn = TRUE, quiet = TRUE)
complete <- tract[is.finite(tract$income) & is.finite(tract$poverty_pct), ]
# Adjacent-tract descriptive contrast: each shared-boundary pair counted once.
nb <- st_touches(g)
pairs <- do.call(rbind, lapply(seq_along(nb), function(i) {
  k <- nb[[i]][nb[[i]] > i]
  if (length(k)) data.frame(i = i, k = k) else NULL
}))
adj <- data.frame(geoid_a = g$geoid[pairs$i], geoid_b = g$geoid[pairs$k],
  income_gap = abs(g$income[pairs$i] - g$income[pairs$k]),
  poverty_gap_pp = abs(g$poverty_pct[pairs$i] - g$poverty_pct[pairs$k]))
write.csv(adj, "results/tables/adjacent_tract_contrasts.csv", row.names = FALSE, na = "")
facts <- c(tracts = nrow(tract), income_available = sum(is.finite(tract$income)),
  poverty_available = sum(is.finite(tract$poverty_pct)), complete_tracts = nrow(complete),
  income_missing = sum(!is.finite(tract$income)), poverty_missing = sum(!is.finite(tract$poverty_pct)),
  income_p10 = unname(quantile(tract$income, .1, na.rm = TRUE)),
  income_p90 = unname(quantile(tract$income, .9, na.rm = TRUE)),
  poverty_ge30 = sum(tract$poverty_pct >= 30, na.rm = TRUE),
  poverty_lt10 = sum(tract$poverty_pct < 10, na.rm = TRUE),
  correlation = cor(complete$income, complete$poverty_pct),
  city_income = city$income, city_poverty = city$poverty_pct,
  adjacent_income_gap_median = median(adj$income_gap, na.rm = TRUE),
  adjacent_poverty_gap_median = median(adj$poverty_gap_pp, na.rm = TRUE))
write.csv(data.frame(metric = names(facts), value = as.numeric(facts)), "results/tables/key_facts.csv", row.names = FALSE)
# Fixed, interpretable bins; maps include all tracts, with unavailable data gray.
g$income_band <- cut(g$income, c(-Inf, 40000, 60000, 80000, 100000, Inf),
  labels = c("< $40,000", "$40,000–59,999", "$60,000–79,999", "$80,000–99,999", "$100,000+"), right = FALSE)
g$poverty_band <- cut(g$poverty_pct, c(-Inf, 10, 20, 30, 40, Inf),
  labels = c("< 10%", "10–19.9%", "20–29.9%", "30–39.9%", "40%+"), right = FALSE)
# Orientation anchors only, not administrative neighborhood boundaries.
anchors <- data.frame(label = c("Center City", "North Philadelphia", "West Philadelphia", "Northeast", "Northwest"),
  lon = c(-75.1636, -75.151, -75.225, -75.04, -75.205), lat = c(39.9526, 40.005, 39.963, 40.085, 40.075))
a <- st_transform(st_as_sf(anchors, coords = c("lon", "lat"), crs = 4326), 26918)
xy <- st_coordinates(a); a$x <- xy[,1]; a$y <- xy[,2]
base_map <- function(field, palette, title, legend) {
  ggplot(g) + geom_sf(aes(fill = .data[[field]]), color = "white", linewidth = .12) +
    geom_label(data = st_drop_geometry(a), aes(x = x, y = y, label = label),
      inherit.aes = FALSE, size = 3, alpha = .85, label.size = 0, fill = "white") +
    scale_fill_manual(values = palette, drop = FALSE, na.value = "#dddddd", labels = function(x) ifelse(is.na(x), "Unavailable", x), name = legend) +
    coord_sf(datum = NA) + labs(title = title, subtitle = "Philadelphia census tracts | ACS 2020–2024",
      caption = "Source: U.S. Census Bureau via Census Reporter; TIGER 2024 boundaries.\nGray = unavailable estimate. Labels are orientation anchors. North is up.") +
    theme_void(base_size = 12) + theme(plot.title = element_text(face = "bold", size = 18),
      plot.subtitle = element_text(size = 12), plot.caption = element_text(hjust = 0, size = 9),
      legend.position = "right", plot.margin = margin(15, 15, 15, 15))
}
p1 <- base_map("income_band", c("#eff3ff", "#bdd7e7", "#6baed6", "#3182bd", "#08519c"),
  "Household income varies sharply within one city", "Median household income\n(2024 dollars)")
p2 <- base_map("poverty_band", c("#ffffb2", "#fecc5c", "#fd8d3c", "#f03b20", "#bd0026"),
  "High poverty is geographically concentrated", "Residents below the\npoverty threshold")
p3 <- ggplot(complete, aes(income, poverty_pct)) + geom_point(color = "#2166ac", alpha = .55, size = 2) +
  geom_vline(xintercept = city$income, linetype = "dashed", color = "#555555") +
  geom_hline(yintercept = city$poverty_pct, linetype = "dashed", color = "#555555") +
  scale_x_continuous(labels = scales::label_dollar()) +
  labs(title = "Higher-income tracts usually have lower poverty", subtitle = "Each point is a tract with both estimates available",
    x = "Median household income (2024 dollars)", y = "Residents below the poverty threshold (%)",
    caption = sprintf("ACS 2020–2024 | n = %d tracts | Pearson correlation = %.2f\nDashed lines: Philadelphia's direct county estimates, not averages of tract medians.", nrow(complete), facts[["correlation"]])) +
  theme_minimal(base_size = 12) + theme(plot.title = element_text(face = "bold"), plot.caption = element_text(hjust = 0))
for (i in 1:3) ggsave(file.path("results/figures", c("01_income_map.png", "02_poverty_map.png", "03_income_poverty.png")[i]),
  plot = list(p1, p2, p3)[[i]], width = if (i < 3) 9 else 9, height = if (i < 3) 9 else 6, dpi = 200, bg = "white")
message(sprintf("Done: %d tracts, %d complete pairs, three figures.", nrow(tract), nrow(complete)))
