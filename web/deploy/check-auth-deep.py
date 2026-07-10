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

cmds = [
    ('AUTH Step2+ (2h)', 'docker logs --since 2h compose-auth-server-1 2>&1 | grep -E "Step[2-9]|SendCode|SetClient|DH" | tail -50'),
    ('AUTH last 40 lines', 'docker logs --since 45m compose-auth-server-1 2>&1 | tail -40'),
    ('GATEWAY last 25', 'docker logs --since 45m compose-gateway-server-1 2>&1 | tail -25'),
    ('API ID in env', 'grep -E "TELEGRAM_API_ID|TELEGRAM_API_HASH|ApiId|ApiHash" /opt/familygram/docker/compose/.env 2>/dev/null | head -20'),
    ('Step1 vs Step2 counts 24h', 'echo -n "Step1="; docker logs --since 24h compose-auth-server-1 2>&1 | grep -c Step1; echo -n "Step2="; docker logs --since 24h compose-auth-server-1 2>&1 | grep -c Step2; echo -n "SendCode="; docker logs --since 24h compose-auth-server-1 2>&1 | grep -c SendCode'),
    ('SendCode recent', 'docker logs --since 24h compose-auth-server-1 2>&1 | grep SendCode | tail -5'),
    ('Live index bundle', 'curl -sS http://127.0.0.1:8082/index.html | grep -o "index-[^\\"]*\\.js" | head -3'),
    ('SW on disk', 'ls -la /opt/familygram-web/dist/service.worker-*.js 2>/dev/null | tail -3'),
    ('Probe local ws', 'python3 - <<"PY"\nimport socket\nhost,port="127.0.0.1",30444\ns=socket.create_connection((host,port),5)\ns.send(b"GET /apiws HTTP/1.1\\r\\nHost: localhost\\r\\nUpgrade: websocket\\r\\nConnection: Upgrade\\r\\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\\r\\nSec-WebSocket-Version: 13\\r\\nSec-WebSocket-Protocol: binary\\r\\n\\r\\n")\nprint(s.recv(200))\ns.close()\nPY'),
]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)
print('Connected\n')

for title, cmd in cmds:
    print(f'=== {title} ===')
    stdin, stdout, stderr = client.exec_command(cmd, timeout=90)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    print(out or '(empty)')
    if err.strip():
        print('STDERR:', err)
    print()

client.close()