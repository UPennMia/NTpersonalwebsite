# Blog 7: Have Wages Caught Up With Prices?

## Research question

Have U.S. average hourly earnings kept pace with consumer prices, and how does the answer change when the comparison starts in a different month?

## Sources

- U.S. Bureau of Labor Statistics via FRED: [CES0500000003](https://fred.stlouisfed.org/series/CES0500000003), average hourly earnings of all employees, total private; dollars per hour, monthly, seasonally adjusted.
- U.S. Bureau of Labor Statistics via FRED: [CPIAUCSL](https://fred.stlouisfed.org/series/CPIAUCSL), Consumer Price Index for All Urban Consumers, all items; index 1982–1984 = 100, monthly, seasonally adjusted.

The saved snapshots cover January 2019–September 2026 and were retrieved October 19, 2026 (UTC). The original CSV responses, download URLs, retrieval times and SHA-256 checksums are retained in `data/raw/`. CPI is missing for October 2025 in this snapshot; it is not imputed. The analysis ends at the latest month with both observations.

## Files

- `index.qmd`: article text, hidden execution and embedded Plotly charts.
- `code/00_setup.R`: installs missing R packages.
- `code/00_download_data.R`: optionally refreshes the two official CSV snapshots.
- `code/01_analyze.R`: verifies, cleans and joins the series; calculates baseline comparisons and article statistics.
- `code/02_visualize.R`: builds a self-contained Plotly dashboard with two panels, starting-month controls and linked date-window behavior.
- `code/lib/plotly-2.11.1.min.js`: bundled Plotly JavaScript (license retained), verified by SHA-256. The chart does not load a library from the installed R package or a CDN.
- `code/03_validate.R`: independently checks the calculations against the raw observations.
- `data/raw/`: original FRED CSVs and source manifest.
- `data/cleaned/`: monthly earnings and CPI, retaining missing observations.
- `results/figures/`: a self-contained interactive HTML dashboard, embedded directly in the article.
- `results/tables/`: starting-month comparisons, monthly purchasing-power calculations, missing-data record, article statistics, interactive data and verification records.
- `results/sessionInfo.txt`: actual R and package versions used for the analysis.

## Reproduce

Use the existing blog project in RStudio with R 4.3 or later and the Quarto CLI. Put this `post7` folder beside the earlier posts in `blog/posts/`. Set the working directory to `blog/posts/post7/` and install the required packages once in the R Console:

```r
source("code/00_setup.R")
```

The required packages are `jsonlite`, `digest`, `base64enc`, `htmltools`, `knitr` and `rmarkdown`. Initial installation requires internet access.

Open `index.qmd` in RStudio and click **Render**. The equivalent Terminal command from this post folder is:

```bash
quarto render index.qmd
```

Rendering reads the included snapshots, regenerates the cleaned data, statistics and interactive figures, and inserts calculated values into the article. Reproduction does not require downloading data again. The rendered article embeds Plotly and the interactive data, so it works without a server or internet connection. Code remains hidden in the published article.

To run the analysis and independent calculation checks without rendering:

```r
source("code/01_analyze.R")
source("code/03_validate.R")
```

For a deliberate data refresh, run `source("code/00_download_data.R")` before rendering. Use the included snapshots to reproduce the reported version because later revisions may change the results.

Keep the existing website configuration. Execution should use the document directory; if `_quarto.yml` overrides `project.execute-dir`, set it to `file`. Render and publish through the existing workflow, then submit the published article URL and GitHub repository URL.

## Method

The two series are joined by calendar month on a complete monthly grid. No interpolation is performed. A starting month must have both earnings and CPI and must precede the final month. December 2019, January 2021 and June 2022 are preset comparisons; the dropdown also permits other available starting months.

For a starting month b and observation month t:

- Pay index = 100 × earnings(t) / earnings(b).
- Price index = 100 × CPI(t) / CPI(b).
- Purchasing-power change (%) = 100 × [(earnings(t) / CPI(t)) / (earnings(b) / CPI(b)) − 1].
- Hourly earnings in starting-month dollars = earnings(t) × CPI(b) / CPI(t).

The purchasing-power change is a ratio of growth factors, not the difference between two percentage changes. The example in the article illustrates that distinction. Missing CPI produces a gap in the price line and purchasing-power bars, while available nominal earnings remain visible.

Changing the starting month recalculates both figures and their endpoint summary. The upper date slider changes the visible date window in both charts; it does not change their baseline. Legend clicks hide or restore the two upper series. The lower bars are green above zero and red below zero. The complete dashboard is also saved as `results/figures/01_wages_prices.html`. It includes both panels and all JavaScript and data. The article embeds that complete document, so chart loading does not depend on copied htmlwidgets folders or external script URLs.

## Limitations

Average earnings can change because the composition of workers changes, not just because individuals receive raises. This matters especially around the pandemic. The wage series covers private-sector employees, not government workers or all households. It does not measure hours, employment risk, benefits, taxes or disposable household income. CPI is an average urban basket, not an individual's cost of living. The comparison is descriptive and identifies no causal effect. Recent data and seasonal adjustments may be revised. A comparison beginning in one month must not be presented as applying to every possible starting period.
