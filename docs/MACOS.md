# How the sandbox works on macOS

This document explains how this repository separates Claude Code's runtime from the Mac host. It covers containers, shared files, networking, user permissions, and persistent state. The descriptions follow the current repository implementation.

## Install on macOS

These steps describe the current installer. They are not a record of a completed end-to-end Mac installation; see [platform validation status](PLATFORMS.md).

### Prepare Docker Desktop and Python 3

Install Docker Desktop for Mac, choosing the installer for your Mac's processor: Apple Silicon or Intel. Open the application, complete its initial setup, and wait for the Docker engine to finish starting.

Python 3 must also be available as `python3` in your Mac terminal. If it is missing, install Python 3 and reopen the terminal. The host only needs Python for the repository's helper scripts; Python packages required by the container are installed when the image is built.

Run the following checks in a **Mac terminal**, before entering any container:

```bash
uname -m
command -v docker
docker version
docker compose version
python3 --version
```

`uname -m` normally reports `arm64` on Apple Silicon and `x86_64` on Intel when using a native terminal. `docker version` must show both client and server information without a connection error. `docker compose version` and `python3 --version` must each print a version.

The installer can attempt to start an existing Docker Desktop installation, but it does not install Docker Desktop or Python, and it requires the `docker` command to be on your terminal's `PATH` before it can proceed.

