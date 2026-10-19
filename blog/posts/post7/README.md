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
- `code/lib/plotly-2.11.1.min.js`: Plotly JavaScript used to render the interactive charts; the original license is retained.
- `code/03_validate.R`: independently checks the calculations against the raw observations.
- `data/raw/`: original FRED CSVs and source manifest.
- `data/cleaned/`: monthly earnings and CPI, retaining missing observations.
- `results/figures/`: a self-contained interactive HTML dashboard, embedded directly in the article.
- `results/tables/`: starting-month comparisons, monthly purchasing-power calculations, missing-data record, article statistics, interactive data and verification records.
- `results/sessionInfo.txt`: actual R and package versions used for the analysis.

## Reproduce the analysis

Requirements: R 4.3 or later and Quarto. The R dependencies are `jsonlite`, `digest`, `base64enc`, `htmltools`, `knitr` and `rmarkdown`.

After cloning or downloading the repository, open a terminal in the directory containing this README and `index.qmd`. Run:

```bash
Rscript code/00_setup.R
quarto render index.qmd
```

The setup script installs any missing packages and requires internet access for installation. Rendering uses the included data snapshots to regenerate the cleaned dataset, tables and interactive dashboard, then produces the article as `index.html`. In a Quarto website project, the rendered article is saved under the configured output directory.

Generated outputs include:

- `data/cleaned/monthly_wages_prices.csv`: the monthly dataset used in the analysis.
- `results/tables/`: baseline comparisons, monthly purchasing-power calculations and article statistics.
- `results/figures/01_wages_prices.html`: the interactive dashboard, which can also be opened directly in a browser.

Run the analysis and calculation checks:

```bash
Rscript code/01_analyze.R
Rscript code/03_validate.R
```

The validation script checks the reported statistics, baseline comparisons and missing observations against the raw data. A successful run prints `110 checks passed.` and saves the check results to `results/tables/validation.csv`. `results/sessionInfo.txt` records the R and package versions for each analysis run.

The included snapshots reproduce the reported results. To retrieve updated observations instead, run:

```bash
Rscript code/00_download_data.R
quarto render index.qmd
```

Updated observations and revisions to earlier data may change the results. The rendered dashboard contains its data and Plotly library and can be viewed offline.

## Method

The two series are joined by calendar month on a complete monthly grid. No interpolation is performed. A starting month must have both earnings and CPI and must precede the final month. December 2019, January 2021 and June 2022 are preset comparisons; the dropdown also permits other available starting months.

For a starting month b and observation month t:

- Pay index = 100 × earnings(t) / earnings(b).
- Price index = 100 × CPI(t) / CPI(b).
- Purchasing-power change (%) = 100 × [(earnings(t) / CPI(t)) / (earnings(b) / CPI(b)) − 1].
- Hourly earnings in starting-month dollars = earnings(t) × CPI(b) / CPI(t).

The purchasing-power change is a ratio of growth factors, not the difference between two percentage changes. The example in the article illustrates that distinction. Missing CPI produces a gap in the price line and purchasing-power bars, while available nominal earnings remain visible.

Changing the starting month recalculates both figures and their endpoint summary. The upper date slider changes the visible date window in both charts; it does not change their baseline. Legend clicks hide or restore the two upper series. The lower bars are green above zero and red below zero. The complete dashboard is also saved as `results/figures/01_wages_prices.html`. It includes both panels, JavaScript and data.

## Limitations

Average earnings can change because the composition of workers changes, not just because individuals receive raises. This matters especially around the pandemic. The wage series covers private-sector employees, not government workers or all households. It does not measure hours, employment risk, benefits, taxes or disposable household income. CPI is an average urban basket, not an individual's cost of living. The comparison is descriptive and identifies no causal effect. Recent data and seasonal adjustments may be revised. A comparison beginning in one month must not be presented as applying to every possible starting period.
