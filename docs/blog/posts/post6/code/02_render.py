"""Recompute results and check the concise tutorial when Quarto renders it."""
from pathlib import Path
import contextlib
import io
import json
import os
import re
import runpy
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]


def check_tutorial(analysis):
    article = (ROOT / 'index.qmd').read_text(encoding='utf-8')
    blocks = re.findall(r'^```python\n(.*?)^```\s*$', article, re.MULTILINE | re.DOTALL)
    if not blocks:
        raise ValueError('No Python tutorial blocks found')
    script = ROOT / 'code/04_tutorial.py'
    preamble = ('"""Executable code displayed in index.qmd, in reading order."""\n'
                'from pathlib import Path\nimport os\n'
                'os.chdir(Path(__file__).resolve().parents[1])\n\n')
    script.write_text(preamble + '\n\n'.join(block.rstrip() for block in blocks) + '\n', encoding='utf-8')
    namespace = {'__file__': str(script), '__name__': 'blog6_tutorial'}
    previous_directory = Path.cwd()
    try:
        os.chdir(ROOT)
        with contextlib.redirect_stdout(io.StringIO()):
            for number, block in enumerate(blocks, 1):
                exec(compile(block, 'index.qmd: block ' + str(number), 'exec'), namespace)
    finally:
        os.chdir(previous_directory)
    expected_sample = analysis['sample']
    actual_sample = namespace['sample']
    assert len(actual_sample) == len(expected_sample)
    columns = list(actual_sample.columns)
    pd.testing.assert_frame_equal(actual_sample.reset_index(drop=True),
                                  expected_sample[columns].reset_index(drop=True), rtol=1e-12, atol=1e-10)
    actual = namespace['estimates'].set_index('model')
    expected = analysis['estimates'].set_index('model')
    for column in ['ige', 'se', 'ci_low', 'ci_high']:
        np.testing.assert_allclose(actual[column], expected[column], rtol=1e-12, atol=1e-12)
    report = {'status': 'PASS', 'visible_python_blocks_executed': len(blocks),
              'visible_code_lines': sum(len(b.strip().splitlines()) for b in blocks),
              'sample_matches_complete_backend': True,
              'coefficients_standard_errors_intervals_match': True,
              'n_children': len(actual_sample), 'n_mothers': int(actual_sample.mother_id.nunique())}
    (ROOT / 'results/tables/tutorial_validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return report


def article_values():
    analysis = runpy.run_path(str(ROOT / 'code/01_analyze.py'))['run']()
    check_tutorial(analysis)
    facts = analysis['facts']
    estimates = analysis['estimates'].set_index('model')
    values = {key: f'{value:,}' if isinstance(value, int) else str(value) for key, value in facts.items()}
    for key, row in estimates.iterrows():
        values[key] = f'{row.ige:.3f}'
        values[key + '_ci'] = f'{row.ci_low:.3f} to {row.ci_high:.3f}'
    contrast = analysis['contrasts'].set_index('contrast')
    values['age_difference'] = f"{estimates.loc['late_mean', 'ige'] - estimates.loc['early_mean', 'ige']:.3f}"
    for key, row in contrast.iterrows():
        values[key + '_ci'] = f'{row.ci_low:.3f} to {row.ci_high:.3f}'
    (ROOT / 'results/tables/article_values.json').write_text(json.dumps(values, indent=2) + '\n', encoding='utf-8')
    return values


if __name__ == '__main__':
    print(json.dumps(article_values(), ensure_ascii=True))
