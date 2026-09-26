# Run from blog/posts/post3/ with Rscript code/01_analyze.R.
# The downloaded IPUMS DDI and microdata belong in data/raw/ and are not committed.

required_packages <- c("ipumsr", "ggplot2")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Install required R packages first: install.packages(c(",
       paste(sprintf('"%s"', missing_packages), collapse = ", "), "))", call. = FALSE)
}

root <- if (file.exists("index.qmd")) "." else
        stop("Run from blog/posts/post3/ (containing index.qmd and code/).", call. = FALSE)
root <- normalizePath(root)
data_dir <- file.path(root, "data", "raw")
figure_dir <- file.path(root, "results", "figures")
table_dir <- file.path(root, "results", "tables")
cleaned_dir <- file.path(root, "data", "cleaned")
dir.create(figure_dir, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cleaned_dir, recursive = TRUE, showWarnings = FALSE)

ddi_paths <- list.files(data_dir, pattern = "^cps_.*\\.xml$", full.names = TRUE)
if (length(ddi_paths) != 1L) {
  stop("Put exactly one IPUMS CPS extract DDI (.xml) and its matching .dat.gz in data/raw/. See README.md.", call. = FALSE)
}
data_path <- sub("\\.xml$", ".dat.gz", ddi_paths)
if (!file.exists(data_path)) {
  stop("Missing matching data file: ", basename(data_path), call. = FALSE)
}

ddi <- ipumsr::read_ipums_ddi(ddi_paths)
cps <- ipumsr::read_ipums_micro(ddi, data_file = data_path, verbose = FALSE)
needed <- c("YEAR", "MONTH", "AGE", "SEX", "LABFORCE", "WTFINL")
if (!all(needed %in% names(cps))) {
  stop("The extract must contain YEAR, MONTH, AGE, SEX, LABFORCE, and WTFINL.", call. = FALSE)
}

year <- as.numeric(cps$YEAR)
month <- as.numeric(cps$MONTH)
if (!setequal(unique(year), c(2019, 2024)) || any(month != 3, na.rm = TRUE) ||
    anyNA(year) || anyNA(month)) {
  stop("The extract must contain only March 2019 and March 2024 Basic Monthly samples.", call. = FALSE)
}
if (any(table(year) < 1000)) stop("Each year should contain a full CPS sample.", call. = FALSE)

age <- as.numeric(cps$AGE)
sex <- as.numeric(cps$SEX)
labor <- as.numeric(cps$LABFORCE)
weight <- as.numeric(cps$WTFINL)  # ipumsr applies IPUMS implied decimals.

# LABFORCE: 1 = not in labor force; 2 = in labor force; 0 = not in universe.
# Restrict to civilians ages 16+ with valid labor-force status and positive weight.
keep <- !is.na(age) & age >= 16 & age <= 120 & !is.na(labor) & labor %in% c(1, 2) &
        is.finite(weight) & weight > 0 & !is.na(sex) & sex %in% c(1, 2)
if (!any(keep)) stop("No valid civilian age-16+ records; check extract and codes.", call. = FALSE)

age_group <- cut(age[keep], breaks = c(16, 25, 55, 65, Inf), right = FALSE,
                 labels = c("16–24", "25–54", "55–64", "65+"))
df <- data.frame(year = year[keep], age_group = as.character(age_group),
                 sex = ifelse(sex[keep] == 1, "Men", "Women"),
                 w = weight[keep], in_lf_w = weight[keep] * (labor[keep] == 2))

weighted_rate <- function(group_columns) {
  total <- aggregate(df["w"], by = df[group_columns], FUN = sum)
  active <- aggregate(df["in_lf_w"], by = df[group_columns], FUN = sum)
  out <- merge(total, active, by = group_columns, sort = FALSE)
  out$rate <- 100 * out$in_lf_w / out$w
  out[order(out$year, match(out$age_group, c("16–24", "25–54", "55–64", "65+"))), ]
}
overall <- weighted_rate(c("year", "age_group"))
by_sex <- weighted_rate(c("year", "age_group", "sex"))
if (nrow(overall) != 8L || nrow(by_sex) != 16L) {
  stop("An age/sex/year group is missing; check the extract.", call. = FALSE)
}

