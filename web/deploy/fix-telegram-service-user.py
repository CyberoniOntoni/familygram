#!/usr/bin/env python3
"""Ensure Telegram service user 777000 exists in Testgram Mongo."""
import os
from pathlib import Path

import paramiko

HOST = os.environ.get('FAMILYGRAM_SSH_HOST', '')
USER = os.environ.get('FAMILYGRAM_SSH_USER', 'root')
PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
SCRIPT = Path(__file__).resolve().parents[2] / 'docker' / 'compose' / 'init-telegram-service.sh'
REMOTE = '/opt/familygram/docker/compose/init-telegram-service.sh'

if not HOST:
    raise SystemExit('Set FAMILYGRAM_SSH_HOST')
if not PASSWORD:
    raise SystemExit('Set FAMILYGRAM_SSH_PASSWORD')

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)

sftp = client.open_sftp()
sftp.put(str(SCRIPT), REMOTE)
sftp.close()

stdin, stdout, stderr = client.exec_command(
    f'chmod +x {REMOTE} && cd /opt/familygram/docker/compose && bash {REMOTE}',
    timeout=120,
)
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print(out)
if err.strip():
    print('STDERR:', err)
client.close()