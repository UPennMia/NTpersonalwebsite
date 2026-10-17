"""Create small, unaltered-column extracts from the official NLS public files.

Normal analysis uses the included extracts, not the multi-gigabyte full files.
Run with --refresh to download and reconstruct them. Requires about 1 GB of
temporary disk space; the CSV members are read directly from the ZIP streams.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import tempfile
import urllib.request
import zipfile
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'data' / 'raw'
URLS = {
    'mothers': 'https://nlsinfo.org/cohort-data/nlsy79_all_1979-2022.zip',
    'children': 'https://nlsinfo.org/cohort-data/nlscya_all_1979-2020.zip',
}
# The standard FRED CSV endpoint is used below; its full monthly series is
# reduced to 1990-2021 without changing any observation's value.
CPI_URL = 'https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCNS&cosd=1990-01-01&coed=2021-12-01'


def sha256(path):
    with path.open('rb') as stream:
        digest = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
        return digest.hexdigest()


def download(url, path):
    request = urllib.request.Request(url, headers={'User-Agent': 'Blog6 academic replication'})
    with urllib.request.urlopen(request, timeout=120) as response, path.open('wb') as out:
        while chunk := response.read(1024 * 1024):
            out.write(chunk)


def codeblocks(text):
    result = []
    for block in re.split(r'\n-{20,}\n', text):
        match = re.match(r'([A-Z]\d{5}\.\d{2})\s+\[([^\]]+)\].*Survey Year:\s*(\S+)', block)
        if match:
            ref, question, wave = match.groups()
            result.append({'ref': ref, 'column': ref.replace('.', ''),
                           'question': question, 'wave': wave, 'block': block})
    return result


def selected_variables(blocks, cohort):
    chosen = []

    def add(role, candidates, wave='XRND'):
        found = [b for b in blocks if b['ref'] in candidates]
        if not found:
            raise ValueError(f'Missing codebook variable: {cohort}, {role}, {wave}')
        item = found[0].copy()
        item.update(cohort=cohort, role=role, wave=wave)
        chosen.append(item)

    def question(role, names, year):
        for name in names:
            found = [b for b in blocks if b['question'] == name and b['wave'] == str(year)
                     and (cohort == 'mothers' or b['ref'].startswith('Y'))]
            if len(found) == 1:
                add(role, [found[0]['ref']], year)
                return
        raise ValueError(f'Cannot uniquely resolve {cohort} {role} in {year}')

    if cohort == 'mothers':
        for role, ref in [('id', 'R00001.00'), ('birth_year', 'R00005.00'), ('sex', 'R02148.00')]:
            add(role, [ref])
        for year in [1993, 1994, 1996, 1998, 2000, 2002, 2004]:
            question('wages', ['Q13-5_TRUNC_REVISED', 'Q13-5_TRUNC', 'Q13-5'], year)
            question('military_receipt', ['Q13-2'], year)
            question('military_amount', ['Q13-3_TRUNC_REVISED', 'Q13-3_TRUNC', 'Q13-3'], year)
    else:
        for role, ref in [('id', 'C00001.00'), ('mother_id', 'C00002.00'),
                          ('birth_year', 'C00057.00'), ('sex', 'C00054.00')]:
            add(role, [ref])
        for year in range(1994, 2021, 2):
            question('wages', ['Q15-5-TOP', 'Q15-5'], year)
            if year < 2000:
                question('military_receipt', ['Q15-2'], year)
                question('military_amount', ['Q15-3'], year)
            if year >= 2014:
                question('interview_year', ['CURDATE~Y'], year)
    return chosen


def build(archive_dir):
    RAW.mkdir(parents=True, exist_ok=True)
    variables, notes, archives = [], [], {}
    for cohort, url in URLS.items():
        archive = archive_dir / f'{cohort}.zip'
        if not archive.exists():
            print(f'Downloading official {cohort} file...', flush=True)
            download(url, archive)
        archives[cohort] = {'url': url, 'sha256': sha256(archive), 'bytes': archive.stat().st_size}
        with zipfile.ZipFile(archive) as bundle:
            cdb = next(n for n in bundle.namelist() if n.endswith('.cdb'))
            selected = selected_variables(codeblocks(bundle.read(cdb).decode()), cohort)
            columns = list(dict.fromkeys(v['column'] for v in selected))
            csv = next(n for n in bundle.namelist() if n.endswith('.csv'))
            print(f'Reading {cohort} CSV stream: {len(columns)} selected columns...', flush=True)
            with bundle.open(csv) as stream:
                frame = pd.read_csv(stream, usecols=columns, dtype='int64')
            frame[columns].to_csv(RAW / f'{cohort}_selected.csv', index=False)
            for item in selected:
                notes.append(f"{cohort} / {item['role']} / {item['wave']}\n{item['block']}\n")
                variables.append({k: v for k, v in item.items() if k != 'block'})
    pd.DataFrame(variables).to_csv(RAW / 'variable_map.csv', index=False)
    (RAW / 'selected_codebook.txt').write_text('\n' + ('\n' + '-' * 80 + '\n').join(notes), encoding='utf-8')
    cpi_file = archive_dir / 'cpi_download.csv'
    download(CPI_URL, cpi_file)
    cpi = pd.read_csv(cpi_file)
    cpi.columns = ['observation_date', 'CPIAUCNS']
    cpi = cpi[cpi.observation_date.between('1990-01-01', '2021-12-31')]
    pd.to_numeric(cpi.CPIAUCNS, errors='raise')
    cpi.to_csv(RAW / 'cpi_monthly.csv', index=False)
    paths = sorted(p for p in RAW.iterdir() if p.is_file() and p.name != 'source_manifest.json')
    from datetime import date
    manifest = {'retrieved_utc': date.today().isoformat(), 'archives': archives,
                'cpi_url': CPI_URL, 'cpi_series': 'CPIAUCNS: BLS CPI-U, all items, not seasonally adjusted',
                'note': 'Selected official columns, all original rows and negative codes retained. No simulated records.',
                'files': {p.name: sha256(p) for p in paths}}
    (RAW / 'source_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Saved official-data extracts and their codebook/provenance.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh', action='store_true', help='rebuild extracts from full official downloads')
    parser.add_argument('--archive-dir', type=Path, help='reuse official ZIPs named mothers.zip and children.zip')
    args = parser.parse_args()
    if (RAW / 'source_manifest.json').exists() and not args.refresh:
        print('Saved extracts already exist. Use --refresh only to download them again.')
    elif args.archive_dir:
        build(args.archive_dir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='blog6_nls_') as directory:
            build(Path(directory))
