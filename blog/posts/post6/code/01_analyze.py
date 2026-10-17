"""Rebuild the Blog6 analysis, using saved official data and SQL in Python.

Run from any directory: python path/to/post6/code/01_analyze.py
No downloads are made by this script. The article rebuild script also calls run().
"""
from pathlib import Path
import hashlib
import importlib.metadata
import json
import platform
import sqlite3
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import statsmodels.api as sm
from scipy.stats import t

ROOT = Path(__file__).resolve().parents[1]
RAW, CLEAN = ROOT / 'data/raw', ROOT / 'data/cleaned'
FIG, TAB = ROOT / 'results/figures', ROOT / 'results/tables'
SEED, REPS = 20261016, 2000
MODELS = [
    ('early_single', '20–29: single year', 'early_single', 'mother_single'),
    ('early_mean', '20–29: multi-year mean', 'early_mean', 'mother_mean'),
    ('late_single', '30–39: single year', 'late_single', 'mother_single'),
    ('late_mean', '30–39: multi-year mean', 'late_mean', 'mother_mean'),
]


def check_sources():
    manifest = json.loads((RAW / 'source_manifest.json').read_text())
    for name, expected in manifest['files'].items():
        with (RAW / name).open('rb') as stream:
            actual = hashlib.sha256(stream.read()).hexdigest()
        if actual != expected:
            raise ValueError(f'Raw snapshot has changed: {name}. Restore it or explicitly refresh the extracts.')
    return manifest


def clean_cohort(cohort, variable_map):
    """Keep negative codes in raw; map them to missing only in analysis."""
    raw = pd.read_csv(RAW / f'{cohort}_selected.csv')
    mapping = variable_map[variable_map.cohort.eq(cohort)]

    def field(role, wave='XRND'):
        rows = mapping[mapping.role.eq(role) & mapping.wave.eq(str(wave))]
        if len(rows) != 1:
            raise ValueError(f'Expected one mapping for {cohort} {role} {wave}')
        return raw[rows.iloc[0]['column']].copy()

    people = pd.DataFrame({'person_id': field('id'), 'birth_year': field('birth_year'), 'sex': field('sex')})
    people.loc[people.birth_year.between(0, 99), 'birth_year'] += 1900
    if cohort == 'mothers':
        people = people[people.sex.eq(2)].copy()
        people = people.rename(columns={'person_id': 'mother_id'})
        generation, id_column = 'mother', 'mother_id'
    else:
        people['mother_id'] = field('mother_id')
        people = people.rename(columns={'person_id': 'child_id'})
        generation, id_column = 'child', 'child_id'
    valid_birth = people.birth_year.between(1957, 1964) if cohort == 'mothers' else people.birth_year.between(1960, 2020)
    people = people[valid_birth & people[id_column].gt(0) & people.sex.isin([1, 2])].copy()
    if people[id_column].duplicated().any():
        raise ValueError('Duplicate person identifier')
    waves = sorted(int(x) for x in mapping.loc[mapping.role.eq('wages'), 'wave'])
    frames = []
    for wave in waves:
        wage = field('wages', wave).where(lambda x: x.ge(0))
        # A documented 'No' to military receipt is a true zero. Other skips,
        # refusals and don't-knows remain missing; none are recoded to zero.
        if cohort == 'mothers' or wave < 2000:
            receipt, amount = field('military_receipt', wave), field('military_amount', wave)
            military = amount.where(receipt.eq(1) & amount.ge(0))
            military = military.mask(receipt.eq(0), 0)
            earnings = wage + military
        else:
            # Child Q15-5-TOP includes military earnings from 2000 onward.
            earnings = wage
        if cohort == 'children' and wave >= 2014:
            interview_year = field('interview_year', wave)
            income_year = (interview_year - 1).where(interview_year.between(wave, wave + 2))
        else:
            # Earlier questionnaires explicitly name the calendar year.
            income_year = pd.Series(wave - 1, index=raw.index)
        frame = pd.DataFrame({'person_id': field('id'), 'survey_year': wave,
                              'income_year': income_year, 'earnings_nominal': earnings})
        frames.append(frame)
    panel = pd.concat(frames, ignore_index=True).merge(
        people.rename(columns={id_column: 'person_id'})[['person_id', 'birth_year']],
        on='person_id', how='inner', validate='many_to_one')
    panel['generation'] = generation
    panel['age'] = panel.income_year - panel.birth_year  # age at end of income year
    panel.loc[~panel.age.between(0, 90), 'earnings_nominal'] = np.nan
    panel = panel.dropna(subset=['income_year']).copy()
    panel.income_year = panel.income_year.astype(int)
    # A late interview can overlap the next wave's income reference year.
    # Retain the later survey's valid report, once per person/calendar year.
    duplicate_count = panel.duplicated(['generation', 'person_id', 'income_year']).sum()
    panel['valid_report'] = panel.earnings_nominal.notna()
    panel = panel.sort_values(['valid_report', 'survey_year']).drop_duplicates(
        ['generation', 'person_id', 'income_year'], keep='last').drop(columns='valid_report')
    return people, panel, int(duplicate_count)


