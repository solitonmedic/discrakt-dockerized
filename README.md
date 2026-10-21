# Discrakt for Docker

Run [Discrakt](https://github.com/afonsojramos/discrakt) in Docker without a
display or system tray. It sends your Trakt, Plex, or Jellyfin watch activity
to Discord Rich Presence, with artwork and estimated playback progress.

Discrakt connects through the Discord desktop client's local IPC socket. The
client can run directly on Linux or in another container. The examples below
cover both arrangements; choose the one that matches where your socket lives.

This is an unofficial Docker adaptation of Afonso Ramos's MIT-licensed project.
It includes the full source, based on upstream commit
`87c66612a6eaf7438b0b9b479e623bdded0a85da`. See [CHANGES.md](CHANGES.md) for the
Docker changes, [README.upstream.md](README.upstream.md) for the original
documentation, and [LICENSE](LICENSE) for the license.

## Requirements

- Docker Engine on Linux with Docker Compose v2, or a compatible Linux container engine.
- A logged-in Linux Discord desktop client whose IPC socket the container can
  access. The browser version of Discord doesn't provide that socket.
- A Trakt, Plex, or Jellyfin account to connect through the setup wizard.

The image `ghcr.io/solitonmedic/discrakt-dockerized:latest` supports `linux/amd64`
and `linux/arm64`. Docker selects the architecture for your host. Docker
Desktop's Linux VM can't automatically use your native Mac
Discord socket or Windows named pipe. These examples require a Linux Discord
client and access to its socket from the container.

## Set up the container

Copy the example settings, then choose a socket mount:

```sh
cp .env.example .env
```

| Where the socket is | Compose file | Setting in `.env` |
| --- | --- | --- |
| A directory on the Linux host | `compose.host.yaml` | `DISCORD_IPC_DIR` |
| A Docker volume shared with Discord | `compose.yaml` | `DISCORD_IPC_VOLUME` |

Both files run the same Discrakt image. Each is a complete example; use one at
a time. The published image runs as UID/GID 1000. Check the socket owner's IDs
before starting. If they differ, follow [Build from source](#build-from-source)
to build an image with matching IDs. Changing the values in `.env` alone does
not change the user inside a prebuilt image.

### Discord installed on the Linux host

Start Discord and find its socket:

```sh
find /run/user/"$(id -u)" /tmp -maxdepth 2 -type s -name 'discord-ipc-[0-9]' 2>/dev/null
```

Set `DISCORD_IPC_DIR` to the directory containing the socket. The sample path
`/run/user/1000` may differ on your machine. Then run:

```sh
docker compose -f compose.host.yaml config --quiet
docker compose -f compose.host.yaml pull
docker compose -f compose.host.yaml up -d --no-build
```

Keep `-f compose.host.yaml` in subsequent commands for this setup.

Mount the directory so Discrakt can find the replacement socket when Discord
restarts. Mounting the socket file itself can leave it pointing to the old
socket. The directory is mounted read-only, but Discrakt can read its other
contents too.

### Discord running in another container

Use this example if Discord writes its IPC socket into a Docker volume.
Set `DISCORD_IPC_VOLUME` to that volume's name, then run:

```sh
docker compose -f compose.yaml config --quiet
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d --no-build
```

The volume must contain Discord's socket. Creating an empty volume or putting
both containers on the same Docker network won't connect them. Check your
Discord container's mounts to find the volume and the socket owner's IDs.

The Discrakt Compose project is named `discrakt-docker`. It creates its own
service, network, and settings volume, and mounts the IPC volume you specify.
No particular Discord image or volume name is required.

## Connect a watch source

Open http://127.0.0.1:18081/index.html on the Docker host. Choose your source,
authorize it with the provider, and finish the wizard. The setup server closes
when you're done. Discrakt keeps checking for watch activity in the background
and saves your credentials in its settings volume.

## Build from source

To build locally, set `DISCRAKT_IMAGE=discrakt-sidecar:local` in `.env`. Set
`DISCRAKT_UID` and `DISCRAKT_GID` to the IDs that need access to Discord's socket.
Then build and start with the Compose file you chose. For the host-directory
example:

```sh
docker compose -f compose.host.yaml build
docker compose -f compose.host.yaml up -d --no-build
```

For the shared-volume example, use `-f compose.yaml` instead. Skip the `pull`
step when using your locally built image.

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

## Published images

The [container workflow](.github/workflows/container.yml) publishes to
[GHCR](https://github.com/solitonmedic/discrakt-dockerized/pkgs/container/discrakt-dockerized)
when image source files change on `main`, or when run manually from that branch.
`latest` follows successful builds from `main`. Each build also gets a
`sha-<full-commit-id>` tag so you can select a specific source revision.

Pushing a tag such as `docker-v1.0.0` publishes the image tag `1.0.0`. These
Docker release tags are separate from upstream Discrakt's release tags.
Tag builds leave `latest` unchanged.

## Management and troubleshooting

These commands use the host-directory example. For the shared-volume example,
replace `compose.host.yaml` with `compose.yaml`:

```sh
docker compose -f compose.host.yaml ps
docker compose -f compose.host.yaml logs --tail 30
docker compose -f compose.host.yaml restart discrakt
docker compose -f compose.host.yaml down
```

`down` keeps the settings volume. `down --volumes` deletes it, including your
saved credentials. Credentials live at `/config/discrakt/credentials.ini`.
Keep that file out of commits and public issues. The ignore files exclude local
settings, credential backups, logs, and transfer archives.

- Cannot connect to Discord: check that Discord is logged in, the mounted
  directory or volume contains its socket, and the configured UID has permission
  to use it.
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
