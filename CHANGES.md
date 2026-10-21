# Docker adaptation

Upstream: https://github.com/afonsojramos/discrakt

Base commit: `87c66612a6eaf7438b0b9b479e623bdded0a85da`.

## Application changes carried from the working sidecar

- `src/main.rs`: `--headless` / `DISCRAKT_HEADLESS=1` bypass the display event
  loop and tray, and send logs to stdout. Normal desktop startup is retained.
- `src/setup/server.rs`: `DISCRAKT_SETUP_ADDR` configures the setup listener.
  Headless mode prints setup guidance instead of opening a browser. Raw setup
  form bodies are no longer logged at debug level.
- `setup-ui/package.json` and `setup-ui/pnpm-lock.yaml`: React and React DOM
  are pinned to 19.2.8 to fix the browser startup crash from mismatched versions.
- `container/check-headless.py`: exercises setup serving, invalid listener
  configuration, and headless polling through mock Discord IPC.

## Portable packaging

- Multi-stage Dockerfile with amd64/arm64 target selection, native Rust build
  stages, an exact React-version check, and build/runtime checks.
- Configurable, non-root runtime UID/GID, persistent account settings, read-only
  IPC mounts, and loopback setup access by default.
- `compose.yaml` for an existing shared Docker IPC volume;
  `compose.host.yaml` for the native Linux client's IPC directory.
- `.env.example`, source/build ignore rules, this README, and preserved upstream
  documentation and MIT license.

This repository contains generic examples. Deployment-specific hostnames,
addresses, account state, logs, backups, screenshots, and image archives from
the working installation are not included.
