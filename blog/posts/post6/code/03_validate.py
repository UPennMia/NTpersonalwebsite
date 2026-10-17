"""Independently check the saved SQL and OLS results after running analysis."""
from pathlib import Path
import json
import runpy
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]


def validate():
    module = runpy.run_path(str(ROOT / 'code/01_analyze.py'))
    module['check_sources']()
    clean, tables = ROOT / 'data/cleaned', ROOT / 'results/tables'
    panel = pd.read_csv(clean / 'person_income.csv')
    summaries = pd.read_csv(clean / 'income_summaries.csv')
    sample = pd.read_csv(clean / 'matched_sample.csv')
    estimates = pd.read_csv(tables / 'ige_estimates.csv').set_index('model')
    assert not panel.duplicated(['generation', 'person_id', 'income_year']).any()
    assert sample.child_id.is_unique
    assert sample[['mother_years', 'early_years', 'late_years']].ge(2).all().all()
    assert sample[['mother_single', 'mother_mean', 'early_single', 'early_mean', 'late_single', 'late_mean']].gt(0).all().all()

    # Validate links against untouched official identifier columns.
    children = pd.read_csv(ROOT / 'data/raw/children_selected.csv').set_index('C0000100')
    assert np.array_equal(children.loc[sample.child_id, 'C0000200'].to_numpy(), sample.mother_id.to_numpy())
    maternal_ids = pd.read_csv(ROOT / 'data/raw/mothers_selected.csv').R0000100
    assert sample.mother_id.isin(maternal_ids).all()

    # Independent pandas reconstruction of SQL AVG, COUNT and year selection.
    for generation, window, lo, hi, center in [
            ('mother', 'mother_35_39', 35, 39, 37),
            ('child', 'child_20_29', 20, 29, 25),
            ('child', 'child_30_39', 30, 39, 35)]:
        eligible = panel[panel.generation.eq(generation) & panel.age.between(lo, hi)
                         & panel.earnings_real.ge(0)].copy()
        by_person = eligible.groupby('person_id').earnings_real.agg(['mean', 'count'])
        sql = summaries[summaries.window.eq(window)].set_index('person_id').sort_index()
        assert sql.index.equals(by_person.index)
        np.testing.assert_allclose(sql.mean_income, by_person['mean'], rtol=1e-12)
        np.testing.assert_array_equal(sql.n_years, by_person['count'])
        eligible['distance'] = abs(eligible.age - center)
        chosen = eligible.sort_values(['distance', 'income_year', 'survey_year']).drop_duplicates('person_id').set_index('person_id')
        np.testing.assert_allclose(sql.single_income, chosen.loc[sql.index, 'earnings_real'], rtol=1e-12)

    # Independent normal equations and cluster sandwich covariance, using
    # NumPy only, checked against statsmodels' reported point estimates/SEs.
    groups, mother_ids = pd.factorize(sample.mother_id, sort=True)
    n, g = len(sample), len(mother_ids)
    for key, _, y_column, x_column in module['MODELS']:
        x = np.column_stack([np.ones(n), np.log(sample[x_column])])
        y = np.log(sample[y_column]).to_numpy()
        inverse = np.linalg.inv(x.T @ x)
        coefficients = inverse @ x.T @ y
        residual = y - x @ coefficients
        scores = np.zeros((g, 2))
        np.add.at(scores, groups, x * residual[:, None])
        covariance = inverse @ scores.T @ scores @ inverse * g / (g - 1) * (n - 1) / (n - 2)
        np.testing.assert_allclose(coefficients[1], estimates.loc[key, 'ige'], atol=1e-11)
        np.testing.assert_allclose(np.sqrt(covariance[1, 1]), estimates.loc[key, 'se'], atol=1e-11)
        assert estimates.loc[key, 'n_pairs'] == n

    draws = pd.read_csv(tables / 'bootstrap_draws.csv')
    contrasts = pd.read_csv(tables / 'paired_contrasts.csv').set_index('contrast')
    assert len(draws) == module['REPS'] and np.isfinite(draws.to_numpy()).all()
    for name, a, b in [('late_minus_early_mean', 'late_mean', 'early_mean'),
                        ('averaging_change_early', 'early_mean', 'early_single'),
                        ('averaging_change_late', 'late_mean', 'late_single')]:
        np.testing.assert_allclose(np.quantile(draws[a] - draws[b], [.025, .975]),
                                   contrasts.loc[name, ['ci_low', 'ci_high']].to_numpy(dtype=float), atol=1e-12)
    report = {'status': 'PASS', 'checks': ['raw checksums', 'original-ID mother–child links',
              'SQL aggregation versus independent pandas calculations', 'single-year selection including zero years',
              'OLS and mother-cluster standard errors versus NumPy calculations', 'common sample across specifications',
              'paired bootstrap interval calculations'], 'n_pairs': n, 'n_mothers': g}
    (tables / 'independent_validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    validate()
