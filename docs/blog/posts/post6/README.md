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

- `index.qmd`: article source, including the SQL-in-Python tutorial, comparison tables, figure, and interpretation.
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

Install Python 3.9 and Quarto 1.4 or later. Set the working directory to this post folder (`blog/posts/post6/`). In a terminal, install the required Python packages:

```bash
python -m pip install -r code/requirements.txt
```

Open `index.qmd` in RStudio and click Render, or run:

```bash
quarto render index.qmd
```

Rendering runs the Python analysis, reads the saved raw data, and regenerates the cleaned data, estimates, tables, and figures. It also checks that the tutorial code produces the same sample and regression results as the full analysis. Use the included raw-data snapshots to reproduce the reported results; no additional data download is required.

To run the analysis without rendering the article:

```bash
python code/01_analyze.py
```

To check the numerical results independently:

```bash
python code/03_validate.py
```

The article's code blocks are also available in `code/04_tutorial.py` and can be run after the analysis. On systems using the command `python3`, substitute it for `python`. If Quarto selects a different Python environment, set `BLOG6_PYTHON` to the executable path of the environment containing the required packages before rendering. Within a Quarto website, execution should use the document directory, the default setting.

To refresh the source extracts, run `python code/00_download_data.py --refresh` before the analysis. This optional step downloads approximately 620 MB from the official sources. Refreshed data may differ if the providers revise their releases.

## Method

The child's mother ID C00002.00 is joined to NLSY79 respondent ID R00001.00. Child IDs are C00001.00. Mother and child person IDs are kept in separate namespaces. The join is checked for one row per child. It links biological mothers, not fathers or current households.

Income includes wages, salary, commissions, tips, and military pay, excluding self-employment and transfers. For mothers, the Q13-5 wage amount is added to Q13-3 military pay. Revised Q13-5 topcodes are used where the release provides them. Before 2000, child Q15-5 and Q15-3 are added; from 2000, Q15-5-TOP already includes military earnings. Military pay is set to zero only when the receipt question explicitly says No. Other negative survey values remain missing; reported zeros remain zero. No income bracket imputation is performed. Public-file topcodes are retained.

For questionnaires explicitly naming a reference year, income year is survey year minus one. From the 2014 child wave, the question refers to the calendar year before the actual interview; CURDATE~Y supplies that year. Age is reference year minus birth year, the age reached by year-end. Duplicate person/calendar-year reports retain the later valid survey report. Annual CPI-U is the mean of twelve monthly observations. Real income equals nominal income multiplied by CPI-U for 2020 divided by CPI-U for its reference year.

Mother income is observed at ages 35–39, and child income separately at 20–29 and 30–39. SQLite SELECT/JOIN constructs links; GROUP BY, AVG, and COUNT aggregate each person's records. Aggregation precedes the intergenerational income join to avoid multiplying person-years. ROW_NUMBER selects the observed year nearest age 37, 25, or 35, respectively, breaking ties toward the earlier year. This selection includes zeros; it does not search for a positive replacement year.

The common sample requires at least two nonmissing, nonnegative income years in every window, plus strictly positive single-year values and means for all logged measures. Arithmetic means include zero years; logs are taken after averaging. Of 11,551 official child records, 11,549 have the required demographic fields and match a mother. Of these, 1,934 meet the coverage rule; 757 are then excluded because one or more log-income measures are nonpositive. The remaining 1,177 children of 896 mothers, born 1972–1986, enter every main specification.

Each unweighted OLS regression includes an intercept and log maternal income. Both generations use single-year income, or both use multi-year means. Mother-cluster robust standard errors use a finite-sample correction and t critical values with 895 degrees of freedom. Differences between specifications use 2,000 paired percentile bootstrap replications, resampling mothers with all their children, seed 20261016. The four-family lifecycle benchmark uses a lifetime slope of 0.4 and an early-career loading of 0.5. It demonstrates a slope of 0.2 for both a single early year and an early three-year mean. These illustrative families are not survey records and do not enter the real-data analysis. Software versions used for each run are recorded in `results/tables/environment.json`.

## Limitations

The sample is selected by coverage, age, attrition, and positive log income. It excludes many zero-income observations at the selected single-year points. Maternal wage income is narrower than parental household resources, and these unweighted associations are not national estimates or causal effects. Public-file topcoding and nonresponse affect measurement. The same mothers can have several children; clustering accounts for siblings but not all cousin relationships.

The number and timing of observations differ across people and windows. From 2010, young adults over 30 are generally interviewed every four years. The means cover observed income years, not a complete decade. Career changes, calendar-period shocks, and differing coverage can affect age comparisons; the early-to-late multi-year difference is not statistically distinguishable from zero here. Averaging can reduce temporary income fluctuations but does not automatically remove lifecycle bias or recover lifetime income.
