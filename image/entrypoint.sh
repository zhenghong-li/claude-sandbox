#!/usr/bin/env bash
set -u
export TZ="${TZ:-America/Los_Angeles}"
export LANG="${LANG:-en_US.UTF-8}" LC_ALL="${LC_ALL:-en_US.UTF-8}" LANGUAGE=en_US:en
export HOME=/home/sandbox

uid="${SANDBOX_UID:-1000}"
gid="${SANDBOX_GID:-1000}"
if ! getent group "$gid" >/dev/null; then
  groupadd -g "$gid" sandbox
fi
if ! getent passwd "$uid" >/dev/null; then
  useradd -u "$uid" -g "$gid" -d "$HOME" -s /bin/bash -M sandbox
fi
user_name="$(getent passwd "$uid" | cut -d: -f1)"
current_home="$(getent passwd "$uid" | cut -d: -f6)"
if [ "$current_home" != "$HOME" ]; then
  usermod -d "$HOME" "$user_name"
fi
mkdir -p "$HOME"
if [ "$(stat -c %u "$HOME")" != "$uid" ] || [ "$(stat -c %g "$HOME")" != "$gid" ]; then
  chown -R "$uid:$gid" "$HOME"
fi
for file in .bashrc .profile; do
  if [ ! -f "$HOME/$file" ]; then
    cp "/etc/skel/$file" "$HOME/$file" 2>/dev/null || touch "$HOME/$file"
    chown "$uid:$gid" "$HOME/$file"
  fi
done
if ! grep -q 'CLAUDE-SANDBOX' "$HOME/.profile"; then
  printf '\n# CLAUDE-SANDBOX\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
fi
if ! grep -q 'CLAUDE-SANDBOX' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'EOF'
# CLAUDE-SANDBOX
export PATH="$HOME/.local/bin:$PATH"
PS1='[US] \w \$ '
EOF
fi
chown "$uid:$gid" "$HOME/.profile" "$HOME/.bashrc"

# Optional SSH transport for Claude Desktop. No SSH port is published and no
# daemon starts at boot; each connection invokes sshd through docker exec.
mkdir -p /run/sshd "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/ssh_host_ed25519_key" ]; then
  ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/ssh_host_ed25519_key"
fi
if [ ! -f "$HOME/.ssh/authorized_keys" ]; then
  touch "$HOME/.ssh/authorized_keys"
fi
usermod -p "*" "$user_name"
chown -R "$uid:$gid" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
chmod 600 "$HOME/.ssh/ssh_host_ed25519_key" "$HOME/.ssh/authorized_keys"

printf '== US Sandbox ==\nTunnel: '
up=0
for _ in $(seq 1 45); do
  if curl -s --max-time 3 -o /dev/null http://cp.cloudflare.com/generate_204; then
    up=1
    break
  fi
  printf '.'
  sleep 1
done
if [ "$up" = 1 ]; then
  echo "up"
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S %Z (%z)')"
  curl -s --max-time 8 https://ipinfo.io/json | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print("Exit: {ip} | {country} {region} {city} | {org}".format(**d))
except Exception:
    print("Exit: geo lookup failed")
'
else
  echo "DOWN (kill switch active, no network). Check the gateway logs."
fi

export USER="$user_name" LOGNAME="$user_name"
if [ $# -gt 0 ]; then
  exec runuser -u "$user_name" -- "$@"
else
  exec runuser -u "$user_name" -- bash -l
fi
