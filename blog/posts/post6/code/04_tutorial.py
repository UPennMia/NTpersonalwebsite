"""Executable code displayed in index.qmd, in reading order."""
from pathlib import Path
import os
os.chdir(Path(__file__).resolve().parents[1])

import sqlite3
import pandas as pd
import numpy as np
import statsmodels.api as sm

con = sqlite3.connect(":memory:")
for table in ("mothers", "children", "tutorial_income"):
    pd.read_csv(f"data/cleaned/{table}.csv").to_sql(table, con, index=False)

pairs = pd.read_sql_query("""
    SELECT c.child_id, c.mother_id
    FROM children AS c
    JOIN mothers AS m ON c.mother_id = m.mother_id
    ORDER BY c.child_id
""", con)
pairs.to_sql("pairs", con, index=False)

summaries = pd.read_sql_query("""
    SELECT generation, person_id, window,
           AVG(earnings_real) AS mean_income, COUNT(*) AS n_years,
           MAX(CASE WHEN is_single = 1 THEN earnings_real END) AS single_income
    FROM tutorial_income
    WHERE earnings_real >= 0
    GROUP BY generation, person_id, window
""", con)
summaries.to_sql("summaries", con, index=False)

sample = pd.read_sql_query("""
    SELECT p.child_id, p.mother_id,
           m.mean_income AS mother_mean, m.single_income AS mother_single,
           e.mean_income AS early_mean, e.single_income AS early_single,
           l.mean_income AS late_mean, l.single_income AS late_single
    FROM pairs AS p
    JOIN summaries AS m ON m.person_id = p.mother_id AND m.window = 'mother_35_39'
    JOIN summaries AS e ON e.person_id = p.child_id AND e.window = 'child_20_29'
    JOIN summaries AS l ON l.person_id = p.child_id AND l.window = 'child_30_39'
    WHERE m.n_years >= 2 AND e.n_years >= 2 AND l.n_years >= 2
      AND m.single_income > 0 AND e.single_income > 0 AND l.single_income > 0
    ORDER BY p.child_id
""", con)

rows = []
for stage in ("early", "late"):
    for measure in ("single", "mean"):
        x = sm.add_constant(np.log(sample[f"mother_{measure}"]).to_numpy())
        y = np.log(sample[f"{stage}_{measure}"]).to_numpy()
        fit = sm.OLS(y, x).fit(cov_type="cluster",
                             cov_kwds={"groups": sample.mother_id}, use_t=True)
        low, high = fit.conf_int()[1]
        rows.append({"model": f"{stage}_{measure}", "ige": fit.params[1],
                     "se": fit.bse[1], "ci_low": low, "ci_high": high})
estimates = pd.DataFrame(rows)
con.close()
