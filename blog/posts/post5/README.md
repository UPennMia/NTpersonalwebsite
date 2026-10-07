# Blog 5: How Do Income and Poverty Vary Across Philadelphia?

## Research question

Where are high- and low-income areas concentrated in Philadelphia, and how does their distribution compare with poverty?

## Sources

- U.S. Census Bureau, ACS 2020–2024 five-year estimates: [B19013](https://api.census.gov/data/2024/acs/acs5/groups/B19013.html) (median household income) and [B17001](https://api.census.gov/data/2024/acs/acs5/groups/B17001.html) (poverty-status counts).
- Census Reporter: [ACS data](https://api.censusreporter.org/1.0/data/show/acs2024_5yr?table_ids=B19013,B17001&geo_ids=140%7C05000US42101,05000US42101) and [TIGER 2024 tract boundaries](https://api.censusreporter.org/1.0/geo/show/tiger2024?geo_ids=140%7C05000US42101).

Data period: 2020–2024. Boundary year: 2024. Retrieval date (UTC): 2026-10-06. The original API responses are saved in data/raw/.

## Files

- code/00_setup.R: installs the required R packages.
- code/00_download_data.R: downloads the ACS estimates and tract boundaries and saves the original responses.
- code/01_analyze.R: cleans and joins the data, calculates statistics, and saves figures and tables.
- data/raw/: original ACS JSON and TIGER GeoJSON files.
- data/cleaned/: cleaned tract observations and the joined spatial data.
- results/figures/: two maps and one scatterplot generated when index.qmd is rendered.
- results/tables/: city reference estimates, key statistics, and differences between neighboring tracts.
- index.qmd: article text, calculations, and figures.
- README.md: project description and reproduction instructions.

## Reproduce

Install R, RStudio, and Quarto.

Set the working directory to this post folder (blog/posts/post5/) and install the required R packages:

```r
source("code/00_setup.R")
```

This installs sf, ggplot2, jsonlite, and knitr if they are missing. Package installation requires internet access.

Open index.qmd in RStudio and click Render. Rendering runs code/01_analyze.R, reads the saved raw data, and regenerates the cleaned data, statistics, and three figures. Subsequent renders do not require downloading the data again. From a terminal in this post folder, the equivalent command is:

```bash
quarto render index.qmd
```

To run the analysis without rendering the article:

```r
source("code/01_analyze.R")
```

To refresh the data, run source("code/00_download_data.R") before rendering. For replication of the reported results, use the included snapshots. In a Quarto website, execution should use the document directory (the default); if project.execute-dir is set to project in _quarto.yml, change it to file.

## Method

Median household income is B19013_001E, expressed in 2024 inflation-adjusted dollars. Poverty rate = B17001_002E / B17001_001E × 100, where the denominator is the population for whom poverty status is determined. Estimates and boundaries are joined by census-tract GEOID and projected to EPSG:26918 for mapping.

Missing or negative sentinel estimates are treated as NA; zero poverty denominators also produce NA. All 408 tracts appear on the maps, with unavailable estimates shown in gray. Income is available for 375 tracts and poverty for 390. The scatterplot and unweighted correlation use the 375 tracts with both estimates. City reference values come directly from the Philadelphia County estimates, not averages of tract medians. Map labels indicate approximate locations, not neighborhood boundaries.

## Limitations

Five-year ACS estimates summarize 2020–2024 rather than conditions on a single date. Tract estimates have sampling uncertainty; margins of error are retained, but differences are not tested for statistical significance. Income measures households, while poverty measures people. Tract patterns do not describe every resident or identify causal effects. Larger map areas do not necessarily contain more people. Refreshing the data requires internet access, and changes to the API may require updating the download script.