def estimate(sample, y_column, x_column):
    x, y = np.log(sample[x_column]), np.log(sample[y_column])
    model = sm.OLS(y.to_numpy(), sm.add_constant(x.to_numpy())).fit()
    result = model.get_robustcov_results(cov_type='cluster', groups=sample.mother_id.to_numpy(),
                                       use_correction=True, df_correction=True, use_t=True)
    beta, se = float(result.params[1]), float(result.bse[1])
    critical = t.ppf(.975, sample.mother_id.nunique() - 1)
    return {'ige': beta, 'se': se, 'ci_low': beta - critical * se,
            'ci_high': beta + critical * se, 'n_pairs': len(sample),
            'n_mothers': sample.mother_id.nunique(), 'r_squared': float(model.rsquared)}


def paired_bootstrap(sample):
    """Resample mothers with all their children; retain paired specifications."""
    group, unique = pd.factorize(sample.mother_id, sort=True)
    rng = np.random.default_rng(SEED)
    output = []
    logs = [(np.log(sample[x].to_numpy()), np.log(sample[y].to_numpy())) for _, _, y, x in MODELS]
    for _ in range(REPS):
        weight = np.bincount(rng.integers(0, len(unique), size=len(unique)), minlength=len(unique))[group]
        slopes = []
        for x, y in logs:
            mx, my = np.average(x, weights=weight), np.average(y, weights=weight)
            slopes.append(np.sum(weight * (x - mx) * (y - my)) / np.sum(weight * (x - mx) ** 2))
        output.append(slopes)
    draws = pd.DataFrame(output, columns=[m[0] for m in MODELS])
    contrasts = []
    for name, left, right in [('late_minus_early_mean', 'late_mean', 'early_mean'),
                              ('averaging_change_early', 'early_mean', 'early_single'),
                              ('averaging_change_late', 'late_mean', 'late_single')]:
        lo, hi = np.quantile(draws[left] - draws[right], [.025, .975])
        contrasts.append({'contrast': name, 'ci_low': lo, 'ci_high': hi, 'replications': REPS, 'seed': SEED})
    return draws, pd.DataFrame(contrasts)


def lifecycle_benchmark():
    # Known, constructed lifetime relationship; not survey observations.
    parent_log = np.array([9., 10., 11., 12.])
    lifetime = 6 + .4 * parent_log
    early = 3 + .5 * lifetime
    early_mean = np.log(np.exp(early[:, None] + np.array([-.05, 0., .05])).mean(axis=1))
    outcomes = [('Lifetime', lifetime), ('Early single year', early),
                ('Early three-year mean', early_mean), ('Later career', lifetime)]
    result = pd.DataFrame([{'measurement': label, 'ige': np.polyfit(parent_log, y, 1)[0]}
                           for label, y in outcomes])
    np.testing.assert_allclose(result.ige, [.4, .2, .2, .4], atol=1e-12)
    return result


