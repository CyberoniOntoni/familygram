#!/usr/bin/env python3
"""Deploy FamilyGram Web to the Testgram LXC via SSH+SFTP."""

import getpass
import os
import sys
import tarfile
import tempfile
from pathlib import Path

import paramiko

HOST = os.environ.get('FAMILYGRAM_SSH_HOST', '')
USER = os.environ.get('FAMILYGRAM_SSH_USER', 'root')
SRC_ROOT = Path(__file__).resolve().parent.parent
REMOTE_SRC = '/opt/familygram-web-src'
REMOTE_DIST = '/opt/familygram-web/dist'


def main() -> int:
    if not HOST:
        print('FAMILYGRAM_SSH_HOST not set', file=sys.stderr)
        return 1
    password = os.environ.get('FAMILYGRAM_SSH_PASSWORD') or getpass.getpass(f'{USER}@{HOST} password: ')

    excludes = {'node_modules', '.git', '.cache', 'dist'}
    with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as tmp:
        tar_path = tmp.name

    print(f'Packaging {SRC_ROOT} ...')
    with tarfile.open(tar_path, 'w:gz') as tar:
        for path in SRC_ROOT.rglob('*'):
            if any(part in excludes for part in path.parts):
                continue
            if path.is_file():
                tar.add(path, arcname=path.relative_to(SRC_ROOT))

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f'Connecting to {USER}@{HOST} ...')
    client.connect(HOST, username=USER, password=password, timeout=15)

    sftp = client.open_sftp()
    remote_tar = '/tmp/familygram-web-src.tar.gz'
    print(f'Uploading to {remote_tar} ...')
    sftp.put(tar_path, remote_tar)
    sftp.close()
    os.unlink(tar_path)

    commands = f'''
set -e
mkdir -p {REMOTE_SRC}
cd {REMOTE_SRC}
find . -mindepth 1 -maxdepth 1 ! -name dist -exec rm -rf {{}} +
tar -xzf {remote_tar} -C {REMOTE_SRC}
cp -n .env.production .env 2>/dev/null || true
unset NODE_OPTIONS
npm ci
npm run build:production
mkdir -p {REMOTE_DIST}
rm -rf {REMOTE_DIST}/*
cp -a dist/. {REMOTE_DIST}/
rm -f {remote_tar}
echo DEPLOYED:$(cat public/version.txt 2>/dev/null || echo unknown)
'''
    print('Building on server ...')
    stdin, stdout, stderr = client.exec_command(commands, timeout=600)
    out = stdout.read().decode()
    err = stderr.read().decode()
    code = stdout.channel.recv_exit_status()
    client.close()

    if out:
        print(out)
    if err:
        print(err, file=sys.stderr)
    return code


if __name__ == '__main__':
    raise SystemExit(main())