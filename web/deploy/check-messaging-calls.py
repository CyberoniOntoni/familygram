#!/usr/bin/env python3
import os
import sys

import paramiko

HOST = os.environ.get('FAMILYGRAM_SSH_HOST', '')
USER = os.environ.get('FAMILYGRAM_SSH_USER', 'root')
PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
if not HOST:
    raise SystemExit('Set FAMILYGRAM_SSH_HOST')
if not PASSWORD:
    raise SystemExit('Set FAMILYGRAM_SSH_PASSWORD')

cmds = [
    ('TIME', 'date -u'),
    ('DOCKER PS key', 'docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "messenger|gateway|session|coturn|auth|file"'),
    ('ENV WebRTC/DC', 'grep -E "WebRtc|DcOptions|Servers|FixedVerify|Coturn|Turn|5348|20443|30444|ApiId" /opt/familygram/docker/compose/.env 2>/dev/null | head -40'),
    ('COTURN logs', 'docker logs --since 2h compose-coturn-1 2>&1 | tail -30'),
    ('GATEWAY recent', 'docker logs --since 2h compose-gateway-server-1 2>&1 | grep -iE "error|exception|call|webrtc|phone|message|send" | tail -40'),
    ('MESSENGER-CMD send/errors', 'docker logs --since 2h compose-messenger-command-server-1 2>&1 | grep -iE "error|exception|fail|SendMessage|phone\.|call|updates" | tail -60'),
    ('MESSENGER-QUERY', 'docker logs --since 2h compose-messenger-query-server-1 2>&1 | grep -iE "error|exception|fail|GetHistory|GetDialogs|phone" | tail -40'),
    ('SESSION errors', 'docker logs --since 2h compose-session-server-1 2>&1 | grep -iE "error|exception|fail|unsupported|updates|phone" | tail -40'),
    ('AUTH recent', 'docker logs --since 2h compose-auth-server-1 2>&1 | grep -iE "error|Step|SignIn" | tail -20'),
    ('MONGO users', 'cd /opt/familygram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollection(\\"eventflow-userreadmodel\\").find({}, {UserId:1,FirstName:1,PhoneNumber:1}).toArray()"'),
    ('MONGO messages sample', 'cd /opt/familygram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollectionNames().filter(c=>c.toLowerCase().includes(\\"message\\")).join(\\", \\")"'),
    ('MESSAGE count', 'cd /opt/familygram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "c=db.getCollectionNames().find(n=>n.includes(\\"message\\")); c?db.getCollection(c).countDocuments({}):0"'),
    ('NGINX apiws', 'grep -h apiws /var/log/nginx/access.log 2>/dev/null | tail -15'),
    ('WEB bundle', 'ls -la /opt/familygram-web/dist/assets/main-*.js /opt/familygram-web/dist/worker-*.js 2>/dev/null | tail -4'),
    ('LISTEN ports', 'ss -lntp | grep -E "20443|30444|5348|8082" || true'),
]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)
print('Connected\n')
for title, cmd in cmds:
    print(f'=== {title} ===')
    stdin, stdout, stderr = client.exec_command(cmd, timeout=120)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    print(out or '(empty)')
    if err.strip() and 'level=warning' not in err[:200]:
        print('STDERR:', err[:1500])
    print()
client.close()