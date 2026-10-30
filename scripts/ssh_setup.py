#!/usr/bin/env python3
"""Configure the host's optional SSH alias for Claude Desktop and terminal use."""
import os
import re
import shutil
import subprocess
from pathlib import Path

CONTAINER = "sandbox-workspace"
KEY = Path.home() / ".ssh" / "claude_sandbox_ed25519"
CONFIG = Path.home() / ".ssh" / "config"
BEGIN = "# BEGIN CLAUDE-SANDBOX"
END = "# END CLAUDE-SANDBOX"


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def main():
    uid = os.environ.get("SANDBOX_UID", "1000")
    gid = os.environ.get("SANDBOX_GID", "1000")
    KEY.parent.mkdir(mode=0o700, exist_ok=True)
    if not KEY.exists():
        run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "claude-sandbox", "-f", str(KEY)])

    login = subprocess.check_output(
        ["docker", "exec", CONTAINER, "getent", "passwd", uid], text=True
    ).split(":", 1)[0]
    public_key = KEY.with_suffix(".pub").read_text(encoding="utf-8").strip()
    remote_script = (
        "umask 077; "
        "touch \"$HOME/.ssh/authorized_keys\"; "
        "grep -qxF \"$1\" \"$HOME/.ssh/authorized_keys\" || "
        "printf '%s\\n' \"$1\" >> \"$HOME/.ssh/authorized_keys\"; "
        "chmod 600 \"$HOME/.ssh/authorized_keys\""
    )
    run(["docker", "exec", "-u", f"{uid}:{gid}", CONTAINER, "bash", "-c", remote_script, "bash", public_key])

    docker_path = shutil.which("docker")
    if not docker_path:
        raise SystemExit("docker was not found on the host PATH")
    block = f"""{BEGIN}
Host claude-sandbox
    HostName claude-sandbox-container
    User {login}
    IdentityFile ~/.ssh/claude_sandbox_ed25519
    IdentitiesOnly yes
    HostKeyAlias claude-sandbox-container
    UserKnownHostsFile ~/.ssh/known_hosts_claude_sandbox
    ForwardAgent no
    ProxyCommand {docker_path} exec -i -u 0 {CONTAINER} /usr/sbin/sshd -i -e -f /etc/ssh/sshd_sandbox_config
{END}
"""
    existing = CONFIG.read_text(encoding="utf-8") if CONFIG.exists() else ""
    updated = re.sub(r"\n?# BEGIN CLAUDE-SANDBOX\n.*?# END CLAUDE-SANDBOX\n?", "\n", existing, flags=re.S)
    if existing and not existing.endswith("\n"):
        updated += "\n"
    if existing:
        backup = CONFIG.with_suffix(".claude-sandbox.bak")
        backup.write_text(existing, encoding="utf-8")
    CONFIG.write_text(updated.rstrip() + "\n\n" + block, encoding="utf-8")
    CONFIG.chmod(0o600)
    print(f"SSH alias configured: claude-sandbox (container user: {login})")


if __name__ == "__main__":
    main()
