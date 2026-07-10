#!/usr/bin/env python3
import os
import sys

import paramiko

PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
if not PASSWORD:
    print('FAMILYGRAM_SSH_PASSWORD not set', file=sys.stderr)
    sys.exit(1)

cmds = [
    ('TIME', 'date -u; uptime'),
    ('DOCKER PS', 'docker ps --format "table {{.Names}}\t{{.Status}}" | head -20'),
    ('AUTH recent (login)', 'docker logs --since 30m compose-auth-server-1 2>&1 | grep -iE "Step|SendCode|SignIn|auth|error|exception" | tail -40'),
    ('GATEWAY recent', 'docker logs --since 30m compose-gateway-server-1 2>&1 | grep -iE "error|exception|auth|dialog|message|getDialogs|user" | tail -40'),
    ('MESSENGER-CMD errors', 'docker logs --since 30m compose-messenger-command-server-1 2>&1 | grep -iE "error|exception|fail|invalid|LANG_PACK|dialog|getDialogs|updates" | tail -60'),
    ('MESSENGER-QUERY errors', 'docker logs --since 30m compose-messenger-query-server-1 2>&1 | grep -iE "error|exception|fail|invalid|dialog|getDialogs|updates" | tail -60'),
    ('SESSION recent', 'docker logs --since 30m compose-session-server-1 2>&1 | grep -iE "error|exception|fail|auth" | tail -30'),
    ('NGINX apiws access', 'grep -h apiws /var/log/nginx/access.log 2>/dev/null | tail -20'),
    ('NGINX errors', 'tail -30 /var/log/nginx/error.log 2>/dev/null'),
    ('MONGO users', 'docker compose -f /opt/testgram/docker/compose/docker-compose.yml exec -T mongodb mongosh tg --quiet --eval "db[\'eventflow-userreadmodel\'].countDocuments({})" 2>/dev/null'),
    ('MONGO dialogs', 'docker compose -f /opt/testgram/docker/compose/docker-compose.yml exec -T mongodb mongosh tg --quiet --eval "db[\'eventflow-dialogreadmodel\'].countDocuments({})" 2>/dev/null || echo no-dialog-collection'),
    ('MONGO collections', 'docker compose -f /opt/testgram/docker/compose/docker-compose.yml exec -T mongodb mongosh tg --quiet --eval "db.getCollectionNames().filter(c=>c.includes(\'dialog\')||c.includes(\'user\')||c.includes(\'chat\')).join(\', \')" 2>/dev/null'),
    ('ENV layer/api', 'grep -E "Layer|ApiId|ApiHash|FixedVerifyCode|CreateTestUsers|Brand" /opt/testgram/docker/compose/.env 2>/dev/null | head -20'),
    ('WEB bundle', 'curl -sS http://127.0.0.1:8082/index.html 2>/dev/null | grep -oE "index-[^\"]+\\.js|worker-[^\"]+\\.js" | head -5'),
    ('RSA in bundle', 'B=$(ls /opt/familygram-web/dist/assets/index-*.js 2>/dev/null | head -1); grep -o "3591632762792723036" "$B" 2>/dev/null | head -1 || echo RSA fingerprint not found'),
]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.11.79', username='root', password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)
print('Connected\n')

for title, cmd in cmds:
    print(f'=== {title} ===')
    stdin, stdout, stderr = client.exec_command(cmd, timeout=120)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    print(out or '(empty)')
    if err.strip():
        print('STDERR:', err)
    print()

client.close()