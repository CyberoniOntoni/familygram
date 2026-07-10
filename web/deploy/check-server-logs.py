#!/usr/bin/env python3
import os
import sys

import paramiko

HOST = os.environ.get('FAMILYGRAM_SSH_HOST', '192.168.11.79')
USER = os.environ.get('FAMILYGRAM_SSH_USER', 'root')
PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')

if not PASSWORD:
    print('FAMILYGRAM_SSH_PASSWORD not set', file=sys.stderr)
    sys.exit(1)


def run(client: paramiko.SSHClient, cmd: str, timeout: int = 90) -> str:
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    if out:
        print(out, end='' if out.endswith('\n') else '\n')
    if err.strip():
        print('STDERR:', err, file=sys.stderr)
    return out


def main() -> int:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)
    print(f'Connected to {HOST}\n')

    sections = [
        ('HOST', 'hostname; date -u'),
        ('NGINX ACCESS apiws (last 40)', 'grep -h apiws /var/log/nginx/access.log 2>/dev/null | tail -40'),
        ('NGINX ERROR (last 50)', 'tail -50 /var/log/nginx/error.log 2>/dev/null'),
        ('FAMILYGRAM NGINX SITE', 'cat /etc/nginx/sites-enabled/familygram-web 2>/dev/null'),
        ('LISTEN PORTS', 'ss -lntp | grep -E "8082|30444|nginx" || true'),
        ('DOCKER PS', 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -35'),
        ('GATEWAY container name', 'docker ps --format "{{.Names}}" | grep -i gateway | head -5'),
        ('GATEWAY LOGS (last 80)', 'G=$(docker ps --format "{{.Names}}" | grep -i gateway | head -1); echo "container=$G"; docker logs --tail 80 "$G" 2>&1'),
        ('AUTH SERVER LOGS (last 80)', 'A=$(docker ps --format "{{.Names}}" | grep -i auth-server | head -1); echo "container=$A"; docker logs --tail 80 "$A" 2>&1'),
        ('MESSENGER auth/errors (last 50)', 'M=$(docker ps --format "{{.Names}}" | grep -i messenger | head -1); echo "container=$M"; docker logs --tail 300 "$M" 2>&1 | grep -iE "error|exception|fail|sendcode|auth|layer" | tail -50'),
        ('SESSION SERVER LOGS (last 40)', 'S=$(docker ps --format "{{.Names}}" | grep -i session | head -1); echo "container=$S"; docker logs --tail 40 "$S" 2>&1'),
        ('TESTGRAM ENV', 'grep -E "FixedVerifyCode|VerificationCodeLength|ApiId|ApiHash" /opt/testgram/docker/compose/.env 2>/dev/null | head -15'),
        ('LOCAL MTProto probe', 'node /opt/familygram-web/deploy/mtproto-handshake-probe.cjs ws://127.0.0.1:30444/apiws 2>&1 || node /opt/testgram/deploy/mtproto-handshake-probe.cjs ws://127.0.0.1:30444/apiws 2>&1 || echo "no probe script on server"'),
        ('DEPLOYED WEB ASSETS', 'ls -la /opt/familygram-web/dist/assets/index-*.js /opt/familygram-web/dist/worker-*.js 2>/dev/null | tail -5'),
    ]

    for title, cmd in sections:
        print(f'=== {title} ===')
        run(client, cmd)
        print()

    client.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())