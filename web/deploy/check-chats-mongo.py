#!/usr/bin/env python3
import os
import paramiko

PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.11.79', username='root', password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)

cmds = [
    ('GETDIALOGS count', 'docker logs --since 30m compose-messenger-query-server-1 2>&1 | grep -c GetDialogs || true'),
    ('QUERY errors', 'docker logs --since 30m compose-messenger-query-server-1 2>&1 | grep -iE "error|exception|RPC|invalid" | tail -30'),
    ('CMD errors', 'docker logs --since 30m compose-messenger-command-server-1 2>&1 | grep -iE "error|exception|RPC|invalid|unsupported" | tail -40'),
    ('SESSION unsupported', 'docker logs --since 30m compose-session-server-1 2>&1 | grep -i unsupported | tail -15'),
    ('DIALOGS in mongo', 'cd /opt/testgram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollection(\'eventflow-dialogreadmodel\').find().limit(5).toArray()"'),
    ('USERS in mongo', 'cd /opt/testgram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollection(\'eventflow-userreadmodel\').find({}, {UserId:1,PhoneNumber:1,UserName:1,FirstName:1}).limit(5).toArray()"'),
    ('USER 777000', 'cd /opt/testgram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollection(\'eventflow-userreadmodel\').find({UserId:Long(777000)}).toArray()"'),
    ('ALL USERS count', 'cd /opt/testgram/docker/compose && docker compose exec -T mongodb mongosh tg --quiet --eval "db.getCollection(\'eventflow-userreadmodel\').find({}, {UserId:1,FirstName:1}).toArray()"'),
    ('SEEDER config file', 'cat /opt/testgram/docker/compose/data/mytelegram/data-seeder/downloads/dataseeder.json 2>/dev/null || echo missing'),
    ('SEEDER logs users', 'docker logs compose-data-seeder-1 2>&1 | grep -iE "user|777000|notification|created" | tail -20'),
]

for title, cmd in cmds:
    print(f'=== {title} ===')
    stdin, stdout, stderr = client.exec_command(cmd, timeout=120)
    print(stdout.read().decode('utf-8', errors='replace'))
    err = stderr.read().decode('utf-8', errors='replace')
    if err.strip():
        print('STDERR:', err)
    print()

client.close()