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

cmds = [
    ('GETDIALOGS count', 'docker logs --since 30m compose-messenger-query-server-1 2>&1 | grep -c GetDialogs || true'),
    ('QUERY errors', 'docker logs --since 30m compose-messenger-query-server-1 2>&1 | grep -iE "error|exception|RPC|invalid" | tail -30'),
    ('CMD errors', 'docker logs --since 30m compose-messenger-command-server-1 2>&1 | grep -iE "error|exception|RPC|invalid|unsupported" | tail -40'),
    ('SESSION unsupported', 'docker logs --since 30m compose-session-server-1 2>&1 | grep -i unsupported | tail -15'),
    ('DIALOGS in mongo', 'cd /opt/familygram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollection(\'eventflow-dialogreadmodel\').find().limit(5).toArray()"'),
]

for title, cmd in cmds:
    print(f'=== {title} ===')
    stdin, stdout, stderr = client.exec_command(cmd, timeout=120)
    print(stdout.read().decode('utf-8', errors='replace') or '(empty)')
    err = stderr.read().decode('utf-8', errors='replace')
    if err.strip():
        print('STDERR:', err, file=sys.stderr)

client.close()