# Blog 6: Matching Mothers and Children with SQL in Python

## Research question

How do single-year and multi-year income measures change estimated earnings persistence between mothers and their adult children? Does measuring children in their 20s rather than their 30s change the comparison?

## Sources

- National Longitudinal Surveys, [NLSY79 through 2022 and Child/Young Adult through 2020](https://www.nlsinfo.org/content/access-data-investigator/accessing-data-cohorts). Official public cohort ZIPs were retrieved on October 16, 2026. The saved CSVs retain all original rows and selected original columns, including negative survey codes. They are extracts, not simulated data or the complete cohort files.
- NLS documentation on [mother–child links](https://www.nlsinfo.org/content/getting-started/introduction-to-the-nls/tutorials-and-videos/linking-nlsy79-mothers-and-their-children), [maternal income](https://www.nlsinfo.org/content/cohorts/nlsy79/topical-guide/income/income), [child income](https://www.nlsinfo.org/content/cohorts/nlsy79-children/topical-guide/income/introduction), and [sample design](https://www.nlsinfo.org/content/cohorts/nlsy79-children/intro-to-the-sample/sample-design).
- U.S. Bureau of Labor Statistics via FRED, [CPIAUCNS](https://fred.stlouisfed.org/series/CPIAUCNS), monthly CPI-U, all items, U.S. city average, not seasonally adjusted. The saved extract covers 1990–2021.
- Haider and Solon (2006), [Life-Cycle Variation in the Association between Current and Lifetime Earnings](https://www.nber.org/papers/w11943).

Exact variable references, question wording, download URLs, and SHA-256 checksums are saved in `data/raw/variable_map.csv`, `selected_codebook.txt`, and `source_manifest.json`.

## Files

- `index.qmd`: tutorial with five visible Python blocks, a comparison table, a figure, and interpretation. Edit the article here.
- `code/01_analyze.py` and the three `.sql` files: source cleaning, matching, income construction, regressions, bootstrap comparisons, and figures.
- `code/render.lua` and `code/02_render.py`: automatically rebuild the analysis during Quarto rendering and check the displayed tutorial against it.
- `code/04_tutorial.py`: the five displayed blocks combined into a runnable script; regenerated from the article during rendering.
- `code/03_validate.py`: independent checks of matching, aggregation, and regression results.
- `code/00_download_data.py`: optional refresh from the official downloads.
- `code/requirements.txt`: pinned Python dependencies.
- `data/raw/`: saved official extracts, CPI, codebook, variable map, and source checksums.
- `data/cleaned/`: cleaned records and analysis tables. `tutorial_income.csv` contains person-years and selection flags, not precomputed income averages or intergenerational matches.
- `results/`: generated figures, estimates, bootstrap contrasts, and validation records.

## Reproduce

Use Python 3.9 and Quarto 1.4 or later. In RStudio's Terminal, change to this post folder and install the dependencies once:

```bash
python -m pip install -r code/requirements.txt
```

Place the entire `post6` folder beside the earlier posts in `blog/posts/`. Open `index.qmd` in RStudio and click Render, or run:

```bash
quarto render index.qmd
```

Rendering runs Python automatically: it verifies the saved raw data, rebuilds the analysis, executes the five displayed blocks in order, checks their sample and estimates against the full analysis, and inserts the calculated results into the page. The supplied data are sufficient; no source download is needed. The filter checks the standard Windows Anaconda installation first, then the system Python. To choose another interpreter, set the `BLOG6_PYTHON` environment variable to its executable path before rendering.

For an independent numerical check, run:

```bash
python code/03_validate.py
```

After rendering once, the visible tutorial can also be run separately with `python code/04_tutorial.py`. On systems where the command is named `python3`, use that in place of `python`. Keep the existing website configuration and publishing workflow, render the website, then commit and push the changed post files. Submit the published Blog6 URL and GitHub repository URL.

`python code/00_download_data.py --refresh` optionally reconstructs the extracts from the full official downloads (approximately 620 MB). This is unnecessary for ordinary reproduction. Refreshing may change the snapshots if the provider revises its release.

## Method

The child's mother ID C00002.00 is joined to NLSY79 respondent ID R00001.00. Child IDs are C00001.00. Mother and child person IDs are kept in separate namespaces. The join is checked for one row per child. It links biological mothers, not fathers or current households.

Income includes wages, salary, commissions, tips, and military pay, excluding self-employment and transfers. For mothers, the Q13-5 wage amount is added to Q13-3 military pay. Revised Q13-5 topcodes are used where the release provides them. Before 2000, child Q15-5 and Q15-3 are added; from 2000, Q15-5-TOP already includes military earnings. Military pay is set to zero only when the receipt question explicitly says No. Other negative survey values remain missing; reported zeros remain zero. No income bracket imputation is performed. Public-file topcodes are retained.

For questionnaires explicitly naming a reference year, income year is survey year minus one. From the 2014 child wave, the question refers to the calendar year before the actual interview; CURDATE~Y supplies that year. Age is reference year minus birth year, the age reached by year-end. Duplicate person/calendar-year reports retain the later valid survey report. Annual CPI-U is the mean of twelve monthly observations. Real income equals nominal income multiplied by CPI-U for 2020 divided by CPI-U for its reference year.

Mother income is observed at ages 35–39, and child income separately at 20–29 and 30–39. SQLite SELECT/JOIN constructs links; GROUP BY, AVG, and COUNT aggregate each person's records. Aggregation precedes the intergenerational income join to avoid multiplying person-years. ROW_NUMBER selects the observed year nearest age 37, 25, or 35, respectively, breaking ties toward the earlier year. This selection includes zeros; it does not search for a positive replacement year.

The common sample requires at least two nonmissing, nonnegative income years in every window, plus strictly positive single-year values and means for all logged measures. Arithmetic means include zero years; logs are taken after averaging. Of 11,551 official child records, 11,549 have the required demographic fields and match a mother. Of these, 1,934 meet the coverage rule; 757 are then excluded because one or more log-income measures are nonpositive. The remaining 1,177 children of 896 mothers, born 1972–1986, enter every main specification.

Each unweighted OLS regression includes an intercept and log maternal income. Both generations use single-year income, or both use multi-year means. Mother-cluster robust standard errors use a finite-sample correction and t critical values with 895 degrees of freedom. Differences between specifications use 2,000 paired percentile bootstrap replications, resampling mothers with all their children, seed 20261016. The constructed four-family lifecycle benchmark is constructed with a lifetime slope of 0.4 and an early-career loading of 0.5. It demonstrates a slope of 0.2 for both a single early year and an early three-year mean. These illustrative families are not survey records and do not enter the real-data analysis. Software versions used for each run are recorded in `results/tables/environment.json`.

## Limitations

The sample is selected by coverage, age, attrition, and positive log income. It excludes many zero-income observations at the selected single-year points. Maternal wage income is narrower than parental household resources, and these unweighted associations are not national estimates or causal effects. Public-file topcoding and nonresponse affect measurement. The same mothers can have several children; clustering accounts for siblings but not all cousin relationships.

The number and timing of observations differ across people and windows. From 2010, young adults over 30 are generally interviewed every four years. The means cover observed income years, not a complete decade. Career changes, calendar-period shocks, and differing coverage can affect age comparisons; the early-to-late multi-year difference is not statistically distinguishable from zero here. Averaging can reduce temporary income fluctuations but does not automatically remove lifecycle bias or recover lifetime income.
