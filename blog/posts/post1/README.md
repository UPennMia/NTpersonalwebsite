# Blog 4: Did Inflation and Unemployment Move Together?

## Research question

How did inflation and unemployment change in the United States from January 2015 to August 2026, and did they consistently move in opposite directions?

## Sources

- [Consumer Price Index for All Urban Consumers: All Items (CPIAUCSL)](https://fred.stlouisfed.org/series/CPIAUCSL): monthly, seasonally adjusted CPI from the U.S. Bureau of Labor Statistics.
- [Unemployment Rate (UNRATE)](https://fred.stlouisfed.org/series/UNRATE): monthly, seasonally adjusted unemployment rate from the U.S. Bureau of Labor Statistics.

Both series were downloaded as public CSV files through FRED, Federal Reserve Bank of St. Louis, on September 28, 2026. The saved files preserve the values used for this article.

## Files

- `code/00_download_data.R`: downloads the two FRED series and saves their CSV files.
- `code/01_analyze.R`: checks and combines the data, calculates inflation and correlations, and generates tables and figures.
- `data/raw/`: saved CPI and unemployment CSV files used for the article.
- `data/cleaned/`: the monthly data after the date join and inflation calculation.
- `results/tables/`: key facts, period summaries, and rolling correlations.
- `results/figures/`: three figures used in the article.
- `index.qmd`: article text, calculations, and figures.
- `README.md`: project description and reproduction instructions.

## Reproduce

Install R and Quarto. The scripts use base R, so no additional R packages or API key are required. From the `blog/posts/post4/` directory, run:

```r
source("code/01_analyze.R")
```

This recreates the cleaned CSV, three result tables, and three PNG figures from the saved files in `data/raw/`. Render `index.qmd` in RStudio or run `quarto render index.qmd` to build the article. Rendering also runs `code/01_analyze.R`, so it regenerates these results from the saved CSV files without an internet connection.

To download the current FRED data again, run `source("code/00_download_data.R")` first, then regenerate the results. A fresh download may contain revisions to historical values.

## Method

The CPI measures the price level; inflation is its percentage change from the same month a year earlier: `100 × (CPI this month / CPI 12 months earlier − 1)`. The unemployment series is already a percentage rate. I match the two series by month, compare their timelines and monthly values, and calculate correlations over successive 36-calendar-month windows.

The analysis covers 140 calendar months. October 2025 has no observed value for either series, leaving 139 matched monthly pairs. These missing values are retained as missing; they are not filled in. A 36-month window containing October 2025 therefore uses 35 observed pairs.

## Limitations

Inflation and unemployment can respond to many economic events. Their correlation describes how the observed monthly values move together; it does not establish a causal tradeoff or predict future outcomes. The data end in August 2026. Downloading FRED data again may change the results if historical observations have been revised.

## Source notice

The U.S. Bureau of Labor Statistics explains the [October 2025 CPI data gap](https://www.bls.gov/cpi/additional-resources/2025-federal-government-shutdown-impact-cpi.htm) and the [missing October 2025 household-survey estimates](https://www.bls.gov/cps/methods/2025-federal-government-shutdown-impact-cps.htm).