a <- subset(by_sex, year == 2019, select = c("age_group", "sex", "rate"))
b <- subset(by_sex, year == 2024, select = c("age_group", "sex", "rate"))
names(a)[3] <- "rate_2019"
names(b)[3] <- "rate_2024"
changes <- merge(a, b, by = c("age_group", "sex"))
changes$change_pp <- changes$rate_2024 - changes$rate_2019
changes <- changes[order(match(changes$age_group, c("16–24", "25–54", "55–64", "65+")), changes$sex), ]

men <- subset(by_sex, sex == "Men", select = c("year", "age_group", "rate"))
women <- subset(by_sex, sex == "Women", select = c("year", "age_group", "rate"))
names(men)[3] <- "men_rate"
names(women)[3] <- "women_rate"
gaps <- merge(men, women, by = c("year", "age_group"))
gaps$gap_pp <- gaps$men_rate - gaps$women_rate

write.csv(overall, file.path(cleaned_dir, "weighted_age_rates.csv"), row.names = FALSE)
write.csv(by_sex, file.path(cleaned_dir, "weighted_age_sex_rates.csv"), row.names = FALSE)
write.csv(changes, file.path(table_dir, "changes_by_age_sex.csv"), row.names = FALSE)
write.csv(gaps, file.path(table_dir, "gender_gaps.csv"), row.names = FALSE)

age_levels <- c("16–24", "25–54", "55–64", "65+")
overall$age_group <- factor(overall$age_group, levels = age_levels)
changes$age_group <- factor(changes$age_group, levels = rev(age_levels))
gaps$age_group <- factor(gaps$age_group, levels = age_levels)
base_theme <- ggplot2::theme_minimal(base_size = 13) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                 plot.title.position = "plot", legend.position = "bottom")
colors <- c("2019" = "#4361a6", "2024" = "#cf6544")

p1 <- ggplot2::ggplot(overall, ggplot2::aes(age_group, rate, group = factor(year),
                                         color = factor(year))) +
  ggplot2::geom_line(linewidth = 1) + ggplot2::geom_point(size = 3) +
  ggplot2::scale_color_manual(values = colors, name = "March") +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(title = "Participation varies sharply by age",
                subtitle = "Civilian population ages 16+, weighted CPS estimates",
                x = "Age group", y = "Labor-force participation rate",
                caption = "Source: IPUMS CPS Basic Monthly, March 2019 and March 2024; WTFINL weights") + base_theme

p2 <- ggplot2::ggplot(changes, ggplot2::aes(age_group, change_pp, fill = sex)) +
  ggplot2::geom_hline(yintercept = 0, color = "#555555") +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.72), width = 0.62) +
  ggplot2::coord_flip() +
  ggplot2::scale_y_continuous(breaks = -1:3) +
  ggplot2::scale_fill_manual(values = c("Men" = "#4361a6", "Women" = "#cf6544")) +
  ggplot2::labs(title = "Which groups changed most?", subtitle = "2024 rate minus 2019 rate",
                x = "Age group", y = "Change (percentage points)", fill = NULL,
                caption = "Source: IPUMS CPS Basic Monthly, March 2019 and March 2024; WTFINL weights") + base_theme

p3 <- ggplot2::ggplot(gaps, ggplot2::aes(age_group, gap_pp, group = factor(year),
                                      color = factor(year))) +
  ggplot2::geom_hline(yintercept = 0, color = "#777777", linetype = "dashed") +
  ggplot2::geom_line(linewidth = 1) + ggplot2::geom_point(size = 3) +
  ggplot2::scale_color_manual(values = colors, name = "March") +
  ggplot2::labs(title = "The within-age gender gap",
                subtitle = "Men's participation rate minus women's rate",
                x = "Age group", y = "Gap (percentage points)",
                caption = "Source: IPUMS CPS Basic Monthly, March 2019 and March 2024; WTFINL weights") + base_theme

ggplot2::ggsave(file.path(figure_dir, "01_age_rates.png"), p1, width = 8, height = 5, dpi = 170, bg = "white")
ggplot2::ggsave(file.path(figure_dir, "02_changes_by_sex.png"), p2, width = 8, height = 5, dpi = 170, bg = "white")
ggplot2::ggsave(file.path(figure_dir, "03_gender_gap.png"), p3, width = 8, height = 5, dpi = 170, bg = "white")