The network prerequisites in the [README](../README.md#requirements) must also be satisfied before installation can finish. This section does not cover network provider configuration.

### Open the repository directory

If you already cloned the repository, use that existing directory. Otherwise:

```bash
git clone https://github.com/zhenghong-li/claude-sandbox.git
cd claude-sandbox
```

For an existing clone, replace the example path below with its location:

```bash
cd /absolute/path/to/claude-sandbox
```

All remaining installation commands run in this directory on the **Mac host**.

### Check for an existing sandbox first

This guide describes a new installation of this repository. An existing sandbox may use different container names, a different user and home directory, a Docker named volume, or another timezone. Those settings are not automatically migrated by `install.sh`.

Before installing alongside another sandbox, inspect its Compose project name and mounts:

```bash
docker compose ls --all
docker ps -a --format '{{.Names}} | project={{.Label "com.docker.compose.project"}}'
```

This repository sets the Compose project name to `claude-sandbox` and fixes the container names to `sandbox-gateway` and `sandbox-workspace`. Another stack with the same project name may be treated as the same Compose project even if it is in a different folder. Starting or stopping one configuration can therefore affect the other stack.

For a separate installation, assign a distinct Compose project name and check for container-name collisions before running the installer. Keep the existing workspace and persistent home unchanged unless you are deliberately migrating them. In particular, an existing named volume mounted at `/home/dev` is not automatically transferred to this repository's `state/home/` mount at `/home/sandbox`.

### Run the installer

```bash
./install.sh
```

The installer performs these steps:

1. Checks that `docker` and `python3` are available.
2. Creates `.env` from `.env.example` if it does not already exist, filling in the current user's UID/GID. An existing `.env` is retained.
3. Creates the workspace and persistent state directories.
4. Waits for Docker, then builds the Ubuntu workspace image. The first build downloads images and packages and can take several minutes.
5. Loads the required network configuration if it has not already been generated.
6. Starts the gateway and workspace containers.
7. Runs the timezone, locale, DNS, and egress checks.

Use the default state directory for an initial installation. The current helper for generating network configuration does not honor a custom `SANDBOX_STATE_DIR`; that code path needs correction before documenting it as supported.

### Recognize a successful installation

On the first run, the output includes a message such as:

```text
Created .env with host UID:GID <your UID>:<your GID>.
Building the sandbox image...
```

The UID/GID values depend on your Mac. The configuration-creation message is skipped if `.env` already exists. Build progress and network-configuration messages vary by environment.

The installer then prints checks under headings such as `date / timezone`, `locale`, `DNS`, and `egress`. If those checks succeed, it finishes with:

```text
Ready. Run ./sandbox to enter, or ./sandbox install-claude to install Claude Code.
```

Confirm that both containers are running:

```bash
docker compose ps
```

Expect `sandbox-gateway` and `sandbox-workspace` to be running. Container status alone does not prove that network routing or the kill switch works; the verification results must also be checked.

If the installer exits with an error before the final `Ready` message, installation has not completed successfully. Read the first error and consult [TROUBLESHOOTING.md](TROUBLESHOOTING.md). The current fallback egress check can also incorrectly reject a US result because it compares a country name with a country code; this remains a known verification issue.

At this point the sandbox infrastructure is installed. Claude Code installation and account sign-in are separate follow-up steps. The installer does not sign in to an account or test the kill switch; the latter has a separate command described below.

## 1. The Mac host, Docker Desktop, and the workspace

Docker Desktop runs Linux containers inside a Linux virtual machine on macOS. The workspace image is based on Ubuntu. Claude Code and the commands it launches execute in that Linux environment.

```text
Mac: terminal, editor, browser, project files
  |
  +-- Docker Desktop Linux VM
       +-- workspace: Claude Code, shell, development tools
       +-- gateway: networking for the workspace
```

Running `./sandbox` from a Mac terminal opens a shell inside the workspace container. Programs started from that shell use the container's tools, environment variables, and network configuration. Exiting the shell returns to the Mac environment.

Installing Claude Code on the Mac does not install it in the container. Likewise, signing in on the Mac does not sign in inside the container.

The repository does not mount the Mac's entire home directory or the Docker socket. Compose volume mounts determine which host files the workspace can access directly.

## 2. Separate containers for work and network management

`docker-compose.yml` defines two services:

| Service | Container name | Purpose |
|---|---|---|
| `workspace` | `sandbox-workspace` | Runs Claude Code, the shell, and project commands |
| `gateway` | `sandbox-gateway` | Runs mihomo and manages TUN, routing, and DNS |

The workspace uses this configuration:

```yaml
network_mode: container:sandbox-gateway
```

It shares the gateway's network namespace: network interfaces, routing tables, and port space. The workspace has no separate network interface or independent route to the internet. The gateway receives `NET_ADMIN` and access to `/dev/net/tun` to configure networking. The workspace drops the relevant capabilities needed to change that configuration.

This places network control in the gateway instead of relying on every development tool to honor proxy environment variables such as `HTTP_PROXY`.

The gateway's TUN and routing configuration directs traffic within this shared network namespace. DNS requests are also handled there. See [`gateway/config.yaml`](../gateway/config.yaml) for the implementation.

The kill switch is intended to make external requests fail when the gateway fails, without falling back to a direct connection. This behavior must be verified on the actual Mac and Docker Desktop version; successful container startup alone does not establish it.

After restarting the gateway, restart the workspace as well so it does not remain attached to an old network namespace. Prefer the repository's commands when managing the stack.

## 3. Share project files through a bind mount

By default, the repository's `workspace/` directory on the Mac is mounted at `/workspace` in the container:

```text
Mac: <repository>/workspace/  <-->  Container: /workspace/
```

Both paths refer to the same files. Changes saved in a Mac editor are visible inside the container. Changes Claude Code makes inside the container are also visible on the Mac.

To use an existing project, set this value in the local `.env` file:

```dotenv
SANDBOX_WORKSPACE=/absolute/path/to/project
```

Replace the example with your project directory. Relative paths are resolved from the repository directory. After changing a mount, recreate the container with the updated configuration.

The project mount is writable by default. Programs inside the container can modify or delete files in that directory. Container isolation does not automatically back up shared files.

The default `workspace/` directory is ignored by this repository's Git configuration. Version control for the project itself must be managed separately.

## 4. Keep installations and login state outside the container lifecycle

A second bind mount provides the container user's home directory:

```text
Mac: <repository>/state/home/  <-->  Container: /home/sandbox/
```

Claude Code's user installation, configuration, and login state live under `/home/sandbox`. Stopping or recreating the container preserves these files as long as the same host directory remains mounted.

This repository uses a host directory for the persistent home. No Docker named volume is required for it.

`./sandbox install-claude` installs Claude Code in the container user's environment. It does not copy the Mac's existing installation or account configuration.

The first use still requires signing in inside the container. If an authorization link opens in a browser on the Mac, that browser uses the Mac's own network configuration. The container gateway does not automatically route the browser's traffic. The exact authorization interaction still needs to be verified during an actual sign-in.

The entire `state/` directory and the local `.env` file are listed in `.gitignore`. Do not include login data in documentation examples. If you customize `SANDBOX_STATE_DIR`, also ensure the new location is not tracked by another repository. Git ignore rules control version tracking; they do not encrypt files.

## 5. User identity and file permissions

macOS and Linux use numeric user and group identifiers, UID and GID. The installer reads the current Mac user's identifiers and writes them to the local `.env` file:

```dotenv
SANDBOX_UID=<current user UID>
SANDBOX_GID=<current user GID>
```

These placeholders explain the settings; do not paste them literally into `.env`. Use the values generated by the installer rather than assuming the Mac user has the common Linux identifiers `1000:1000`.

The container entrypoint initially runs as root to initialize the user and home directory, then switches to the configured user. Entering through `./sandbox` also selects the same UID/GID.

This is intended to reduce permission problems when the container writes shared files. Docker Desktop also participates in host file sharing, so confirm that files created inside the container remain editable on the Mac.

## 6. Timezone and locale apply to container processes

The default settings are:

```dotenv
SANDBOX_TZ=America/Los_Angeles
SANDBOX_LOCALE=en_US.UTF-8
```

The Dockerfile installs timezone and locale data and sets `/etc/localtime` and `/etc/timezone`. Compose passes variables such as `TZ`, `LANG`, and `LC_ALL` to the workspace container.

These settings give container processes the configured time display and language environment. They do not change the Mac's system timezone, display language, or browser settings, and do not translate project files into English.

The current image also sets the system timezone files at build time. If you change the timezone later, check that those files and the runtime variables agree. Changing `TZ` alone does not update every timezone setting in this implementation.

## 7. Where each part is configured

| File | Responsibility |
|---|---|
| [`docker-compose.yml`](../docker-compose.yml) | Containers, shared networking, capabilities, and mounts |
| [`image/Dockerfile`](../image/Dockerfile) | Ubuntu environment, tools, default timezone, and locale |
| [`image/entrypoint.sh`](../image/entrypoint.sh) | User initialization, home permissions, shell setup, and startup |
| [`.env.example`](../.env.example) | Template for local paths, UID/GID, timezone, and locale |
| [`install.sh`](../install.sh) | Generates local configuration, builds, and starts the environment |
| [`scripts/common.sh`](../scripts/common.sh) | Platform detection, path resolution, and shared Docker operations |
| [`sandbox`](../sandbox) | Entry point for everyday workspace access and management |
| [`scripts/verify.sh`](../scripts/verify.sh) | Checks timezone, locale, DNS, egress, and the kill switch |

## 8. Verify the configuration on a Mac

After completing the installation and network preparation in the README, run these commands from the repository directory in a **Mac terminal**:

```bash
./sandbox doctor
./sandbox verify
```

Enter the workspace to inspect its process environment and mounts:

```bash
./sandbox
# Run the following commands inside the container.
pwd
id
printf '%s\n' "$HOME"
date
locale
```

Expect `/workspace` as the working directory and `/home/sandbox` as the home directory, along with the intended user identity, timezone, and locale. Also check that shared project files are readable and writable from both the Mac and the container.

Test the kill switch separately from a **Mac terminal**:

```bash
./sandbox verify --kill-switch
```

This check temporarily stops the gateway, attempts an external request, and restores the containers. It interrupts active network connections, so run it when no tasks are in progress.

This document explains the repository configuration. It does not establish that this repository has completed end-to-end runtime or login validation on macOS. See [`PLATFORMS.md`](PLATFORMS.md) for validation status.

## Optional application access

For SSH clients and the Claude Desktop Code tab, see [Optional SSH access and Claude Desktop](SSH_DESKTOP.md). This requires additional image and client configuration and is separate from the default installation.