def make_figures(sample, estimates, summaries):
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 11,
                         'axes.spines.top': False, 'axes.spines.right': False,
                         'axes.labelcolor': '#253442', 'text.color': '#253442',
                         'savefig.dpi': 170})
    blue, orange = '#326987', '#bb7040'
    fig, ax = plt.subplots(figsize=(8.4, 4.6), layout='constrained')
    for j, age in enumerate(['20–29', '30–39']):
        for k, method in enumerate(['single', 'mean']):
            row = estimates.set_index('model').loc[('early' if j == 0 else 'late') + '_' + method]
            pos = j + (k - .5) * .18
            ax.errorbar(row.ige, pos, xerr=[[row.ige - row.ci_low], [row.ci_high - row.ige]],
                        fmt='o' if k else 's', color=blue if k else orange, capsize=4,
                        markersize=7, label=('Multi-year mean' if k else 'Single year') if j == 0 else None)
            ax.annotate(f'{row.ige:.3f}', (row.ige, pos), xytext=(0, 11), textcoords='offset points', ha='center', fontsize=10)
    ax.set(yticks=[0, 1], yticklabels=['Child ages 20–29', 'Child ages 30–39'], ylim=(-.5, 1.5),
           xlabel='Intergenerational earnings elasticity (IGE)', title='The estimate depends on when and how income is measured')
    ax.axvline(0, color='#9ba8b2', linewidth=.8)
    ax.grid(axis='x', alpha=.16)
    ax.legend(frameon=False, loc='upper left')
    fig.savefig(FIG / '01_ige_comparison.png'); plt.close(fig)

    fig, axes = plt.subplots(1, 2, figsize=(9, 4.4), sharex=True, sharey=True, layout='constrained')
    x = np.log(sample.mother_mean)
    bins = pd.qcut(x, 10, labels=False, duplicates='drop')
    binned = []
    for ax, column, label, color in zip(axes, ['early_mean', 'late_mean'], ['Child ages 20–29', 'Child ages 30–39'], [orange, blue]):
        y = np.log(sample[column])
        grouped = pd.DataFrame({'bin': bins, 'x': x, 'y': y}).groupby('bin', as_index=False).mean()
        grouped['stage'] = label; binned.append(grouped)
        ax.scatter(x, y, s=9, alpha=.11, color=color, edgecolors='none')
        fit = np.polyfit(x, y, 1); grid = np.linspace(x.min(), x.max(), 100)
        ax.plot(grid, fit[0] * grid + fit[1], color=color, linewidth=2)
        ax.scatter(grouped.x, grouped.y, s=32, color=color, edgecolors='white', linewidth=.6)
        ax.set(title=label, xlabel="Log mother's mean annual earnings")
        ax.grid(alpha=.12)
    axes[0].set_ylabel("Log child's mean annual earnings")
    fig.suptitle('The same mother–child pairs at two stages of adulthood', fontsize=13)
    fig.savefig(FIG / '02_income_relationship.png'); plt.close(fig)
    pd.concat(binned, ignore_index=True).to_csv(TAB / 'binned_scatter.csv', index=False)


