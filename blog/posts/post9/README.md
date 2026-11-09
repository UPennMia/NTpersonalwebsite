# An Attempt to Improve Stock Return Predictions with Gradient Boosting

## Research question

Does changing the inputs and tuning the XGBoost model improve its out-of-sample stock return forecasts and the performance of a portfolio built from them?

## Sources

- University of Pennsylvania course materials. The original XGBoost script provides the baseline model settings. The classroom portfolio results provide paired final values for 45 teams.
- Yahoo Finance. Daily prices and trading volumes for 95 stocks and SPY from January 3, 2022 to October 30, 2026. Returns use adjusted closing prices. [Yahoo Finance](https://finance.yahoo.com/)

## Files

- `index.qmd` — blog post with the forecast and portfolio comparisons.
- `code/01_analyze.py` — prepares the data, fits the models, runs the backtest and regenerates the figures and tables.
- `data/raw/` — classroom portfolio results and daily market data.
- `data/cleaned/daily_panel.csv` — aligned predictors, forward returns and holding dates.
- `results/figures/` and `results/tables/` — generated charts, model comparisons and supporting results.

## Reproduce

Open `index.qmd` in RStudio and click **Render**, or run the following command from the directory containing the article.

```bash
quarto render index.qmd
```

The article contains the reported tables and uses the included figures.

To reproduce the underlying analysis separately, use Python 3.11 or later and install the required packages.

```bash
python -m pip install numpy==2.3.5 pandas==2.2.3 matplotlib==3.10.8 scipy==1.17.0 xgboost==3.2.0 scikit-learn==1.8.0
python code/01_analyze.py
```

The script regenerates the figures and CSV results from the included data. If the analysis changes, update the tables in `index.qmd` to match the new results.

## Method

The classroom comparison pairs each team's two final portfolio values and computes a paired t interval for the mean difference.

The original model uses its original predictors and settings. The tuned model replaces raw price and volume levels with return-based and relative measures. Twelve configurations are fitted on 2022 data and compared by RMSE on 2023 data. Both models are then refitted on the data available before 2024 and evaluated from 2024 onward against a historical-mean forecast. The XGBoost seed is 123. The script checks that training returns are fully realized before the next evaluation period begins.

Every 19 trading sessions, each model selects its ten highest forecasts and weights the positive forecasts proportionally. If all ten are nonpositive, the ten stocks receive equal weights. The backtest compares both portfolios with SPY and an equal-weight portfolio on the same dates. The main comparison charges 10 basis points per dollar traded and also reports results at zero and 25 basis points.

## Limitations

The classroom teams faced the same market conditions and may have held some of the same stocks, so their paired differences may be correlated. Daily forecast targets overlap, while the portfolio backtest uses 37 nonoverlapping holding periods. The fixed stock list and short test period limit how far the results generalize. Trading costs are modeled as a fixed charge per dollar traded.
