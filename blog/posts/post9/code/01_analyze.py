"""Rebuild all empirical outputs and the standalone blog."""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.stats import ttest_rel, t
from xgboost import XGBRegressor

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw"
CLEAN = ROOT / "data/cleaned"
FIG = ROOT / "results/figures"
TAB = ROOT / "results/tables"
for folder in (CLEAN, FIG, TAB):
    folder.mkdir(parents=True, exist_ok=True)
plt.rcParams.update({"figure.dpi": 140, "axes.spines.top": False,
                     "axes.spines.right": False, "font.size": 11})

# 1. Summarize classroom results
pairs = pd.read_csv(RAW / "class_visible_pairs.csv")
assert pairs.shape == (45, 2) and pairs.notna().all().all()
gap = pairs.portfolio2 - pairs.portfolio1
test = ttest_rel(pairs.portfolio2, pairs.portfolio1)
lo, hi = t.interval(.95, len(gap)-1, loc=gap.mean(), scale=gap.sem())
pd.DataFrame([dict(pairs=len(gap), intuition=pairs.portfolio1.mean(),
    historical_measures=pairs.portfolio2.mean(), mean_gap=gap.mean(),
    lower=lo, upper=hi, p=test.pvalue, wins=(gap>0).sum())]).to_csv(
    TAB / "class_summary.csv", index=False)
fig, ax = plt.subplots(figsize=(8, 3.6), layout="constrained")
ax.hist(gap, bins=np.arange(-15000, 27001, 3000), color="#267b81", edgecolor="white")
ax.axvline(0, color="#555", linestyle=":", label="No difference")
ax.axvline(gap.mean(), color="#9b4727", label="Mean difference")
ax.set(xlabel="Final value difference ($, historical measures minus intuition)", ylabel="Number of teams")
ax.legend(frameon=False)
fig.savefig(FIG / "class_gaps.png")
plt.close(fig)

# 2. Prepare stock returns and predictors
prices = pd.read_csv(RAW / "daily_prices.csv", parse_dates=["date"])
assert not prices.duplicated(["date", "symbol"]).any()
prices = prices.sort_values(["symbol", "date"])
spy = prices.loc[prices.symbol.eq("SPY")].set_index("date").adjusted
assert spy.index.is_monotonic_increasing and spy.notna().all()
calendar = spy.index
market_return = spy.pct_change(fill_method=None)

# A signal at session t uses data through its close. The original target
# enters at close t+1 and exits at close t+20 (19 close-to-close intervals).
panel = []
for symbol, block in prices.loc[prices.symbol.ne("SPY")].groupby("symbol"):
    frame = block.set_index("date").reindex(calendar)
    frame["symbol"] = symbol
    p = frame.adjusted
    r = p.pct_change(fill_method=None)
    frame["return"] = r
    frame["spy_ret"] = market_return
    frame["excess_ret"] = r - market_return
    for n, col in [(21, "mom_1m"), (63, "mom_3m"), (126, "mom_6m"), (5, "ret_5d")]:
        frame[col] = p.shift(n) / p.shift(1) - 1
        frame[f"trend_{n}"] = p.shift(1) / p.shift(n) - 1
    frame["market_trend"] = spy / spy.shift(63) - 1
    frame["relative_trend"] = p / p.shift(63) - spy / spy.shift(63)
    frame["volume_ratio"] = frame.volume / frame.volume.shift(1).rolling(21).mean() - 1
    frame["vol_1m"] = r.shift(1).rolling(22).std()
    frame["actual"] = p.shift(-20) / p.shift(-1) - 1
    frame["entry"] = calendar.to_series().shift(-1)
    frame["exit"] = calendar.to_series().shift(-20)
    panel.append(frame)
original = ["open", "high", "low", "close", "volume", "adjusted", "return",
            "spy_ret", "mom_1m", "mom_3m", "mom_6m", "vol_1m", "ret_5d", "excess_ret"]
improved = ["return", "spy_ret", "excess_ret", "trend_5", "trend_21",
            "trend_63", "trend_126", "vol_1m", "market_trend",
            "relative_trend", "volume_ratio"]
data = pd.concat(panel).replace([np.inf, -np.inf], np.nan)
data = data.dropna(subset=list(set(original + improved)) + ["actual", "entry", "exit"])
data = data.reset_index().sort_values(["date", "symbol"]).reset_index(drop=True)
data.to_csv(CLEAN / "daily_panel.csv", index=False)
# 3. Train, validate and score forecasts
# Train on 2022, choose parameters on 2023, and freeze models before 2024.
train = data.loc[data.exit.lt("2023-01-01")]
valid = data.loc[data.date.ge("2023-01-01") & data.exit.lt("2024-01-01")]
development = data.loc[data.exit.lt("2024-01-01")]
test_data = data.loc[data.date.ge("2024-01-01")].copy()
assert train.exit.max() < valid.date.min()
assert development.exit.max() < test_data.date.min()

def fit(frame, columns, trees, depth, rate):
    return XGBRegressor(n_estimators=trees, max_depth=depth,
        learning_rate=rate, min_child_weight=10, gamma=0,
        objective="reg:squarederror", tree_method="hist", n_jobs=2,
        random_state=123).fit(frame[columns], frame.actual)

