# Discrakt Docker sidecar

Run [Discrakt](https://github.com/afonsojramos/discrakt) in a separate headless
container alongside an existing Linux Discord desktop client. It mirrors Trakt,
Plex, or Jellyfin watch activity to Discord Rich Presence, including artwork
and estimated playback progress.

This is an unofficial Docker adaptation of Afonso Ramos's MIT-licensed project,
based on upstream commit `87c66612a6eaf7438b0b9b479e623bdded0a85da`.
The complete source is included. See [changes](CHANGES.md),
[upstream documentation](README.upstream.md), and [license](LICENSE).

## Requirements

- Docker Engine on Linux with Docker Compose v2, or a compatible Linux container engine.
- A running, logged-in **Linux Discord desktop client** with its Rich Presence
  Unix socket available to the container. A Discord browser tab is insufficient.
- Access to Trakt, Plex, or Jellyfin, connected through the setup wizard.

Images can be built for `linux/amd64` and `linux/arm64`. Mac and Windows users
can build images, but their native Discord application's socket or named pipe
is not automatically available inside Docker Desktop's Linux VM. Run the
Discord Linux client in that same Docker environment, or deploy on Linux.

## Quick start: Discord already runs in Docker

Use the existing Docker volume that contains the Discord IPC socket. It must
already be mounted in the Discord container, usually at `/tmp`. Creating an
empty volume alone does not connect it to Discord.

```sh
cp .env.example .env
```

Edit `.env`: set `DISCORD_IPC_VOLUME` to that volume's name, and match
`DISCRAKT_UID`/`DISCRAKT_GID` to the socket owner. Then run:

```sh
docker compose config --quiet
docker compose build
docker compose up -d --no-build
```

Open **http://127.0.0.1:18081/index.html**, select a source, authorize it directly
with the provider, and finish the wizard. The setup server then closes and
Discrakt continues polling in the background. The provider credentials persist
in the project's configuration volume.

The Compose project is named `discrakt-docker`. It manages its own service,
network, and settings volume. It uses your existing Discord IPC volume without
managing the Discord container or requiring a custom Discord image.

## Alternative: native Discord on the Linux host

Locate the actual socket directory on the Linux host:

```sh
find /run/user/"$(id -u)" /tmp -maxdepth 2 -type s -name 'discord-ipc-[0-9]' 2>/dev/null
```

Set `DISCORD_IPC_DIR` in `.env` to the **directory** containing the socket, and
match the UID/GID. Use the standalone host Compose file:

```sh
docker compose -f compose.host.yaml config --quiet
docker compose -f compose.host.yaml build
docker compose -f compose.host.yaml up -d --no-build
```

Keep using `-f compose.host.yaml` for management commands with this option.
Do not combine the two Compose files. A directory mount follows a replacement
socket after Discord restarts; mounting a single socket file can retain an old
inode. The IPC directory is mounted read-only, including its other contents.
No Discord home directory, display, session D-Bus, or Docker daemon socket is
mounted into Discrakt.

## Remote setup and private VPN access

The setup wizard has no authentication of its own. It defaults to loopback.
For SSH access, forward the setup port from your computer:

```sh
ssh -N -L 127.0.0.1:18081:127.0.0.1:18081 YOUR_LINUX_HOST
```

Then open http://127.0.0.1:18081/index.html locally. For direct private VPN
access, set `DISCRAKT_BIND_ADDRESS` to the Linux host's own VPN interface
address before starting Compose. Keep this endpoint off public interfaces.

If you change the bind address or setup port, apply it with `docker compose up
-d --no-build`. The settings volume is retained.

## Build details and checks

The Dockerfile uses a native build stage and cross compilers for the requested
image architecture. It avoids running the Rust compiler under CPU emulation.
Examples using Docker Buildx:

```sh
docker buildx build --platform linux/amd64 --load -t discrakt-sidecar:amd64 .
docker buildx build --platform linux/arm64 --load -t discrakt-sidecar:arm64 .
```

Podman can also build with `podman build --platform linux/amd64 ...`. Cross
builds need target-platform emulation for the runtime verification stage;
Docker Desktop normally supplies it. Native builds need no emulation.

Every complete image build checks resolved React/React DOM versions, builds the
frontend, checks Rust formatting, runs the upstream library/integration tests,
and exercises the real target binary against local HTTP and Discord IPC mocks.
Tests use dummy source configuration and never contact your real Discord or
media accounts. Build and test tools stay outside the final image.

The runtime uses an unprivileged user, a read-only root, dropped capabilities,
bounded resources/logs, a writable settings volume, and Docker init. Defaults
are UID/GID 1000; changing those values also requires rebuilding the image.
Do not change IDs on an existing settings volume without addressing ownership.

See [validation notes](VALIDATION.md) for the checks completed for this repository.

## Management and troubleshooting

```sh
docker compose ps
docker compose logs --tail 30
docker compose restart discrakt
docker compose down
```

`down` retains the settings volume; `down --volumes` deletes it. Credentials are
stored at `/config/discrakt/credentials.ini` and should never be committed or
included in a public issue. `.gitignore` and `.dockerignore` exclude local
configuration, credential backups, logs, and transfer archives.

- **Cannot connect to Discord:** confirm the client is logged in, the real IPC
  directory/volume is mounted, and socket permissions allow the configured UID.
  Sharing a Docker network alone does not share a Unix socket.
- **Setup port closes after authorization:** expected; it is an initial setup
  wizard, not a permanent dashboard.
- **Blank setup page:** React and React DOM are pinned to the same exact version;
  the build rejects a mismatch. Reload the page after changing images.
- **Progress changes backward:** the Trakt path calculates estimated progress
  from watch timestamps. It can reflect timing updates but does not log explicit
  player seek events.

## Sharing this fork

The branch contains the upstream source and the Docker changes. Configure your
own Git hosting remote when publishing it; the `upstream` remote points to the
original project. A source ZIP needs no Git installation. A Git bundle preserves
the commit history and can be cloned with `git clone PATH_TO_BUNDLE`.
