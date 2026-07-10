#!/usr/bin/env python3
"""Reset Testgram Mongo/MinIO/bot data and restart compose stack."""
import os
import sys
import time

import paramiko

HOST = os.environ.get('FAMILYGRAM_SSH_HOST', '192.168.11.79')
USER = os.environ.get('FAMILYGRAM_SSH_USER', 'root')
PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
COMPOSE_DIR = '/opt/testgram/docker/compose'


def run(client: paramiko.SSHClient, cmd: str, timeout: int = 600) -> tuple[int, str, str]:
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    code = stdout.channel.recv_exit_status()
    return code, out, err


def main() -> int:
    if not PASSWORD:
        print('Set FAMILYGRAM_SSH_PASSWORD', file=sys.stderr)
        return 1

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)
    print(f'Connected to {HOST}')

    reset_cmd = f'''
set -e
cd {COMPOSE_DIR}

echo "=== Current compose status ==="
docker compose ps 2>/dev/null || true

echo "=== Optional backup ==="
BACKUP=/root/testgram-backup-$(date +%F-%H%M%S).tar.gz
if [ -d data/mongo ] || [ -d data/minio ] || [ -d data/bot ]; then
  tar -czf "$BACKUP" data/mongo data/minio data/bot .env 2>/dev/null || true
  echo "Backup: $BACKUP ($(du -h "$BACKUP" 2>/dev/null | cut -f1 || echo unknown))"
else
  echo "No data dirs to backup"
fi

echo "=== Stopping stack ==="
docker compose down

echo "=== Wiping persistent data ==="
rm -rf data/mongo data/minio data/bot data/mytelegram/data-seeder/downloads
mkdir -p data/mongo/db data/mongo/configdb data/minio data/bot data/mytelegram/data-seeder/downloads
echo "Wiped: mongo, minio, bot, data-seeder downloads"

echo "=== Starting stack ==="
docker compose up -d

echo "=== Waiting for mongodb healthy ==="
for i in $(seq 1 60); do
  if docker compose exec -T mongodb mongosh --quiet --eval "db.adminCommand({{ ping: 1 }})" >/dev/null 2>&1; then
    echo "MongoDB ready after ${{i}}s"
    break
  fi
  sleep 2
done

echo "=== Waiting for data-seeder (up to 3 min) ==="
for i in $(seq 1 36); do
  SEEDER=$(docker ps --format "{{{{.Names}}}}" | grep -i data-seeder | head -1)
  if [ -n "$SEEDER" ]; then
    if docker logs --tail 5 "$SEEDER" 2>&1 | grep -qiE "seed|complete|started|finished|error"; then
      docker logs --tail 20 "$SEEDER" 2>&1
    fi
  fi
  sleep 5
done

echo "=== Compose status ==="
docker compose ps

echo "=== Mongo collections (tg db) ==="
docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollectionNames().length" 2>/dev/null || echo "mongosh failed"

echo "=== Recent gateway/messenger logs ==="
G=$(docker ps --format "{{{{.Names}}}}" | grep -i gateway | head -1)
M=$(docker ps --format "{{{{.Names}}}}" | grep -i messenger-command | head -1)
[ -n "$G" ] && docker logs --tail 15 "$G" 2>&1
[ -n "$M" ] && docker logs --tail 15 "$M" 2>&1

echo "RESET_DONE"
'''

    code, out, err = run(client, reset_cmd, timeout=900)
    print(out)
    if err.strip():
        print('STDERR:', err, file=sys.stderr)

    client.close()

    if 'RESET_DONE' not in out:
        print('Reset may have failed', file=sys.stderr)
        return code or 1

    print('\nDatabase reset complete. Re-login with phone + code 280963 and clear site data for web.50bar.app.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())