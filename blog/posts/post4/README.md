# Blog Post 4 — U.S. inflation and unemployment, 2015–2026

This is a self-contained Quarto post folder. Put **this folder's contents** in `blog/posts/post4/` in the existing website repository. It follows the Blog 3 layout: `index.qmd`, `code/`, `data/raw/`, `data/cleaned/`, `results/figures/`, and `results/tables/`. The article hides its R setup chunk, displays three generated figures, and has category tags in the YAML header.

## Run from RStudio or a terminal

1. Set the working directory to `blog/posts/post4/` (not the website root). In RStudio's Files pane, open that folder and choose **More → Set As Working Directory**.
2. With internet access, execute `source("code/00_download_data.R")`. This downloads the two public FRED CSV series through their URLs and saves snapshots to `data/raw/`. No FRED API key or extra R package is needed.
3. Render `index.qmd` or the whole Quarto website as you did for Blog 3. Its hidden setup code **runs `code/01_analyze.R` from the raw CSV snapshots on every render**, regenerating the cleaned CSV, three PNGs, and three result CSVs before inserting the computed numbers into the prose. This works offline once the raw files are present. The rendered article shows no R code.
5. Upload or commit this entire `post4` folder in your existing website repository, render/publish by your normal workflow, and submit both the published post URL and repository URL.

From a shell in this folder, the equivalent commands are `Rscript code/00_download_data.R` and `Rscript code/01_analyze.R`. You may run the latter independently without rendering to inspect the output. Tested on R 4.3.3 with the September 28, 2026 FRED download. Base R provides all analysis and plotting functions. The website rendering uses Quarto and its R engine, as Blog 3 does.

## File map

| Path | Purpose |
| --- | --- |
| `index.qmd` | Complete English article; Quarto categories and a hidden setup chunk that rebuilds the results. |
| `code/00_download_data.R` | Programmatic acquisition of the two FRED CSV files. |
| `code/01_analyze.R` | Input checks, 12-month CPI change, date join, rolling correlation, summary tables, and three PNG figures. |
| `data/raw/CPIAUCSL.csv`, `UNRATE.csv` | Source snapshots; commit these to pin the article to the checked release. |
| `data/cleaned/monthly_inflation_unemployment.csv` | All 140 months, preserving the missing October 2025 values. |
| `results/figures/` | Three programmatically generated images referenced by the article. |
| `results/tables/` | Key facts, period summary, and rolling correlation series. |

## Definitions and limits

FRED series: [CPIAUCSL](https://fred.stlouisfed.org/series/CPIAUCSL) (monthly, seasonally adjusted CPI-U index) and [UNRATE](https://fred.stlouisfed.org/series/UNRATE) (monthly, seasonally adjusted unemployment rate). The fixed analytical window is January 2015–August 2026. The earliest CPI value needed for a January 2015 year-over-year rate is January 2014, supplied by FRED's full CSV download.

Inflation is `100 × (CPI[t] / CPI[t−12] − 1)` using the same calendar month a year earlier. The missing October 2025 CPI and unemployment values remain missing. There are 140 calendar months and 139 matched observed pairs. [BLS explains the CPI interruption](https://www.bls.gov/cpi/additional-resources/2025-federal-government-shutdown-impact-cpi.htm) and [the absence of October CPS estimates](https://www.bls.gov/cps/methods/2025-federal-government-shutdown-impact-cps.htm). No interpolation is performed. A rolling correlation uses 36 calendar months and all available pairs in its window (35 in windows containing October 2025). It is descriptive and is not a causal Phillips-curve estimate.

Re-running the download later may replace the pinned raw snapshots with revised FRED values. The analysis is fixed at August 2026; if you refresh, rerun the analysis and render the post to update its inline figures. If a future historical revision changes the expected missing-month pattern, inspect the new source data before changing the validation checks.

## Verified run

`Rscript code/00_download_data.R` and `Rscript code/01_analyze.R` both completed. The analysis found 139 complete months; August 2026 year-over-year inflation was 3.35% and unemployment 4.1%. The highest inflation in this window was 8.98% in June 2022; unemployment peaked at 14.8% in April 2020. The output tables retain full precision. The hidden `index.qmd` setup chunk was also executed independently after deleting the generated files, verifying that it recreates them from the raw snapshots.
