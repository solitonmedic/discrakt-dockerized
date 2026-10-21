# Discrakt Docker sidecar

Run [Discrakt](https://github.com/afonsojramos/discrakt) in its own container,
without a display or system tray. It sends your Trakt, Plex, or Jellyfin watch
activity to Discord Rich Presence, with artwork and estimated playback progress.

Discrakt connects to your Linux Discord desktop client through its IPC socket.
You can keep using your existing Discord image.

This is an unofficial Docker adaptation of Afonso Ramos's MIT-licensed project.
It includes the full source, based on upstream commit
`87c66612a6eaf7438b0b9b479e623bdded0a85da`. See [CHANGES.md](CHANGES.md) for the
Docker changes, [README.upstream.md](README.upstream.md) for the original
documentation, and [LICENSE](LICENSE) for the license.

## Requirements

- Docker Engine on Linux with Docker Compose v2, or a compatible Linux container engine.
- A running Linux Discord desktop client, logged in, with its IPC socket
  available to the Discrakt container. The browser version of Discord won't work.
- A Trakt, Plex, or Jellyfin account to connect through the setup wizard.

You can build images for `linux/amd64` and `linux/arm64`, including from macOS or
Windows. Docker Desktop runs containers in a Linux VM, so it can't automatically
use your Mac Discord socket or Windows named pipe. Run the Linux Discord client
in the same Docker environment, or deploy both on Linux.

## Quick start: Discord already runs in Docker

Find the Docker volume that holds Discord's IPC socket. Discord must already
have that volume mounted, usually at `/tmp`. An empty volume won't connect the
two containers.

```sh
cp .env.example .env
```

In `.env`, set `DISCORD_IPC_VOLUME` to the volume's name. Set `DISCRAKT_UID` and
`DISCRAKT_GID` to the socket owner's user and group IDs. Then run:

```sh
docker compose config --quiet
docker compose build
docker compose up -d --no-build
```

Open http://127.0.0.1:18081/index.html, choose your source, authorize it with the
provider, and finish the wizard. The setup server closes when you're done.
Discrakt keeps checking for watch activity in the background and saves your
credentials in its settings volume.

The Compose project is named `discrakt-docker`. It creates its own service,
network, and settings volume, and mounts the existing Discord IPC volume.

## Alternative: native Discord on the Linux host

Find the socket on the Linux host:

```sh
find /run/user/"$(id -u)" /tmp -maxdepth 2 -type s -name 'discord-ipc-[0-9]' 2>/dev/null
```

Set `DISCORD_IPC_DIR` in `.env` to the directory containing the socket. Match
`DISCRAKT_UID` and `DISCRAKT_GID` to its owner, then use `compose.host.yaml`:

```sh
docker compose -f compose.host.yaml config --quiet
docker compose -f compose.host.yaml build
docker compose -f compose.host.yaml up -d --no-build
```

Keep `-f compose.host.yaml` in subsequent management commands. Use this file on
its own; don't combine it with `compose.yaml`.

Mount the directory so Discrakt can find the replacement socket when Discord
restarts. Mounting the socket file itself can leave it pointing to the old
socket. The directory is mounted read-only, but Discrakt can read its other
contents too. The Compose files share only the IPC directory with the Discord client.

## Remote setup and private VPN access

The setup wizard has no login of its own. Compose binds its port to
`127.0.0.1` by default. To reach it over SSH, run this on your computer:

```sh
ssh -N -L 127.0.0.1:18081:127.0.0.1:18081 YOUR_LINUX_HOST
```

Then open http://127.0.0.1:18081/index.html on that computer.

For direct access through a private VPN, set `DISCRAKT_BIND_ADDRESS` to the
Linux host's VPN interface address before starting Compose. Open
`http://VPN_ADDRESS:18081/index.html` while connected to the VPN. Keep the setup
port off public interfaces.

After changing the bind address or setup port, run
`docker compose up -d --no-build` to apply it. This keeps your settings volume.

## Build details and checks

The Dockerfile compiles Rust on the builder's native CPU and uses a cross
compiler when the image targets another architecture. With Docker Buildx:

```sh
docker buildx build --platform linux/amd64 --load -t discrakt-sidecar:amd64 .
docker buildx build --platform linux/arm64 --load -t discrakt-sidecar:arm64 .
```

You can also use Podman, for example `podman build --platform linux/amd64 ...`.
Building for another CPU architecture requires emulation to run the binary
checks. Docker Desktop normally supplies it. Native builds don't need emulation.

Each complete image build checks that React and React DOM match, builds the
setup page, checks Rust formatting, and runs the upstream library and integration
tests. It also runs the target binary against local HTTP and Discord IPC mocks.
These checks use dummy settings and don't contact your Discord or media
accounts. The final image excludes the build and test tools.

The image runs as an unprivileged user. Compose makes the root filesystem
read-only, drops Linux capabilities, limits resources and log size, and enables
Docker init. Settings stay in a writable volume. The default UID and GID are
1000; rebuild the image if you change them, and check ownership before reusing
an existing settings volume.

See [VALIDATION.md](VALIDATION.md) for the completed checks and their limits.

## Management and troubleshooting

```sh
docker compose ps
docker compose logs --tail 30
docker compose restart discrakt
docker compose down
```

`down` keeps the settings volume. `down --volumes` deletes it, including your
saved credentials. Credentials live at `/config/discrakt/credentials.ini`.
Keep that file out of commits and public issues. The ignore files exclude local
settings, credential backups, logs, and transfer archives.

- Cannot connect to Discord: check that Discord is logged in, the IPC directory
  or volume contains its socket, and the configured UID has permission to use it.
  Putting both containers on the same Docker network won't share the socket.
- Setup port closes after authorization: this is expected. Discrakt closes the
  server after you finish setup.
- Blank setup page: React and React DOM are pinned to the same version, and the
  build rejects a mismatch. Reload the page after changing images.
- Progress moves backward: Discrakt estimates Trakt progress from watch
  timestamps. Updates to those timestamps can change the estimate. The logs
  don't record explicit player seek events.

## Sharing this fork

The branch includes the upstream source and Docker changes. Set up your own
remote before publishing; `upstream` points to the original project.

Use the source ZIP if you don't need Git history. To get the history from a Git
bundle, run:

```sh
git clone PATH_TO_BUNDLE discrakt-docker
```
