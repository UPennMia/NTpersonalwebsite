# Blog 2: Where Does the Minimum Wage Go Furthest?

## Research question
How does adjusting minimum wages for state-level living costs change the comparison across U.S. jurisdictions?

## Sources
- U.S. Department of Labor: https://www.dol.gov/agencies/whd/mw-consolidated
- MERIC: https://meric.mo.gov/data/cost-living-data-series

DOL wage schedule: July 1, 2026.
MERIC cost period: Second Quarter 2026.
DOL retrieval date (UTC): 2026-09-20.
MERIC retrieval date (UTC): 2026-09-20.

## Files
- code/01_scrape.R: downloads both webpages, extracts tables with rvest, cleans and joins observations, and saves CSV outputs.
- data/raw/dol/: original DOL HTML, extracted cells, and retrieval metadata.
- data/raw/meric/: original MERIC HTML, extracted table, and retrieval metadata.
- data/cleaned/: merged observations, the single-rate analysis sample, and multiple-rate states.
- results/figures/: figures generated when index.qmd is rendered.
- results/table/: rankings, the top ten, the multiple-rate appendix, and validation counts.
- index.qmd: article text, calculations, figures, and tables.
- README.md: project description and reproduction instructions.

## Reproduce
Install R, RStudio, and Quarto.

Install the required R packages:

```r
install.packages(c("rvest", "xml2", "httr", "stringr", "knitr", "rmarkdown"))
```

Open index.qmd in RStudio and click Render.
The first run downloads both websites. Subsequent runs parse the saved HTML.
To request current webpages, change refresh = FALSE to refresh = TRUE in the setup chunk, render once, and then change it back to FALSE.
From a terminal in this post folder, the equivalent rendering command is: quarto render index.qmd

## Method
Cost-adjusted hourly wage = nominal hourly minimum wage / (cost index / 100).
The wage scope is general non-tipped employment covered by the federal FLSA.
States without a higher applicable state floor use the federal floor.
Superscript footnote markers are removed before wage values are parsed.
Multiple general rates are retained in a separate appendix rather than reduced to an arbitrary single value.
Matched jurisdictions: 51.
Main analysis sample: 47.
Multiple-rate states excluded from the main comparison: New Jersey, New York, Ohio, and Oregon.

## Limitations
The wage schedule and cost index cover different periods.
State averages conceal local variation.
The adjustment omits taxes, benefits, household composition, and job availability.
The results describe a purchasing-power proxy and do not identify causal effects.
Refreshing requires internet access; changed website layouts or access rules may require updating the scraper.

## Source notice
The article includes the State of Missouri source-data notice.
