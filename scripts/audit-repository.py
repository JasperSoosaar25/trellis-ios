"""Check tracked source and every reachable commit without printing secret values."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
patterns = {
    'GitHub credential': re.compile(r'\bgh[pousr]_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{40,}\b'),
    'private-key block': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    'AWS access key': re.compile(r'\bAKIA[A-Z0-9]{16}\b'),
    'personal workspace path': re.compile(r'C:[\\/]+Users[\\/]+jaspe', re.I),
}
failures = []
def check(data, location):
    text = data.decode('utf-8', errors='ignore')
    for label, pattern in patterns.items():
        if pattern.search(text):
            failures.append((location, label))

files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root).decode().split('\0')
for filename in filter(None, files):
    path = root / filename
    if path.is_file():
        check(path.read_bytes(), filename)
        if path.suffix.lower() in {'.p12', '.pem', '.key', '.mobileprovision', '.cer'}:
            failures.append((filename, 'signing/credential file'))
commits = subprocess.check_output(['git', 'rev-list', '--all'], cwd=root).decode().splitlines()
for commit in commits:
    check(subprocess.check_output(['git', 'show', '--format=fuller', '--no-ext-diff', commit], cwd=root), commit)
if failures:
    for location, label in failures:
        print(f'FAIL: {location}: {label}')
    sys.exit(1)
print(f'PASS: {len(list(filter(None, files)))} working files and {len(commits)} commits; no credential/private-key/personal-path patterns detected.')
