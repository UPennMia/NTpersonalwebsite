# Blog 3: Where Did Labor-Force Participation Change?

## Research question

How did U.S. labor-force participation change across age groups and between women and men from March 2019 to March 2024?

## Sources

- [IPUMS Current Population Survey (CPS)](https://cps.ipums.org/cps/): March 2019 and March 2024 Basic Monthly samples.
- [LABFORCE](https://cps.ipums.org/cps-action/variables/LABFORCE) identifies labor-force status; [WTFINL](https://cps.ipums.org/cps-action/variables/WTFINL) provides the monthly person weights.

The analysis uses civilians ages 16 and older. Both samples are from March so that the comparison uses the same calendar month.

## Files

- `code/00_request_extract.R`: optionally requests and downloads the IPUMS extract using an API key.
- `code/01_analyze.R`: reads the extract, calculates weighted participation rates, and generates tables and figures.
- `data/raw/`: the downloaded IPUMS `.dat.gz` file and its matching `.xml` file. These files are not included in the repository.
- `data/cleaned/`: weighted participation rates by age, and by age and sex.
- `results/tables/`: changes in participation and gender gaps.
- `results/figures/`: three figures used in the article.
- `index.qmd`: article text, calculations, and figures.
- `README.md`: project description and reproduction instructions.

## Reproduce

Install R, Quarto, and the required R packages:

```r
install.packages(c("ipumsr", "ggplot2"))
```

To regenerate the results, obtain the March 2019 and March 2024 **Basic Monthly** samples from [IPUMS CPS](https://cps.ipums.org/cps/). Include `AGE`, `SEX`, `LABFORCE`, and `WTFINL`. Save the downloaded `.dat.gz` file and its matching `.xml` file in `data/raw/`. From the `blog/posts/post3/` directory, run:

```r
source("code/01_analyze.R")
```

This regenerates the CSV files in `data/cleaned/` and `results/tables/`, as well as the three images in `results/figures/`. Render `index.qmd` in RStudio or run `quarto render index.qmd` to build the article.

Alternatively, `code/00_request_extract.R` can request the same samples through the IPUMS API. Set your own `IPUMS_API_KEY` as an environment variable before running the script. The raw IPUMS extract and API key should remain outside Git. The repository includes the generated summaries and figures, so the article can be rendered without downloading the person-level records.

## Method

Labor-force participation is the weighted share of people who are employed or looking for work. For each group, I divide the sum of `WTFINL` weights for people in the labor force by the sum of weights for everyone with a valid labor-force status. The age groups are 16–24, 25–54, 55–64, and 65+. The analysis compares participation by age, changes by age and sex, and the difference between men's and women's rates within each age group.

## Limitations

The two samples contain different people, so the results describe changes between two cross-sections rather than changes experienced by the same individuals. The comparisons do not establish what caused participation to change. The raw IPUMS records require an IPUMS account and are not redistributed in this repository.

## Source notice

Data: Sarah Flood et al., *IPUMS CPS: Version 13.0* [dataset]. Minneapolis, MN: IPUMS, 2025. [https://doi.org/10.18128/D030.V13.0](https://doi.org/10.18128/D030.V13.0).