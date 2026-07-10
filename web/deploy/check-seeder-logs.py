#!/usr/bin/env python3
import os
import sys

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

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)

stdin, stdout, stderr = client.exec_command('docker logs compose-data-seeder-1 2>&1 | head -80', timeout=60)
print(stdout.read().decode('utf-8', errors='replace'))
client.close()