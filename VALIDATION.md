# Validation

The application changes were previously exercised with a Linux Discord desktop
container and a separate headless Discrakt sidecar. User-confirmed Trakt watch
activity appeared in Discord with artwork and playback progress.

The portable repository is validated locally with isolated build and test
containers. Its checks use mock HTTP/IPC services and no live account data.
No deployment commands from this repository have been run against that working
installation.

## Local results — 2026-10-20

| Check | Result |
| --- | --- |
| Complete `linux/amd64` image build | Passed |
| Complete `linux/arm64` image build | Passed |
| React and React DOM version guard / frontend build | Passed, both builds |
| Rust formatting | Passed, both builds |
| Upstream library and integration checks | 179 passed, 0 failed per build |
| Real target binary with mock HTTP and Unix IPC | 3 passed per build |
| Both standalone Compose configurations | Parsed successfully with Docker Compose v2 |
| Volume-based Compose startup | Passed with an isolated empty IPC volume and fresh settings |
| Setup UI in browser | Source tabs and Trakt login control rendered successfully |
| Shell build helper syntax / Git whitespace checks | Passed |

Builds ran in a local ARM64 Podman Linux VM. The AMD64 runtime verification used
CPU emulation; Rust compilation used the builder's native CPU. Compose startup
used the Docker CLI with Podman's compatibility socket. The host-directory
Compose alternative was checked as configuration, without starting that variant.

The three runtime checks cover embedded setup serving without a desktop, failure
on an invalid listener address, and polling an idle mock Plex server through a
mock Discord socket. The upstream Rust checks run for the builder's native CPU;
the runtime checks run the binary for each requested image architecture.

The browser check used a fresh setup session. No credentials were entered or
provider authorization requested. Temporary Compose resources were removed.

The carried application files match the working sidecar's source copy. Local
credentials, account settings, deployment receipts, personal host addresses,
and private IPC volume names were excluded from the portable repository.

These local checks do not establish live Plex/Jellyfin integration or prove a
new user's socket permissions, provider configuration, or target host behavior.

## GHCR publication — 2026-10-20

The [first container build](https://github.com/solitonmedic/discrakt-dockerized/actions/runs/39540185962)
built and pushed the image from source commit
`1d7950d3ca6bb395cd4a40207ed46d43b72bf3a1`. The inherited build and lint
workflows also passed for that commit.

Each build variant passed 179 Rust checks on the builder's native AMD64 CPU.
The real AMD64 and ARM64 binaries each passed all three headless runtime checks;
the ARM64 checks ran through emulation. The frontend version guard confirmed
React and React DOM 19.2.8.

Published tags:

- `ghcr.io/solitonmedic/discrakt-dockerized:latest`
- `ghcr.io/solitonmedic/discrakt-dockerized:sha-1d7950d3ca6bb395cd4a40207ed46d43b72bf3a1`

The image index digest is
`sha256:4c42965b1cf92965829a9f3f69bb35174d6d9ad0945ac42e7db7de5b48635660`.

Anonymous registry requests retrieved the index, both Linux architecture
manifests, and their image configurations. The retrieved content matched its
SHA-256 digests. Both images run as `1000:1000` and identify the expected source
commit and this GitHub fork. GitHub also displayed the package as public.

These registry checks used no saved GitHub or Docker credentials. They confirm
public access to the published manifests and configurations; they do not repeat
a live Discord/media integration check or start a deployed container.
