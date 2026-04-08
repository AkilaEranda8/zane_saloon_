#!/usr/bin/env python3
import paramiko
import sys
import io

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)

host = '157.180.113.249'
user = 'root'
passwords = ['qnuwjheuweugdsjsds', 'kjsdksdjiereihshdks']

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

connected = False
for pwd in passwords:
    try:
        client.connect(host, port=22, username=user, password=pwd, timeout=30)
        print('Connected to server ✓')
        connected = True
        break
    except:
        pass

if not connected:
    print('Failed to connect', file=sys.stderr)
    sys.exit(1)

try:
    cmd = 'cd /root/xanesalon && echo "=== Docker Compose Status ===" && docker compose ps && echo && echo "=== Backend Logs (last 30 lines) ===" && docker compose logs backend 2>&1 | tail -30'
    stdin, stdout, stderr = client.exec_command(cmd, get_pty=False)
    stdin.close()
    for line in stdout:
        print(line, end='')
finally:
    client.close()
