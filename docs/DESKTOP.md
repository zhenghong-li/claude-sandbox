# Claude Desktop with the sandbox

The recommended Desktop architecture is **native UI on the host, remote execution
in the sandbox**. Claude Desktop connects to the workspace through SSH and SFTP.
This avoids running an Electron/OpenGL application inside a container while keeping
Claude Code's execution and network traffic inside the US-region environment.

```text
Claude Desktop (host UI)
  |
  +-- SSH + SFTP
       |
       +-- ProxyCommand: docker exec ... sshd (no published SSH port)
            |
            +-- sandbox-workspace: project, Claude Code, execution, US egress
```

The optional SSH server is included in the image, but no SSH daemon starts at boot
and no port is exposed. Each connection starts a per-connection server through
`docker exec`. Authentication uses a dedicated host key pair; password and root
login are disabled.

## 1. Start and verify the sandbox

```bash
./sandbox up
./sandbox verify --kill-switch
```

## 2. Configure SSH on the host

Run this on the host where Desktop will run (WSL or macOS), not inside the
workspace:

```bash
./sandbox ssh-setup
```

This command:

1. creates `~/.ssh/claude_sandbox_ed25519` if needed;
2. authorizes its public key in the persistent sandbox home;
3. writes an idempotent `claude-sandbox` block to `~/.ssh/config` (with a backup);
4. checks a real SSH login and an SFTP connection.

The private key never leaves the host. The container entrypoint generates and
persists the server host key in `state/home/.ssh/` and initializes `/run/sshd`.
Container recreation preserves both client authorization and server identity.

You can also open a terminal through the alias:

```bash
./sandbox ssh
# or directly:
ssh claude-sandbox
```

## 3. Install Claude Desktop on a WSL host

Run these commands **on the WSL host**, not inside the container. They require your
sudo password:

```bash
sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
  https://downloads.claude.ai/claude-desktop/key.asc
echo "deb [signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-desktop.list
sudo apt update && sudo apt install claude-desktop
```

On macOS, install the native Claude Desktop application instead and run
`./sandbox ssh-setup` from the repository there.

## 4. Connect Desktop

1. Ensure the host browser/Desktop login path also uses your US-region network.
   The sandbox does not route host application traffic.
2. Open Claude Desktop and sign in.
3. Open the **Code** tab and the environment selector.
4. Add an SSH environment using the host alias **`claude-sandbox`**. Leave port and
   key overrides empty so Desktop uses `~/.ssh/config`.
5. Select **`/workspace`** as the remote project directory and create the
   environment.

Desktop reads `HostName`, `User`, `IdentityFile`, and `ProxyCommand` from that
alias. It installs its remote components automatically; if the remote machine
cannot download them, Desktop can download on the host and upload over SFTP.
Labels vary slightly between Desktop versions.

For terminal-side checks:

```bash
ssh claude-sandbox 'id; echo "$HOME"; pwd'
printf 'quit\n' | sftp -b - claude-sandbox
```

Expected: the configured non-root container user, `/home/sandbox`, and a working
SFTP prompt.

## Network model

Desktop's interface and sign-in run on the host and use the **host network**.
Claude Code launched in the SSH environment runs in the workspace and makes its
network requests through the **sandbox gateway**. Keep the host on the same US
region for account consistency; do not alternate direct domestic logins with
sandbox use on the same account.

## Troubleshooting

- **Docker not found from Desktop:** confirm `docker info` works in the host
  terminal and that `~/.ssh/config` contains the absolute Docker path.
- **Container not running:** `./sandbox up` before connecting.
- **Permission denied (publickey):** rerun `./sandbox ssh-setup`; do not replace
  the key or disable host-key checking.
- **Host-key mismatch after moving state:** compare the fingerprint directly from
  the container before updating the known-hosts entry.
- **Terminal SSH works but Desktop fails:** test SFTP and noninteractive execution
  (`ssh claude-sandbox 'id; echo "$HOME"'`). Desktop requires SFTP and a writable,
  executable home.
- **External requests fail in a session:** run `./sandbox verify`; SSH connectivity
  does not validate outbound routing.

See the [official Desktop SSH documentation](https://code.claude.com/docs/en/desktop#ssh-sessions)
for the current environment selector and remote requirements.
