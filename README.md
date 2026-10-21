# Discrakt Dockerized

Run [Discrakt](https://github.com/afonsojramos/discrakt) in Docker and show your
Trakt, Plex, or Jellyfin watch activity in Discord, with artwork and estimated
playback progress. The container runs without a display or system tray.

The public image supports Linux AMD64 and ARM64:

```sh
docker pull ghcr.io/solitonmedic/discrakt-dockerized:latest
```

## What you need

- Docker Engine on Linux with Docker Compose v2, or a compatible container engine.
- Discord's Linux desktop client, running and logged in.
- A Trakt, Plex, or Jellyfin account to connect during setup.

Discrakt updates Discord through the desktop client's local IPC socket. You
need to give the container access to the directory or volume holding that
socket. The browser version of Discord won't work.

Docker Desktop on macOS or Windows can't automatically use the native Discord
client's socket or named pipe. These instructions require a Linux Discord client
whose socket is accessible from the container.

## Install

Get the Compose files and copy the example settings:

```sh
git clone https://github.com/solitonmedic/discrakt-dockerized.git
cd discrakt-dockerized
cp .env.example .env
```

Choose the file that matches where Discord keeps its socket:

| Socket location | Compose file | Setting in `.env` |
| --- | --- | --- |
| A directory on the Linux host | `compose.host.yaml` | `DISCORD_IPC_DIR` |
| A Docker volume shared with Discord | `compose.yaml` | `DISCORD_IPC_VOLUME` |

Use one Compose file at a time. The published image runs as UID/GID 1000. Check
that those IDs can access your socket. If you need different IDs, follow
[Build from source](#build-from-source) before starting the container. Changing
`DISCRAKT_UID` and `DISCRAKT_GID` in `.env` only affects images you build yourself.

### Discord installed on Linux

Start Discord, then find its socket:

```sh
find /run/user/"$(id -u)" /tmp -maxdepth 2 -type s -name 'discord-ipc-[0-9]' 2>/dev/null
```

In `.env`, set `DISCORD_IPC_DIR` to the directory containing the socket. Check
the path on your machine; `/run/user/1000` is an example.

```sh
docker compose -f compose.host.yaml config --quiet
docker compose -f compose.host.yaml pull
docker compose -f compose.host.yaml up -d --no-build
```

Mount the directory rather than the socket file so Discrakt can find a new
socket after Discord restarts. The mount is read-only, though Discrakt can
read the directory's other contents too.

### Discord running in a container

If Discord writes its socket into a Docker volume, set `DISCORD_IPC_VOLUME`
in `.env` to that volume's name:

```sh
docker compose -f compose.yaml config --quiet
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d --no-build
```

Check your Discord container's mounts and the socket owner's IDs. The volume
must contain Discord's socket. An empty volume or a shared Docker network
won't connect the two applications.

Compose creates a separate Discrakt service, network, and settings volume.
It mounts the IPC volume you specify, so choose the volume from your own
Discord setup.

## Connect your watch source

Open http://127.0.0.1:18081/index.html on the machine running Docker. Choose
Trakt, Plex, or Jellyfin, authorize access with the provider, and finish setup.

The setup server closes when you're done. Discrakt keeps checking for watch
activity in the background and saves your credentials in its settings volume.

## Manage the container

Use the same Compose file you chose during installation. These examples use
`compose.host.yaml`; substitute `compose.yaml` for the shared-volume setup.

```sh
docker compose -f compose.host.yaml ps
docker compose -f compose.host.yaml logs --tail 30
docker compose -f compose.host.yaml restart discrakt
docker compose -f compose.host.yaml down
```

To update the image:

```sh
docker compose -f compose.host.yaml pull
docker compose -f compose.host.yaml up -d --no-build
```

`down` keeps your settings. `down --volumes` deletes them, including saved
credentials. The credential file is `/config/discrakt/credentials.ini` inside
the container. Keep it out of commits and public issues.

## Build from source

In `.env`, set `DISCRAKT_IMAGE=discrakt-sidecar:local`. Set `DISCRAKT_UID` and
`DISCRAKT_GID` to the IDs that need access to Discord's socket. Then build with
your chosen Compose file:

```sh
docker compose -f compose.host.yaml build
docker compose -f compose.host.yaml up -d --no-build
```

For a shared Docker volume, use `-f compose.yaml`. Skip the image pull when
using a local build. Check the settings volume's ownership before reusing it
with a different UID/GID.

You can also build either architecture with Buildx:

```sh
docker buildx build --platform linux/amd64 --load -t discrakt-sidecar:amd64 .
docker buildx build --platform linux/arm64 --load -t discrakt-sidecar:arm64 .
```

The Dockerfile compiles Rust on the builder's native CPU and uses a cross
compiler when needed. Builds for another CPU architecture require emulation
to run the binary checks. Docker Desktop normally supplies it. Podman can also
build the image with `podman build --platform linux/amd64 ...`.

Each complete build checks the React versions, builds the setup page, checks
Rust formatting, runs the upstream Rust tests, and checks the target binary
against local HTTP and Discord IPC mocks. The checks use dummy settings and
don't contact your accounts. Build and test tools stay out of the final image.
See [VALIDATION.md](VALIDATION.md) for the results and their limits.

## Image versions

The [container workflow](.github/workflows/container.yml) publishes images to
[GHCR](https://github.com/solitonmedic/discrakt-dockerized/pkgs/container/discrakt-dockerized).
`latest` follows successful builds from `main`. To select a specific source
revision, use its `sha-<full-commit-id>` image tag.

The workflow runs when image source files change on `main`, and can be run
manually. Pushing `docker-v1.0.0`, for example, publishes image tag `1.0.0`.
These Docker tags are separate from upstream Discrakt releases. Tag builds
leave `latest` unchanged.

## Troubleshooting

- Cannot connect to Discord: check that Discord is logged in, the mount contains
  its socket, and the container's UID has permission to use it.
- Setup port stops responding after authorization: expected. The server closes
  after setup finishes.
- Blank setup page: this fork pins React and React DOM to the same version and
  rejects a mismatch during the build. Reload the page after changing images.
- Progress moves backward: Discrakt estimates Trakt progress from watch
  timestamps. Updated timestamps can change the estimate. The logs don't record
  explicit player seek events.

## Credits

This is an unofficial Docker adaptation of Afonso Ramos's
[Discrakt](https://github.com/afonsojramos/discrakt), based on upstream commit
`87c66612a6eaf7438b0b9b479e623bdded0a85da`. The full source and original
[MIT license](LICENSE) are included. See [CHANGES.md](CHANGES.md) for the Docker
changes and [README.upstream.md](README.upstream.md) for the original documentation.
