#!/usr/bin/env python3
import os
import sys
from pathlib import Path

import paramiko

HOST = os.environ.get('FAMILYGRAM_SSH_HOST', '')
USER = os.environ.get('FAMILYGRAM_SSH_USER', 'root')
PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
if not HOST:
    print('FAMILYGRAM_SSH_HOST not set', file=sys.stderr)
    sys.exit(1)
if not PASSWORD:
    print('FAMILYGRAM_SSH_PASSWORD not set', file=sys.stderr)
    sys.exit(1)
PUB_KEY = (Path(os.environ['USERPROFILE']) / '.ssh' / 'id_ed25519.pub').read_text().strip()
NGINX_SNIPPET = r'''
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location = /version.txt {
        add_header Cache-Control "no-cache";
    }
'''


def main() -> int:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)

    # Fix authorized_keys properly
    sftp = client.open_sftp()
    try:
        with sftp.open('/root/.ssh/authorized_keys', 'r') as f:
            existing = f.read().decode()
    except FileNotFoundError:
        existing = ''
    if PUB_KEY not in existing:
        with sftp.open('/root/.ssh/authorized_keys', 'w') as f:
            content = (existing.rstrip() + '\n' + PUB_KEY + '\n').lstrip()
            f.write(content)
    sftp.close()

    stdin, stdout, stderr = client.exec_command('''
set -e
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
CONF=/etc/nginx/sites-enabled/familygram-web
if [ -f "$CONF" ] && ! grep -q 'location = /index.html' "$CONF"; then
  sed -i '/location \\/ {/i\
    location = /index.html {\
        add_header Cache-Control "no-cache, no-store, must-revalidate";\
    }\
\
    location = /version.txt {\
        add_header Cache-Control "no-cache";\
    }\
' "$CONF"
  nginx -t && systemctl reload nginx
  echo NGINX_PATCHED
else
  echo NGINX_ALREADY_OK
fi
curl -sI http://127.0.0.1:8082/ | head -3
curl -sI http://127.0.0.1:30444/apiws 2>/dev/null | head -3 || true
''', timeout=60)
    print(stdout.read().decode())
    err = stderr.read().decode()
    if err:
        print(err, file=sys.stderr)
    client.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())