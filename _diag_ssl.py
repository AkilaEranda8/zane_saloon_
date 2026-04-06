"""Diagnose SSL cert status on the VPS."""
import io, os, sys

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)
if hasattr(sys.stderr, "buffer"):
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace", line_buffering=True)

try:
    import paramiko
except ImportError:
    print("pip install paramiko", file=sys.stderr); sys.exit(1)

host     = os.environ.get("DEPLOY_HOST", "157.180.113.249")
user     = os.environ.get("DEPLOY_USER", "root")
app_path = os.environ.get("DEPLOY_PATH", "/root/xanesalon")
passwords = []
if os.environ.get("DEPLOY_SSH_PASSWORD"):
    passwords.append(os.environ["DEPLOY_SSH_PASSWORD"])
passwords.extend(p for p in ("qnuwjheuweugdsjsds", "kjsdksdjiereihshdks") if p not in passwords)

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
connected = False
for pw in passwords:
    try:
        client.connect(host, port=22, username=user, password=pw, timeout=15)
        print(f"Connected to {user}@{host}\n")
        connected = True
        break
    except paramiko.AuthenticationException:
        print("Auth failed")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr); sys.exit(1)

if not connected:
    print("SSH login failed.", file=sys.stderr); sys.exit(1)

def run(cmd, label):
    print(f"{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    _, stdout, stderr = client.exec_command(cmd, get_pty=False)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    stdout.channel.recv_exit_status()
    if out.strip(): print(out.strip())
    if err.strip(): print("[stderr]", err.strip())
    print()

# 1. What domains does the current cert cover?
run(
    "docker run --rm -v /etc/letsencrypt:/etc/letsencrypt certbot/certbot certificates 2>&1",
    "Current cert domains (certbot certificates)"
)

# 2. Any stale certbot containers or lock?
run(
    'docker ps -a --filter "name=certbot" --format "{{.Names}}  {{.Status}}"',
    "Stale certbot containers"
)
run(
    "ls -la /var/lib/letsencrypt/.certbot.lock 2>/dev/null && echo 'LOCK EXISTS' || echo 'No lock file'",
    "Certbot lock file"
)

# 3. DNS resolution for zanesalon.com
run(
    "dig +short zanesalon.com A 2>/dev/null || host zanesalon.com 2>/dev/null || nslookup zanesalon.com 2>/dev/null",
    "DNS: zanesalon.com A record"
)
run(
    "dig +short www.zanesalon.com A 2>/dev/null || host www.zanesalon.com 2>/dev/null",
    "DNS: www.zanesalon.com A record"
)

# 4. Can nginx serve ACME challenge for zanesalon.com?
run(
    "curl -sk -o /dev/null -w '%{http_code}' http://zanesalon.com/.well-known/acme-challenge/test 2>&1 || echo 'curl failed'",
    "HTTP challenge path reachable (zanesalon.com port 80)"
)

# 5. Running containers
run(
    f"cd {app_path} && docker compose ps --format 'table {{{{.Name}}}}\\t{{{{.Status}}}}'",
    "Docker container status"
)

# 6. Certbot log (last 30 lines)
run(
    "tail -30 /var/log/letsencrypt/letsencrypt.log 2>/dev/null || echo 'No log found'",
    "Certbot last log"
)

client.close()
print("=== Diagnosis complete ===")
