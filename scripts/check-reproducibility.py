"""Compare two clean renders, including fresh R execution, outside the checkout."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]

def hashes(directory):
    return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.rglob('*')) if p.is_file()}

with tempfile.TemporaryDirectory(prefix='bety-repro-') as temp:
    project = Path(temp) / 'project'
    shutil.copytree(root, project, ignore=shutil.ignore_patterns(
        '.git', '.quarto', '_freeze', '_site', 'site-data', 'node_modules',
        'test-results', 'playwright-report', '.website-r-library', 'triage',
        '*.tar.gz', '*.Rcheck', '*_files'))

    def render():
        # Removing frozen computations is essential: --execute alone does not
        # make a project render ignore freeze:auto for unchanged vignettes.
        for name in ('_site', '_freeze', '.quarto', 'site-data'):
            shutil.rmtree(project / name, ignore_errors=True)
        subprocess.run(['quarto', 'render', '--execute'], cwd=project, check=True)
        return hashes(project / '_site'), hashes(project / 'site-data')

    first, first_data = render()
    second, second_data = render()
    changed = [name for name in sorted(first.keys() | second.keys()) if first.get(name) != second.get(name)]
    if changed or first_data != second_data:
        raise SystemExit('Non-reproducible output: ' + ', '.join(changed) +
                         ('; generated data differs' if first_data != second_data else ''))
    print(f'Identical clean renders with fresh R execution: {len(first)} site files and {len(first_data)} data files.')
