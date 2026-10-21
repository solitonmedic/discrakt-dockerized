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
