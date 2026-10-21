# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM docker.io/library/node:26-bookworm-slim AS setup-ui
WORKDIR /app/setup-ui
RUN npm install --global @nubjs/nub@0.9.7
COPY setup-ui/package.json setup-ui/pnpm-lock.yaml setup-ui/pnpm-workspace.yaml ./
RUN nub install --frozen-lockfile
COPY setup-ui/ ./
RUN node -e 'const react = require("react/package.json").version; const dom = require("react-dom/package.json").version; if (react !== dom) throw new Error("React and React DOM versions must match"); console.log("React and React DOM:", react)' \
    && nub run build

FROM --platform=$BUILDPLATFORM docker.io/library/rust:1.99.0-bookworm AS build
ARG TARGETARCH
ARG DISCRAKT_VERSION=docker-sidecar
WORKDIR /app
RUN case "$TARGETARCH" in \
        amd64) compiler=gcc-x86-64-linux-gnu; headers=libc6-dev-amd64-cross; target=x86_64-unknown-linux-gnu ;; \
        arm64) compiler=gcc-aarch64-linux-gnu; headers=libc6-dev-arm64-cross; target=aarch64-unknown-linux-gnu ;; \
        *) printf 'Unsupported architecture: %s\n' "$TARGETARCH" >&2; exit 1 ;; \
    esac \
    && apt-get update \
    && apt-get install -y --no-install-recommends "$compiler" "$headers" \
    && rm -rf /var/lib/apt/lists/* \
    && rustup target add "$target"
ENV DISCRAKT_SKIP_UI_BUILD=1 \
    DISCRAKT_VERSION=$DISCRAKT_VERSION \
    CARGO_BUILD_JOBS=1 \
    CARGO_PROFILE_RELEASE_LTO=false \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
COPY Cargo.toml Cargo.lock build.rs rust-toolchain.toml ./
COPY src/ src/
COPY assets/ assets/
COPY container/build-release.sh /usr/local/bin/build-discrakt-release
COPY --from=setup-ui /app/setup-ui/dist setup-ui/dist
RUN cargo fmt --all --check
RUN --mount=type=cache,id=discrakt-cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=discrakt-cargo-target,target=/app/target \
    sh /usr/local/bin/build-discrakt-release "$TARGETARCH"
COPY tests/ tests/
RUN --mount=type=cache,id=discrakt-cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=discrakt-cargo-target,target=/app/target \
    cargo test --locked --target "$(rustc -vV | sed -n 's/^host: //p')" --lib --tests

FROM docker.io/library/debian:bookworm-slim AS runtime-base
ARG DISCRAKT_UID=1000
ARG DISCRAKT_GID=1000
RUN test "$DISCRAKT_UID" -gt 0 && test "$DISCRAKT_GID" -gt 0 \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --non-unique --gid "$DISCRAKT_GID" discrakt \
    && useradd --non-unique --uid "$DISCRAKT_UID" --gid "$DISCRAKT_GID" --no-create-home --home-dir /config discrakt \
    && install -d -o "$DISCRAKT_UID" -g "$DISCRAKT_GID" -m 0700 /config /config/discrakt
COPY --from=build /out/discrakt /usr/local/bin/discrakt
LABEL org.opencontainers.image.source="https://github.com/solitonmedic/discrakt-dockerized" \
    io.discrakt.upstream.source="https://github.com/afonsojramos/discrakt" \
    io.discrakt.upstream.revision="87c66612a6eaf7438b0b9b479e623bdded0a85da" \
    org.opencontainers.image.description="Discrakt headless Docker sidecar; see included README for fork changes" \
    org.opencontainers.image.licenses="MIT"
ENV HOME=/config \
    XDG_CONFIG_HOME=/config \
    XDG_RUNTIME_DIR=/discord-ipc \
    DISCRAKT_HEADLESS=1 \
    DISCRAKT_SETUP_ADDR=0.0.0.0:8080 \
    RUST_LOG=info
USER $DISCRAKT_UID:$DISCRAKT_GID
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/discrakt"]
CMD ["--headless"]

FROM runtime-base AS verify
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*
COPY container/check-headless.py /opt/check-headless.py
USER discrakt
RUN python3 /opt/check-headless.py /usr/local/bin/discrakt \
    && printf 'Headless setup, invalid address, IPC polling: passed\n' > /tmp/verification.ok

FROM runtime-base AS runtime
COPY --from=verify /tmp/verification.ok /usr/share/discrakt/verification.txt
COPY LICENSE /usr/share/doc/discrakt/LICENSE
COPY README.md /usr/share/doc/discrakt/README.md
