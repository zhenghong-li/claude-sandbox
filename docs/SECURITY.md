# Security and privacy

## What is isolated

The workspace container has a reduced capability set, no Docker socket, no host SSH
agent, and no automatic access to your host home directory. Only these paths are
mounted:

- `SANDBOX_WORKSPACE` → `/workspace`
- `SANDBOX_STATE_DIR/home` → `/home/sandbox`
- the gateway's read-only mihomo YAML files

Processes inside the workspace see a US network exit, Pacific time, and English
locale. They do not see Windows profile names, NTFS ownership, or arbitrary host
paths unless you explicitly mount them.

## Secrets handling

Do not commit `.env` or `state/`. They can contain:

- proxy node addresses, passwords, UUIDs, and keys;
- Claude Code OAuth credentials and session history;
- logs and project files.

The example file uses placeholders only. `scripts/nodes.py` reads a Verge profile and
writes the selected node configuration locally; it does not print node secrets.
Back up `state/` only through a channel you trust, and never include it in a public
archive or issue attachment.

`./sandbox install-claude` downloads the official installer from `claude.ai` through
the sandbox's US egress. No host GitHub or SSH credentials are required or copied by
this package. If you later push code from inside the sandbox, configure credentials
there deliberately; `state/home/` is persistent but is not a secrets manager.

## Optional SSH/Desktop transport

`./sandbox ssh-setup` creates a dedicated client key in the host's `~/.ssh` and adds
its public key to the persistent sandbox home. No private key or host GitHub token
is copied into a container. The SSH server uses public-key authentication only,
disables password and root login, publishes no port, and starts only for the
lifetime of a `docker exec` connection. The client still needs host Docker access,
which is equivalent to host-level control; do not expose the Docker socket or the
alias to untrusted users. Server and client keys live outside git.

## Gateway privileges

The gateway has `NET_ADMIN` and `/dev/net/tun` because TUN cannot work without them.
The workspace does not receive those privileges. The entrypoint starts as root to
create the user and then drops to your UID/GID. Do not add `privileged: true` to the
Compose file; it would destroy the intended boundary.

## Limits of the model

- A user who controls the host can change the gateway, node list, mounts, or Docker
  settings. This is not a defense against a malicious host administrator.
- A compromised process inside the workspace can still act within its mounted
  directories. Keep `state/` out of untrusted projects.
- A datacenter proxy IP is not a residential IP. Region consistency is not the same
  as anonymity or a guarantee against a service's risk controls.
- Browser fingerprinting is outside this package. TLS fingerprints, account history,
  payment region, and usage patterns are independent signals.
- A proxy provider can observe the traffic it carries, subject to its own policy and
  the protocol's encryption. Choose a provider you trust.

## Updating

The mihomo image is pinned by version to make behavior reproducible. Review upstream
changes before upgrading it. Rebuild with `./sandbox rebuild` after changing the
Dockerfile, then run `./sandbox verify --kill-switch` again.
