#!/usr/bin/env python3
import os
import paramiko

PASSWORD = os.environ.get('FAMILYGRAM_SSH_PASSWORD', '')
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.11.79', username='root', password=PASSWORD, timeout=15, look_for_keys=False, allow_agent=False)

stdin, stdout, stderr = client.exec_command('docker logs compose-data-seeder-1 2>&1 | head -80', timeout=60)
print(stdout.read().decode('utf-8', errors='replace'))
client.close()