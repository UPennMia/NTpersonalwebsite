# Blog 3: U.S. labor-force participation, 2019–2024

This post folder reproduces the Quarto article at `index.qmd`. The published article contains prose and three figures, with no displayed R code. Its results come from a real IPUMS CPS extract of the March 2019 and March 2024 **Basic Monthly** samples (extract #1, created September 26, 2026; 213,419 person records).

## Folder map

| Path | Contents |
| --- | --- |
| `code/00_request_extract.R` | Optional API request and download using your private IPUMS API key. |
| `code/01_analyze.R` | Import, checks, weighted estimates, tables, and figures. |
| `data/raw/` | Matching IPUMS DDI XML and compressed person records; **exclude these files from Git**. |
| `data/cleaned/` | Two generated weighted group summaries in CSV format. |
| `results/tables/` | Two generated comparisons in CSV format. |
| `results/figures/` | Three generated PNG charts. |
| `index.qmd` | Article with hidden calculations and linked figures. |

## Data and replication

1. Log in to [IPUMS CPS](https://cps.ipums.org/cps/). Select Basic Monthly samples `cps2019_03b` and `cps2024_03b` (not March ASEC). Request `YEAR`, `MONTH`, `AGE`, `SEX`, `LABFORCE`, `WTFINL`; some are automatically included. Download the fixed-width `.dat.gz` **and** matching DDI `.xml` files. Put one matching pair, such as `cps_00001.dat.gz` and `cps_00001.xml`, in `data/raw/`. The sample must not be restricted to employed people or one sex.
2. Install R, Quarto, and R packages with `install.packages(c("ipumsr", "ggplot2"))`.
3. From the website project, set the RStudio Console working directory to `blog/posts/post3/` (for example, navigate to it in Files and choose More > Set As Working Directory). Then run `source("code/01_analyze.R")`. This replaces the two files in `data/cleaned/`, two files in `results/tables/`, and three PNGs in `results/figures/`.
4. Render `index.qmd` (or your whole Quarto website). Verify the article has three charts, dynamically calculated figures in its sentences, and no visible R code. Commit and push the QMD, code, README, summary CSVs and figures; do not commit the raw IPUMS files. Submit the published post URL and the repository URL.

As an alternative to step 1, create your own IPUMS API key, put it in the `IPUMS_API_KEY` environment variable **outside Git**, then run `source("code/00_request_extract.R")` from `blog/posts/post3/`. The script submits the precise request, waits, and downloads to `data/raw/`. Do not paste your key into the script. In the website repository root `.gitignore`, add `blog/posts/post3/data/raw/cps_*.dat.gz` and `blog/posts/post3/data/raw/cps_*.xml` before placing any private extract there.

The numerator for each labor-force participation rate is the sum of `WTFINL` for records with `LABFORCE == 2`; the denominator is the sum for `LABFORCE` 1 or 2. The population is civilian people age 16 and over with positive weights. The four age groups are 16–24, 25–54, 55–64, and 65+. The 2019 and 2024 observations are separate cross-sections and do not identify a causal effect. Raw IPUMS person records require an account; committed cleaned aggregates and charts let the article render without a private extract.

## Adding the article to an existing website

Keep this entire folder inside `blog/posts/post3/` in the website repository. Render the website, then commit and push source and rendered files using the existing site workflow. Keep your own raw extract pair in `data/raw/` locally for regeneration.

**Data citation:** Sarah Flood, Miriam King, Renae Rodgers, Steven Ruggles, J. Robert Warren, Daniel Backman, Etienne Breton, Grace Cooper, Julia A. Rivera Drew, Stephanie Richards, David Van Riper, and Kari C.W. Williams. *IPUMS CPS: Version 13.0* [dataset]. Minneapolis, MN: IPUMS, 2025. https://doi.org/10.18128/D030.V13.0. Variable documentation: [LABFORCE](https://cps.ipums.org/cps-action/variables/LABFORCE), [WTFINL](https://cps.ipums.org/cps-action/variables/WTFINL).
