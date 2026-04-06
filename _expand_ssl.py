"""
Expand Let's Encrypt SSL cert to include zanesalon.com + www.zanesalon.com.
Run from repo root:

  python _expand_ssl.py
"""

import io, os, sys, threading

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)
if hasattr(sys.stderr, "buffer"):
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace", line_buffering=True)

try:
    import paramiko
except ImportError:
    print("Install paramiko:  pip install paramiko", file=sys.stderr)
    sys.exit(1)

host     = os.environ.get("DEPLOY_HOST", "157.180.113.249")
user     = os.environ.get("DEPLOY_USER", "root")
app_path = os.environ.get("DEPLOY_PATH", "/root/xanesalon")

passwords = []
if os.environ.get("DEPLOY_SSH_PASSWORD"):
    passwords.append(os.environ["DEPLOY_SSH_PASSWORD"])
passwords.extend(p for p in ("qnuwjheuweugdsjsds", "kjsdksdjiereihshdks") if p not in passwords)

expand_cmd = (
    f"cd {app_path} && "
    "echo '>>> Expanding SSL cert...' && "
    "docker compose --profile certbot run --rm certbot certonly "
    "  --webroot "
    "  --webroot-path=/var/www/certbot "
    "  --email akilaeranda8@gmail.com "
    "  --agree-tos --no-eff-email --expand "
    "  -d main.zanesalon.com "
    "  -d api.zanesalon.com "
    "  -d pma.zanesalon.com "
    "  -d zanesalon.com "
    "  -d www.zanesalon.com && "
    "echo '>>> Reloading nginx...' && "
    "docker compose exec proxy nginx -s reload && "
    "echo '=== SSL EXPAND DONE ==='"
)

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

connected = False
for password in passwords:
    try:
        client.connect(host, port=22, username=user, password=password, timeout=30)
        print(f"Connected to {user}@{host}")
        connected = True
        break
    except paramiko.AuthenticationException:
        print("Auth failed (tried ****)")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if not connected:
    print("SSH login failed. Set DEPLOY_SSH_PASSWORD.", file=sys.stderr)
    sys.exit(1)

try:
    stdin, stdout, stderr = client.exec_command(expand_cmd, get_pty=True)
    stdin.close()

    def _copy(stream, out):
        for line in iter(stream.readline, ""):
            out.write(line)
            out.flush()

    t_err = threading.Thread(target=_copy, args=(stderr, sys.stderr))
    t_err.daemon = True
    t_err.start()
    _copy(stdout, sys.stdout)
    t_err.join(timeout=1)

    exit_code = stdout.channel.recv_exit_status()
    print(f"\nExit code: {exit_code}", flush=True)
    if exit_code != 0:
        sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
finally:
    client.close()