def run():
    for folder in [CLEAN, FIG, TAB]: folder.mkdir(parents=True, exist_ok=True)
    manifest = check_sources()
    variable_map = pd.read_csv(RAW / 'variable_map.csv', dtype={'wave': str})
    mothers, maternal, dm = clean_cohort('mothers', variable_map)
    children, offspring, dc = clean_cohort('children', variable_map)
    incomes = pd.concat([maternal, offspring], ignore_index=True)
    cpi = pd.read_csv(RAW / 'cpi_monthly.csv', parse_dates=['observation_date'])
    cpi['year'] = cpi.observation_date.dt.year
    cpi.CPIAUCNS = pd.to_numeric(cpi.CPIAUCNS, errors='raise')
    annual = cpi.groupby('year').CPIAUCNS.agg(['mean', 'count'])
    if not annual['count'].eq(12).all(): raise ValueError('CPI must contain 12 months per year')
    annual.to_csv(CLEAN / 'cpi_annual.csv', index_label='year')
    incomes['cpi'] = incomes.income_year.map(annual['mean'])
    # Only years that could fall within the specified age windows are needed.
    candidate = ((incomes.generation.eq('mother') & incomes.age.between(35, 39)) |
                 (incomes.generation.eq('child') & (incomes.age.between(20, 29) | incomes.age.between(30, 39))))
    if incomes.loc[candidate & incomes.earnings_nominal.notna(), 'cpi'].isna().any():
        raise ValueError('Missing CPI for an eligible income year')
    incomes['earnings_real'] = incomes.earnings_nominal * annual.loc[2020, 'mean'] / incomes.cpi
    windows = pd.DataFrame([
        ['mother', 'mother_35_39', 35, 39, 37],
        ['child', 'child_20_29', 20, 29, 25],
        ['child', 'child_30_39', 30, 39, 35]],
        columns=['generation', 'window', 'min_age', 'max_age', 'center_age'])
    # A compact teaching input retains person-years; it does not precompute
    # means or intergenerational matches. The article performs those in SQL.
    tutorial_parts = []
    for row in windows.itertuples(index=False):
        part = incomes[incomes.generation.eq(row.generation)
                       & incomes.age.between(row.min_age, row.max_age)
                       & incomes.earnings_real.ge(0)].copy()
        part['window'] = row.window
        part['distance'] = abs(part.age - row.center_age)
        part = part.sort_values(['person_id', 'distance', 'income_year', 'survey_year'])
        part['is_single'] = (~part.person_id.duplicated()).astype(int)
        tutorial_parts.append(part[['generation', 'person_id', 'window',
                                    'income_year', 'age', 'earnings_real', 'is_single']])
    pd.concat(tutorial_parts, ignore_index=True).to_csv(CLEAN / 'tutorial_income.csv', index=False)
    with sqlite3.connect(':memory:') as connection:
        for name, frame in [('mothers', mothers), ('children', children), ('incomes', incomes), ('windows', windows)]:
            frame.to_sql(name, connection, index=False)
        pairs = pd.read_sql_query((ROOT / 'code/01_match.sql').read_text(), connection)
        summaries = pd.read_sql_query((ROOT / 'code/02_income.sql').read_text(), connection)
        pairs.to_sql('pairs', connection, index=False)
        summaries.to_sql('summaries', connection, index=False)
        sample = pd.read_sql_query((ROOT / 'code/03_sample.sql').read_text(), connection)
    assert not pairs.child_id.duplicated().any(), 'JOIN duplicated a child'
    assert not sample.child_id.duplicated().any(), 'Final sample duplicated a child'
    assert len(sample) > 100 and sample.mother_id.nunique() > 50, 'Unexpected sample loss'
    assert not incomes.duplicated(['generation', 'person_id', 'income_year']).any()
    for frame, name in [(mothers, 'mothers'), (children, 'children'), (incomes, 'person_income'),
                        (pairs, 'parent_child_links'), (summaries, 'income_summaries'), (sample, 'matched_sample')]:
        frame.to_csv(CLEAN / f'{name}.csv', index=False)
    estimates = pd.DataFrame([{'model': key, 'label': label, **estimate(sample, y, x)}
                             for key, label, y, x in MODELS])
    estimates.to_csv(TAB / 'ige_estimates.csv', index=False)
    lifecycle_benchmark().to_csv(TAB / 'lifecycle_benchmark.csv', index=False)
    draws, contrasts = paired_bootstrap(sample)
    draws.to_csv(TAB / 'bootstrap_draws.csv', index=False)
    contrasts.to_csv(TAB / 'paired_contrasts.csv', index=False)
    # A child-sex sensitivity check is saved separately from the
    # unadjusted, clearly defined tutorial estimates.
    sensitivity = []
    for key, label, y, x in MODELS:
        for sex in [1, 2]:
            part = sample[sample.child_sex.eq(sex)]
            sensitivity.append({'model': key, 'child_sex': sex, **estimate(part, y, x)})
    pd.DataFrame(sensitivity).to_csv(TAB / 'sex_sensitivity.csv', index=False)
    counts = {'official_child_rows': len(pd.read_csv(RAW / 'children_selected.csv')),
              'children_with_valid_demographics': len(children), 'matched_children': len(pairs),
              'n_pairs': len(sample), 'n_mothers': int(sample.mother_id.nunique()),
              'duplicate_maternal_income_years_removed': dm, 'duplicate_child_income_years_removed': dc,
              'child_birth_min': int(sample.child_birth_year.min()), 'child_birth_max': int(sample.child_birth_year.max()),
              'retrieved_utc': manifest['retrieved_utc'], 'bootstrap_reps': REPS, 'seed': SEED}
    # Record progressive coverage losses to make the balanced sample transparent.
    coverage = pairs[['child_id', 'mother_id']].copy()
    for prefix, gen, window, id_col in [('mother', 'mother', 'mother_35_39', 'mother_id'),
                                       ('early', 'child', 'child_20_29', 'child_id'),
                                       ('late', 'child', 'child_30_39', 'child_id')]:
        summary = summaries[summaries.generation.eq(gen) & summaries.window.eq(window)]
        coverage = coverage.merge(summary[['person_id', 'n_years', 'mean_income', 'single_income']].rename(
            columns={'person_id': id_col, 'n_years': prefix + '_years', 'mean_income': prefix + '_mean',
                     'single_income': prefix + '_single'}), on=id_col, how='left', validate='many_to_one')
    coverage['two_years_each'] = coverage[['mother_years', 'early_years', 'late_years']].ge(2).all(axis=1)
    counts['two_years_each'] = int(coverage.two_years_each.sum())
    counts['excluded_for_nonpositive_log_income'] = counts['two_years_each'] - len(sample)
    coverage.to_csv(TAB / 'sample_coverage.csv', index=False)
    sample[['mother_years', 'early_years', 'late_years', 'mother_mean_age', 'early_mean_age', 'late_mean_age']].describe().to_csv(TAB / 'sample_description.csv')
    make_figures(sample, estimates, summaries)
    (TAB / 'key_facts.json').write_text(json.dumps(counts, indent=2) + '\n')
    packages = ['numpy', 'pandas', 'matplotlib', 'scipy', 'statsmodels']
    versions = {'Python': platform.python_version(), 'SQLite': sqlite3.sqlite_version,
                **{name: importlib.metadata.version(name) for name in packages}}
    (TAB / 'environment.json').write_text(json.dumps(versions, indent=2) + '\n')
    (TAB / 'validation.txt').write_text(
        'PASS: raw snapshot checksums match source manifest.\n'
        'PASS: unique demographic IDs; one row per child after JOIN.\n'
        'PASS: one record per generation/person/income year.\n'
        'PASS: CPI has twelve months per year and covers every eligible income year.\n'
        'PASS: all four regressions use the same positive-log-income balanced sample.\n'
        f'PASS: {len(sample)} children linked to {sample.mother_id.nunique()} mothers.\n'
        f'PASS: {REPS} paired mother-cluster bootstrap draws, seed {SEED}.\n')
    return {'sample': sample, 'estimates': estimates, 'contrasts': contrasts, 'facts': counts}


if __name__ == '__main__':
    output = run()
    print(output['estimates'].to_string(index=False))
    print(f"Saved results in {ROOT / 'results'}")
