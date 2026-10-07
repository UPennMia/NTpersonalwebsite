# Blog 5: Mapping Income and Poverty in Philadelphia

## Question
Where are high- and low-income census tracts concentrated within Philadelphia, and how does their geography compare with poverty?

## Project organization
Place this entire folder at `blog/posts/post5/` in the existing Quarto blog repository. Keep the existing site-level `_quarto.yml`. Do not put this README in `data/raw/`, and do not move individual images away from their relative paths.

```text
post5/
  index.qmd
  README.md
  code/
    00_setup.R
    00_download_data.R
    01_analyze.R
  data/
    raw/                  # Original ACS JSON and TIGER GeoJSON responses
    cleaned/              # Joined tract CSV and spatial GeoJSON
  results/
    figures/              # Two maps and one scatterplot
    tables/               # Programmatically generated statistics
```

`index.qmd` contains the complete English article. Its hidden setup chunk runs the analysis and reads key facts; numerical statements update automatically. Published readers see prose and figures, not R code.

## Requirements
R (tested with 4.3.3), Quarto (tested with 1.8.27), and packages `sf`, `ggplot2`, `jsonlite`, `knitr`. `scales` is installed as a ggplot2 dependency. RStudio is convenient but optional. No API key is required. The initial package installation requires internet; subsequent replication from the saved snapshots works offline.

For Windows/macOS, install a current R release and use CRAN binary packages. On Linux, `sf` can require system libraries for GDAL, GEOS, PROJ, and units. On Ubuntu/Debian, install `libgdal-dev libgeos-dev libproj-dev libudunits2-dev` before installing sf from source.

## Replicate in RStudio
1. Unzip and put `post5` inside the existing `blog/posts/` directory.
2. Open the existing blog project. In RStudio's Files pane, enter `posts/post5` and choose **More → Set As Working Directory**. Verify that `file.exists("index.qmd")` returns TRUE.
3. Run once in the Console:
   ```r
   source("code/00_setup.R")
   ```
4. Recreate everything from the committed raw snapshots:
   ```r
   source("code/01_analyze.R")
   ```
5. Open `index.qmd` and click **Render**. Rendering reruns the analysis with no network downloads. At site level, the Quarto execution directory must be the document directory (the default). If your existing `_quarto.yml` specifies `execute-dir: project`, change that value to `file` under `project` before rendering this post.

The root of the post folder is the working directory for the R scripts. Do not run them with `code/` as the working directory. No hard-coded personal machine paths are needed.

## Command-line replication
From `blog/posts/post5/`:

```bash
Rscript code/00_setup.R
Rscript code/01_analyze.R
quarto render index.qmd
```

The setup script is only needed the first time. To build the existing site, run `quarto render` from the blog root. Do not replace the existing site configuration with a new standalone project.

## Data and exact download URLs
- Original producer: U.S. Census Bureau, American Community Survey 2020–2024 five-year estimates, fixed release `acs2024_5yr`.
- Access provider: Census Reporter, which serves Census estimates, margins of error, metadata, and TIGER boundaries.
- [ACS response](https://api.censusreporter.org/1.0/data/show/acs2024_5yr?table_ids=B19013,B17001&geo_ids=140%7C05000US42101,05000US42101): B19013 and B17001 for Philadelphia County and its census tracts.
- [Geometry response](https://api.censusreporter.org/1.0/geo/show/tiger2024?geo_ids=140%7C05000US42101): TIGER 2024 census-tract boundaries.
- [B19013 definitions](https://api.census.gov/data/2024/acs/acs5/groups/B19013.html) and [B17001 definitions](https://api.census.gov/data/2024/acs/acs5/groups/B17001.html).
- [API documentation](https://github.com/censusreporter/census-api/blob/master/API.md).

Snapshots were retrieved October 6, 2026. Philadelphia city and county are coterminous; county FIPS 42101 provides the reference estimates. `2013_population_estimate`, an incidental field in the geometry response, is never used. Boundaries and ACS are explicitly pinned to 2024, not the API's changing `latest` endpoint.

## Variables and cleaning
| Cleaned field | Census column / calculation | Unit |
|---|---|---|
| income | B19013_001E (Reporter B19013001) | Median household income, 2024 dollars |
| income_moe | B19013_001M | 90% margin of error, dollars |
| poverty_universe | B17001_001E | People with poverty status determined |
| below_poverty | B17001_002E | People below poverty threshold |
| poverty_pct | 100 × below_poverty / poverty_universe | Percent |
| universe_moe, below_poverty_moe | Corresponding B17001 margins of error | People |

Null or negative sentinel estimates become NA. Zero denominators produce NA poverty rates. Each map retains every tract polygon; unavailable values are gray. The scatterplot uses complete pairs only. Margins of error are preserved, but no margin of error for the derived poverty percentage or formal significance test is calculated. Income and poverty have different statistical universes.

The data join uses full GEOIDs, checks uniqueness and exact matching, repairs invalid polygons, and transforms to EPSG:26918 (UTM zone 18N, meters). Geographic labels are approximate orientation anchors, not neighborhood polygons. North is up. Fixed map categories are not quantiles; income and poverty use different sequential palettes.

The direct county income median and poverty rate are used for city reference lines; tract medians are never averaged to estimate city income. Tract percentiles and Pearson correlation are unweighted geographic summaries, not estimates for the distribution of individual residents. `adjacent_tract_contrasts.csv` gives supplementary absolute differences for boundary-touching tract pairs, each pair once; it is not a formal spatial autocorrelation test.

## Expected output from the included snapshots
408 tract polygons; income available for 375; poverty available for 390; 375 complete pairs. County median household income: $61,953. County poverty rate: about 21.36%. Tract-level income/poverty correlation: about -0.7295. Three PNGs are recreated in `results/figures/`; tables and joined data are regenerated without manual copying.

## Refresh (optional)
From the post directory, run `source("code/00_download_data.R")`, then `source("code/01_analyze.R")`, then render. The download script preserves old responses as `.previous` files and uses fixed release URLs. A later revision or removal of these endpoints may affect refreshed data; the committed snapshots remain the replication inputs. For exact replication, skip refresh.

## Submission and interpretation
Publish the existing Quarto blog using its normal workflow, then submit BOTH the published post URL and the GitHub repository URL. Commit this whole post folder, including raw data and generated figures, so reviewers can inspect results and rerun them. Check the published page shows all three figures. These are descriptive maps: they establish neither causal effects nor neighborhood-level judgments about individual residents.
