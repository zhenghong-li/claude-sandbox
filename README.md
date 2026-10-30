# claude-sandbox

A reproducible, US-region Docker workspace for Claude Code and other command-line tools.
It gives every process in the workspace the same **US egress IP, Pacific timezone, and
English locale**, with a real network kill switch — without changing your host system.

The point is not a folder with a few environment variables. It is a two-container
network namespace design: **the workspace has no independent route to the internet**.

## What makes it different

- **Mandatory US egress**: mihomo runs a TUN interface in a gateway container. The
  workspace shares that container's network namespace and has no NIC of its own.
- **Kill switch, not a proxy hint**: stop the gateway and the workspace loses network
  entirely. There is no accidental direct connection. `./sandbox verify --kill-switch`
  proves it.
- **Region consistency**: timezone, `/etc/localtime`, `/etc/timezone`, locale, DNS, and
  exit geography are aligned. A pinned node gives you a stable exit IP.
- **No secrets in git**: subscriptions, node credentials, sessions, and Claude login
  state live under `state/`, which is gitignored. The repository contains no personal
  subscription or account data.
- **Normal file ownership**: container processes run as your host UID/GID after startup,
  so files created in `workspace/` remain editable on the host.
- **Host-side English-only monitor**: optional CJK detection for files added to the
  workspace, with no host package dependencies beyond Python 3.

## Requirements

| Platform | Requirements | Status |
|---|---|---|
| Windows 10/11 + WSL2 | Docker Desktop, WSL integration enabled for your distro, Python 3 in WSL | Tested on Ubuntu/WSL2 |
| macOS (Apple Silicon or Intel) | Docker Desktop, Python 3 (`python3` on PATH) | Adapted; needs on-device validation |
| Native Linux | Docker Engine with Compose, Python 3 | Supported by the same path; not the primary test target |

You also need **a working US proxy node**. The sandbox does not provide a VPN service
or bypass a paid subscription. It can read your current Clash Verge Rev profile, or
import a Clash/mihomo YAML file.

## Quick start

### 1. Clone

```bash
git clone https://github.com/zhenghong-li/claude-sandbox.git
cd claude-sandbox
```

### 2. Prepare Docker

**Windows:** open Docker Desktop → Settings → Resources → WSL Integration, and enable
your WSL distro. Run the rest inside that distro.

**macOS:** start Docker Desktop and wait for the engine to be ready. See [macOS sandbox configuration principles](docs/MACOS.md) for the container, file-sharing, permissions, and persistence model.

If Docker Hub is slow on your network, configure a registry mirror in Docker Desktop
before building. apt uses the Ubuntu archive by default; set `APT_MIRROR` in `.env`
to a host such as `mirrors.ustc.edu.cn` if you need a mirror.

### 3. Install

```bash
./install.sh
```

The installer creates `.env`, builds the image, imports US nodes, starts both
containers, and checks the environment. The first build takes a few minutes.

Node discovery works with Clash Verge Rev at its standard locations on Windows,
macOS, and Linux. If it is not found, use either:

```bash
# Your subscription is currently selected in Verge:
./sandbox refresh

# Or import any Clash/mihomo YAML containing a `proxies:` list:
./sandbox import /path/to/your-config.yaml
```

Only US nodes are selected (`美国`, `西美`, `US`, `United States` name patterns).
Real node configuration stays in `state/gateway/proxies.yaml` and is never committed.

### 4. Enter and verify

```bash
./sandbox             # prompt changes to [US] /workspace
date                  # Pacific time
locale                # en_US.UTF-8
curl https://ipinfo.io/json
```

Install Claude Code into the persistent sandbox home:

```bash
./sandbox install-claude
./sandbox             # then run: claude
```

The first `claude` login opens an OAuth URL in your browser. Complete it through a
browser that uses the same US-region network path. Login state persists in
`state/home/`, which is never committed.

## Optional SSH and Claude Desktop

See [SSH access and Claude Desktop](docs/SSH_DESKTOP.md) for a manual extension using Docker as the SSH transport. The default installer does not enable SSH; this extension still needs end-to-end validation.

## Stable exit IP

List available US nodes, then pin one:

```bash
./sandbox nodes
./sandbox pin "YOUR US NODE NAME"
./sandbox verify
```

`pin` reimports that node from the current Verge profile, so subscription refreshes
can update its keys/port without changing your chosen identity. To return to
automatic selection of the fastest healthy US node:

```bash
./sandbox pin --auto
```

A pinned node is a deliberate trade-off: consistent IP, but no failover. If it dies,
the sandbox goes offline rather than falling back to another region or a direct route.

## English-only file monitoring

```bash
./sandbox watch start     # background monitor
./sandbox watch status
./sandbox watch once      # one scan; exits 1 if CJK content is found
./sandbox watch stop
```

The watcher polls the host-mounted workspace and reports new or changed text files
containing CJK characters. It is a detector, not a language firewall: the OS cannot
force every newly created file to be English. Logs are in `state/langwatch.log`.

## Commands

| Command | Purpose |
|---|---|
| `./sandbox` | Enter the workspace shell; start the stack if needed |
| `./sandbox up` / `down` | Start / stop the two containers |
| `./sandbox build` / `rebuild` | Build the workspace image (with/without cache) |
| `./sandbox refresh` | Re-read US nodes from Verge and restart in the required order |
| `./sandbox nodes` | List US node names from the current Verge profile |
| `./sandbox pin "NAME"` / `pin --auto` | Pin a stable exit node / resume auto-selection |
| `./sandbox import FILE.yaml` | Import nodes from a Clash/mihomo YAML file |
| `./sandbox install-claude` | Install Claude Code in the persistent home |
| `./sandbox verify` | Check timezone, locale, DNS, and egress |
| `./sandbox verify --kill-switch` | Also test that gateway failure causes no leak |
| `./sandbox watch ...` | Manage the English-only file monitor |
| `./sandbox doctor` | Print local and runtime diagnostics |
| `./sandbox logs` | Follow gateway logs |

## Configuration

`install.sh` creates `.env` from `.env.example` and fills in your host UID/GID.
Common settings:

```dotenv
SANDBOX_WORKSPACE=./workspace
SANDBOX_STATE_DIR=./state
SANDBOX_TZ=America/Los_Angeles
SANDBOX_LOCALE=en_US.UTF-8
SANDBOX_UID=1000
SANDBOX_GID=1000
# SANDBOX_VERGE_DIR=/custom/path/to/verge/config
# APT_MIRROR=mirrors.ustc.edu.cn
```

Paths are resolved relative to the repository, not your current shell directory.
Point `SANDBOX_WORKSPACE` at any project folder to expose it as `/workspace`.
Do not put `.env`, `state/`, or the default `workspace/` under version control;
they are already in `.gitignore`.

## What this does and does not guarantee

**Guaranteed by the implementation:** a container-level network boundary, no direct
fallback when the gateway dies, US-only mihomo rules, tunneled DNS, and a consistent
process environment.

**Not guaranteed:** a particular service's account decision, residential-IP appearance,
or complete anonymity. Datacenter proxy IPs, account history, payment region, browser
fingerprints, and user behavior are separate signals. Browser activity is outside the
sandbox. For sensitive browser logins, use a consistent US-region proxy and an
English/US browser profile; do not alternate between direct domestic access and the
sandbox on the same account.

See [ARCHITECTURE.md](docs/ARCHITECTURE.md), [PLATFORMS.md](docs/PLATFORMS.md),
[SECURITY.md](docs/SECURITY.md), and [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## License

[MIT](LICENSE). VESTA and MagView are not part of this package. mihomo, Docker, and
other dependencies retain their own licenses.
