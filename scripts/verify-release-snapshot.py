"""Read-only publication gate; prints paths/rules, never credential values."""
import argparse
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import urlsplit

parser = argparse.ArgumentParser()
parser.add_argument('--tree', default='HEAD')
parser.add_argument('--require-root', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]

def git(*cmd):
    return subprocess.check_output(['git', *cmd], cwd=root)

issues = []
if args.require_root and len(git('rev-list', '--parents', '-n', '1', args.tree).split()) != 1:
    issues.append({'path': '<history>', 'rule': 'EXPECTED_PARENTLESS_RELEASE'})

# These are intentionally public, self-signed SDK unit-test fixtures. No real project authority.
fixture_keys = {
    'backend/src/test/resources/firebase/test-only-private-key.pem',
    'backend/src/test/resources/firebase/test-only-certificate.pem',
}
needles = []
env_file = root / '.env'
if env_file.exists():
    for line in env_file.read_text(encoding='utf-8-sig').splitlines():
        if '=' not in line or line.lstrip().startswith('#'):
            continue
        key, value = line.split('=', 1)
        value = value.strip().strip('\"\'')
        if key in ('DB_PASSWORD', 'JWT_SECRET') and len(value) >= 20:
            needles.append(value.encode())
        if key == 'CLOUDINARY_URL' and value.startswith('cloudinary://'):
            secret = urlsplit(value).password
            if secret:
                needles.append(secret.encode())
        if key == 'MAPBOX_SERVER_TOKEN' and value.startswith('sk.'):
            needles.append(value.encode())

files = []
for entry in git('ls-tree', '-r', '-l', '-z', args.tree).split(b'\0'):
    if not entry:
        continue
    meta, raw_path = entry.split(b'\t', 1)
    mode, kind, oid, size = meta.decode().split()
    path = raw_path.decode()
    if kind != 'blob':
        issues.append({'path': path, 'rule': 'UNREVIEWED_NON_BLOB'})
        continue
    files.append((path, oid, int(size)))

# Narrow owner-approved release exception: no replacement entrypoint is generated.
if any(path == 'lib/main.dart' for path, _, _ in files):
    issues.append({'path': 'lib/main.dart', 'rule': 'OWNER_PRIVATE_ENTRYPOINT_MUST_BE_EXCLUDED'})

proc = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=root,
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE)
for path, oid, size in files:
    parts = path.split('/')
    suffix = Path(path).suffix.lower()
    if (Path(path).name.startswith('.env') and Path(path).name != '.env.example') or (
        path.startswith('backend/secrets/') and path != 'backend/secrets/README.md'
    ) or Path(path).name in ('google-services.json', 'GoogleService-Info.plist'):
        issues.append({'path': path, 'rule': 'LOCAL_CREDENTIAL_CONFIG'})
    if any(p in ('backups', 'build', 'target', 'node_modules', '.dart_tool', '__pycache__', '.m2-cache')
           or p.startswith('.venv') for p in parts):
        issues.append({'path': path, 'rule': 'GENERATED_OR_PRIVATE_DIRECTORY'})
    if suffix in ('.dump', '.backup', '.log', '.apk', '.jar', '.p12', '.rar', '.zip'):
        issues.append({'path': path, 'rule': 'EXPORT_BUILD_OR_ARCHIVE'})
    if suffix == '.pem' and path not in fixture_keys:
        issues.append({'path': path, 'rule': 'UNREVIEWED_PEM'})
    if size >= 100 * 1024 * 1024:
        issues.append({'path': path, 'rule': 'REMOTE_FILE_SIZE_LIMIT'})
    proc.stdin.write((oid + '\n').encode())
    proc.stdin.flush()
    actual_size = int(proc.stdout.readline().split()[-1])
    data = proc.stdout.read(actual_size)
    proc.stdout.read(1)
    if path == '.gitignore' and b'/lib/main.dart' not in data.splitlines():
        issues.append({'path': path, 'rule': 'PRIVATE_ENTRYPOINT_IGNORE_RULE_REQUIRED'})
    if data.startswith(b'version https://git-lfs.github.com/spec/v1'):
        issues.append({'path': path, 'rule': 'UNREVIEWED_LFS_OBJECT'})
    if any(secret in data for secret in needles):
        issues.append({'path': path, 'rule': 'CURRENT_SERVER_CREDENTIAL'})
    if path not in fixture_keys and re.search(
        rb'-----BEGIN (?:RSA )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/=\r\n]{80,}-----END', data
    ):
        issues.append({'path': path, 'rule': 'PRIVATE_KEY_MATERIAL'})
    # GitHub Push Protection also flags embedded client tokens. Do not bypass it.
    if re.search(rb'\b(?:pk|sk)\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}', data):
        issues.append({'path': path, 'rule': 'MAPBOX_EMBEDDED_TOKEN_REVIEW'})
    if re.search(rb'\beyJ[A-Za-z0-9_-]{25,}\.[A-Za-z0-9_-]{25,}\.[A-Za-z0-9_-]{20,}', data):
        issues.append({'path': path, 'rule': 'JWT_LITERAL_REVIEW'})
proc.stdin.close()
proc.wait()
print(json.dumps({'tree': args.tree, 'files': len(files), 'issues': issues,
                  'private_file_required': 'lib/main.dart', 'git_only_flutter_buildable': False,
                  'fixture_policy': 'self-signed unit tests only; embedded Mapbox tokens require review'}))
raise SystemExit(bool(issues))
