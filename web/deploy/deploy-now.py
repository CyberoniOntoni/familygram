#!/usr/bin/env python3
import os
import sys
from pathlib import Path

import paramiko

HOST = os.environ.get('FAMILYGRAM_SSH_HOST', '192.168.11.79')
USER = os.environ.get('FAMILYGRAM_SSH_USER', 'root')
PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
SSH_KEY = Path(os.environ.get('FAMILYGRAM_SSH_KEY', Path(os.environ['USERPROFILE']) / '.ssh' / 'id_ed25519'))
SSH_KEY_PASSPHRASE = os.environ.get('FAMILYGRAM_SSH_KEY_PASSPHRASE', '')
DIST_TAR = Path(os.environ.get('FAMILYGRAM_DIST_TAR', r'D:\Software\Grok\familygram-web-dist.tar.gz'))
PUB_KEY = SSH_KEY.with_suffix('.pub') if SSH_KEY.suffix == '' else SSH_KEY.parent / f'{SSH_KEY.stem}.pub'
REMOTE_DIST = '/opt/familygram-web/dist'
REMOTE_TAR = '/tmp/familygram-web-dist.tar.gz'


def run(client: paramiko.SSHClient, cmd: str, timeout: int = 120) -> tuple[int, str, str]:
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode()
    err = stderr.read().decode()
    return stdout.channel.recv_exit_status(), out, err


def connect_client() -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    if SSH_KEY.exists():
        try:
            client.connect(
                HOST,
                username=USER,
                key_filename=str(SSH_KEY),
                passphrase=SSH_KEY_PASSPHRASE or None,
                timeout=15,
                look_for_keys=False,
                allow_agent=False,
            )
            return client
        except Exception as key_error:
            if not PASSWORD:
                raise SystemExit(f'SSH key auth failed ({key_error}) and FAMILYGRAM_SSH_PASSWORD is not set') from key_error

    if not PASSWORD:
        raise SystemExit('Set FAMILYGRAM_SSH_PASSWORD or configure FAMILYGRAM_SSH_KEY (+ optional FAMILYGRAM_SSH_KEY_PASSPHRASE)')

    client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)
    return client


def main() -> int:
    client = connect_client()
    print(f'Connected to {HOST}')

    if not PUB_KEY.exists():
        print('Skipping authorized_keys update: public key not found')
        pub = ''
    else:
        pub = PUB_KEY.read_text().strip()
    if pub:
        code, out, err = run(client, f'''
mkdir -p ~/.ssh && chmod 700 ~/.ssh
grep -qF '{pub}' ~/.ssh/authorized_keys 2>/dev/null || echo '{pub}' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo KEY_OK
''')
        print(out.strip() or err.strip())

    if not DIST_TAR.exists():
        print(f'Missing dist tarball: {DIST_TAR}', file=sys.stderr)
        return 1

    sftp = client.open_sftp()
    print(f'Uploading {DIST_TAR} ({DIST_TAR.stat().st_size} bytes) ...')
    sftp.put(str(DIST_TAR), REMOTE_TAR)
    sftp.close()

    code, out, err = run(client, f'''
set -e
mkdir -p {REMOTE_DIST}
cd {REMOTE_DIST}
rm -rf ./*
tar -xzf {REMOTE_TAR}
rm -f {REMOTE_TAR}
echo "DEPLOYED:$(cat version.txt 2>/dev/null || echo unknown)"
ls -la | head -10
nginx -t
systemctl reload nginx
echo NGINX_RELOADED
''', timeout=180)
    print(out)
    if err:
        print(err, file=sys.stderr)
    client.close()
    return code


if __name__ == '__main__':
    raise SystemExit(main())