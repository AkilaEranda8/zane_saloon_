import paramiko, sys, io

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect("157.180.113.249", port=22, username="root", password="qnuwjheuweugdsjsds", timeout=15)

cmd = r"""cd /root/xanesalon
echo '=== .env has FIREBASE? ==='
grep -c FIREBASE_SERVICE_ACCOUNT_JSON .env && echo 'line found' || echo 'NOT FOUND'
echo '=== Container env has FIREBASE? ==='
docker compose exec -T backend sh -c 'if [ -n "$FIREBASE_SERVICE_ACCOUNT_JSON" ]; then echo YES - set; else echo NO - not set; fi'
"""

stdin, stdout, stderr = client.exec_command(cmd, get_pty=True)
stdin.close()
print(stdout.read().decode("utf-8", errors="replace"))
client.close()
