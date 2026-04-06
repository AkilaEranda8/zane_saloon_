"""Remove stale certbot lock/containers then re-run the SSL expand."""
import io, os, sys, threading

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
        print(f"Connected to {user}@{host}")
        connected = True
        break
    except paramiko.AuthenticationException:
        print("Auth failed")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr); sys.exit(1)

if not connected:
    print("SSH login failed.", file=sys.stderr); sys.exit(1)

def run(cmd, label=""):
    if label:
        print(f"\n>>> {label}")
    _, stdout, stderr = client.exec_command(cmd, get_pty=False)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if out.strip(): print(out.strip())
    if err.strip(): print("[stderr]", err.strip())
    return code

# 1. Remove stale certbot containers
run('docker ps -a --filter "name=certbot" --format "{{.Names}} {{.Status}}"', "Certbot containers")
run('CONTAINERS=$(docker ps -aq --filter "name=certbot") && [ -n "$CONTAINERS" ] && docker rm -f $CONTAINERS || echo "No certbot containers to remove"', "Remove stale certbot containers")

# 2. Remove lock file
run("rm -f /var/lib/letsencrypt/.certbot.lock && echo 'Lock removed'", "Remove certbot lock")

# 3. Show current cert domains
run("certbot certificates 2>/dev/null || docker run --rm -v /etc/letsencrypt:/etc/letsencrypt certbot/certbot certificates", "Current cert domains")

# 4. Run expand
print("\n>>> Running SSL expand...")
expand_cmd = (
    f"cd {app_path} && "
    "docker compose --profile certbot run --rm certbot certonly "
    "  --webroot "
    "  --webroot-path=/var/www/certbot "
    "  --email akilaeranda8@gmail.com "
    "  --agree-tos --no-eff-email --expand "
    "  -d main.zanesalon.com "
    "  -d api.zanesalon.com "
    "  -d pma.zanesalon.com "
    "  -d zanesalon.com "
    "  -d www.zanesalon.com"
)

stdin, stdout, stderr = client.exec_command(expand_cmd, get_pty=True)
stdin.close()

def _copy(stream, out):
    for line in iter(stream.readline, ""):
        out.write(line); out.flush()

t_err = threading.Thread(target=_copy, args=(stderr, sys.stderr))
t_err.daemon = True
t_err.start()
_copy(stdout, sys.stdout)
t_err.join(timeout=1)
exit_code = stdout.channel.recv_exit_status()
print(f"\nExpand exit code: {exit_code}")

if exit_code == 0:
    # 5. Reload nginx
    run(f"cd {app_path} && docker compose exec proxy nginx -s reload", "Reload nginx")
    print("\n=== SSL EXPAND DONE ===")
    print("  https://zanesalon.com")
    print("  https://www.zanesalon.com")
else:
    print("\nExpand FAILED. Check output above.", file=sys.stderr)

client.close()
