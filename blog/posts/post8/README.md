# Do Coupons Actually Increase Profit?

A simulation calibrated to a published coupon experiment estimates incremental contribution profit and identifies the margin/campaign-cost combinations at which coupons break even. It retains the profit question; purchases alone are not the outcome.

## Inputs and interpretation

Source: Gopalakrishnan and Park, MSI Report 19-106:
https://thearf-org-unified-admin.s3.amazonaws.com/MSI/2020/06/MSI_Report_19-106-1.pdf
Locations: printed p20 for coupon terms, p24 for buyer receipts, Table 2 (printed p47) for purchase/redemption rates.

The seven transcribed, rounded quantities appear with units and provenance in data/raw/published_inputs.csv. They are published summaries, not original customer records. Rates describe the study sample, not population-weighted estimates. Group/category mean receipts are held constant within category. This finite-outcome simulation does not reproduce the paper's spending variance or stratified design, and its confidence intervals are not confidence intervals for that original experiment.

The contribution margin g applies to pre-discount sales after product and fulfillment variable costs. A redeemed coupon reduces profit by $7, once. Campaign cost c applies to every assigned coupon recipient, including nonbuyers. Gross revenue is restored by adding $7 to redeemers' reported net receipts, avoiding double-counting discounts. Baseline profit is g times control receipts. Treatment profit is g times gross receipts minus redeemed discounts minus c.

The retailer's actual margin and campaign cost are not disclosed. The 10% margin and zero campaign cost are illustrative cost scenarios, not estimated financial facts. No outside company's margin is substituted for this retailer's. The main economic result is the full relationship:
incremental contribution profit = 0.757811*g - 0.0406 - c.
At c=0, model break-even g is 5.3575%. At g=10%, model expected gain before campaign cost is $0.0351811 per recipient. These values are conditional on calibrated aggregate rates and the stated cost model.

## Files

- index.qmd: article, three figures, and a directly embedded margin/cost interaction.
- code/00_setup.R: dependency setup.
- code/01_analyze.R: simulation, bootstrap, coverage, null test, figure/table generation, and numerical diagnostics.
- data/raw/published_inputs.csv: transcribed source quantities.
- data/raw/simulation_design.csv: fixed seed and simulation settings.
- data/cleaned/simulated_customers.csv: generated customer outcomes, gross receipts, redemptions, and scenario profit.
- results/figures/: bootstrap distribution, coverage experiment, and null distribution.
- results/tables/: bootstrap draws, coverage intervals, null draws, scenario sensitivity, and summary.

## Reproduce

Download or clone this repository. The analysis requires R 4.3 or later. Rendering the article also requires Quarto and the R packages `knitr` and `rmarkdown`.

From the directory containing this README, run:

```bash
Rscript code/00_setup.R
Rscript code/01_analyze.R
quarto render index.qmd
```

The setup script installs missing R packages and requires an internet connection if installation is needed. The analysis itself uses base R and the included inputs, so no external data download is required. It regenerates the simulated customer records, tables, and figures. Rendering reruns the analysis and produces the article webpage. If model parameters are changed, the corresponding numerical statements and interpretations in the article must also be updated.

The random seed is `20261026`. The main bootstrap uses 5,000 customer resamples within each group. Coverage is evaluated across 2,000 independent simulated trials, with 2,000 bootstrap resamples per trial. The null distribution uses 50,000 centered bootstrap resamples. Percentile intervals use R’s type-7 quantiles. The rejection boundary uses the type-1 95th percentile of absolute null differences; rejection requires strictly exceeding this boundary.

For coverage and null simulations, binomial and multinomial draws generate customer counts efficiently. These implement the same resampling distribution as drawing individual customers with replacement. The main bootstrap resamples customer records directly, preserving the relationship between sales and coupon redemption.

The two-sided Monte Carlo p-value is calculated as:

```text
(1 + number of absolute null differences at least as large as observed)
÷ (50,000 + 1)
```

The null simulation centers each group’s profit outcomes at zero, imposing equal expected profit while retaining each group’s empirical variability. These centered outcomes form a reference distribution rather than literal customer profit records. The test is approximate. Because the percentile interval and the centered-bootstrap test use different constructions, their conclusions need not always agree.

## Scope and checks

The known simulation effect follows from fixed source-calibrated category probabilities and explicit scenario costs. It is used to evaluate interval coverage, not to estimate purchase probabilities from a supposed known real-world effect. Source-estimation uncertainty and within-category spending variation are omitted; resampling cannot recover missing information. Repeat purchases, returns, spillovers, and price-induced changes in margins are outside this model.

Diagnostics in the analysis check customer profit accounting, bootstrap quantiles, coverage near 95% with Monte Carlo tolerance, and null mean/variance against empirical moments. The embedded selector recomputes intervals from the same joint bootstrap draws at each margin and subtracts a fixed campaign cost; it does not predict demand responses to changing the coupon.
