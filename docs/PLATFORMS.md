# Platform notes

## Windows 10/11 + WSL2 (tested)

Use a WSL2 distro with Docker Desktop integration enabled. The CLI must be able to
run `docker` and `docker compose` from inside WSL. If only `docker.exe` is visible,
enable the distro under Docker Desktop → Settings → Resources → WSL Integration.
The installer can start Docker Desktop for you, but it does not silently change that
setting.

The WSL filesystem is mounted directly by Docker Desktop; there is no VirtualBox or
manual Samba/UNC mount to configure. Windows usernames, NTFS owners, and Chinese
locale settings do not propagate into the container as file metadata. A process in
the workspace sees Linux UIDs/GIDs, `/workspace`, and `/home/sandbox`.

The optional SSH + SFTP transport used by native Claude Desktop has also been
validated end to end on WSL2. See [DESKTOP.md](DESKTOP.md).

## macOS (adapted; needs on-device validation)

The same container model applies: Docker Desktop runs a Linux VM, and the workspace
bind mount uses your macOS project directory. There is no WSL translation layer, so
paths are simpler than on Windows.

The implementation detects Clash Verge Rev at:

```
~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev
```

Docker Desktop is started with `open -a Docker` when necessary. Both Apple Silicon
and Intel use the same YAML and scripts. The base images (`ubuntu:24.04` and the
pinned mihomo release) are multi-architecture; Docker selects the CPU-appropriate
variant. The package has no Rosetta requirement by design.

The items that still need a real Mac check are:

1. `/dev/net/tun` inside the Docker Desktop Linux VM;
2. the pinned mihomo image on Apple Silicon;
3. direct connectivity from that VM to your proxy servers;
4. host-side file ownership after writing from the container.

These are environment checks, not differences in timezone or locale behavior. If your
Mac uses a different container runtime (Colima, OrbStack, etc.), treat it as a new
target and verify TUN support before assuming the kill switch works.

## Native Linux (same code path)

Docker Engine plus the Compose plugin is sufficient. Start the Docker service before
`./install.sh`. The Verge lookup also checks `~/.config/io.github.clash-verge-rev.clash-verge-rev`.

## Validation status versus marketing claims

Windows/WSL2 is exercised end to end. macOS support means the platform-specific paths,
startup, discovery, and documentation are implemented; it does **not** mean that a
Mac run has already been observed by the maintainers. Run `./sandbox doctor` and
`./sandbox verify --kill-switch` on a Mac and compare the results. The design should
be equivalent for CLI work; GUI/OpenGL behavior is outside this package's scope and
must not be used to judge the sandbox model.