grid = []
for trees in (50, 150, 300):
    for depth in (1, 3):
        for rate in (.02, .05):
            model = fit(train, improved, trees, depth, rate)
            rmse = np.sqrt(np.mean((valid.actual - model.predict(valid[improved]))**2))
            grid.append(dict(trees=trees, depth=depth, rate=rate, validation_rmse=rmse))
grid = pd.DataFrame(grid).sort_values("validation_rmse")
grid.to_csv(TAB / "validation_grid.csv", index=False)
best = grid.iloc[0]
test_data["mean"] = development.actual.mean()
test_data["original"] = fit(development, original, 300, 5, .05).predict(test_data[original])
test_data["tuned"] = fit(development, improved, int(best.trees), int(best.depth),
                         best.rate).predict(test_data[improved])
forecast_names = ["mean", "original", "tuned"]
test_data[["date","symbol","entry","exit","actual"] + forecast_names].to_csv(
    TAB / "predictions.csv", index=False)
labels = {"mean":"Historical mean", "original":"Original XGBoost model", 
          "tuned":"Tuned XGBoost", "equal":"Equal weight", "spy":"SPY"}
base_sse = ((test_data.actual-test_data["mean"])**2).sum()
scores = []
for name in forecast_names:
    error = test_data.actual-test_data[name]
    daily_rank = np.nan
    if name != "mean":
        ranks = test_data.groupby("date")[["actual",name]].rank()
        daily_rank = ranks.groupby(test_data.date).apply(
            lambda g: g.actual.corr(g[name])).mean()
    scores.append(dict(model=name, rmse=np.sqrt(np.mean(error**2)),
        mae=np.mean(abs(error)), r2_vs_mean=1-(error**2).sum()/base_sse,
        rank_ic=daily_rank))
predictions = pd.DataFrame(scores).set_index("model")
predictions.to_csv(TAB / "forecast_scores.csv")
# 4. Compare investment performance
# Consecutive blocks share the prior exit and next entry close. This aligns
# the exact benchmark interval, prevents overlap and keeps capital invested.
def backtest(frame, signal, cost):
    blocks = frame.groupby("date")
    assert (blocks.size() >= 10).all()
    universe = pd.Index(sorted(frame.symbol.unique()))
    rows = []
    drifted = pd.Series(0., index=universe)
    for day, block in blocks:
        block = block.set_index("symbol")
        entry, exit_date = block.entry.iloc[0], block.exit.iloc[0]
        if signal == "spy":
            gross = spy.loc[exit_date] / spy.loc[entry] - 1
            traded = float(not rows)
        else:
            if signal == "equal":
                selected = block
                weights = pd.Series(1/len(selected), index=selected.index)
            else:
                selected = block.nlargest(10, signal, keep="first")
                positive = selected[signal].clip(lower=0)
                weights = positive / positive.sum() if positive.sum() > 0 else (
                    pd.Series(1/len(selected), index=selected.index))
            gross = float(weights @ selected.actual)
            traded = (weights.reindex(universe, fill_value=0)-drifted).abs().sum()
            drifted = (weights*(1+selected.actual)/(1+gross)).reindex(universe, fill_value=0)
        net = (1-cost*traded)*(1+gross)-1
        rows.append((day, entry, exit_date, net, traded))
    return pd.DataFrame(rows, columns=["signal","entry","exit","net","traded"]).set_index("exit")

signal_days = calendar[(calendar >= "2024-01-01") &
                       (calendar <= test_data.date.max())][::19]
trade_data = test_data.loc[test_data.date.isin(signal_days)]
assert trade_data.date.nunique() == len(signal_days)
paths, metrics, returns = {}, [], []
periods_per_year = 252/19
for cost in (0, .001, .0025):
    for name in ("spy","equal","original","tuned"):
        path = backtest(trade_data, name, cost)
        returns.append(path.assign(strategy=name, cost=cost))
        wealth = (1+path.net).cumprod()
        peak = wealth.cummax().clip(lower=1)
        metrics.append(dict(strategy=name, cost=cost,
            annualized_return=wealth.iloc[-1]**(periods_per_year/len(path))-1,
            annualized_vol=path.net.std()*np.sqrt(periods_per_year),
            max_drawdown=(wealth/peak-1).min(), average_traded=path.traded.mean(),
            ending_wealth=wealth.iloc[-1]*10000))
        if cost == .001:
            paths[name] = pd.concat([pd.Series([10000], index=[path.entry.iloc[0]]), wealth*10000])
metrics = pd.DataFrame(metrics)
metrics.to_csv(TAB / "investment_scores.csv", index=False)
pd.concat(returns).to_csv(TAB / "portfolio_periods.csv")
wealth = pd.DataFrame(paths).rename_axis("date")
wealth.to_csv(TAB / "wealth_paths.csv")
fig, ax = plt.subplots(figsize=(8, 4), layout="constrained")
for col, color in zip(wealth, ["#536173", "#827032", "#ac5937", "#167779"]):
    ax.plot(wealth.index, wealth[col], label=labels[col], color=color)
ax.set(ylabel="Value of $10,000 ($)", xlabel="Holding period end")
ax.legend(frameon=False, ncol=2)
ax.grid(axis="y", alpha=.25)
fig.savefig(FIG / "wealth.png")
plt.close(fig)
