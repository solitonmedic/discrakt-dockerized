#!/bin/sh
set -eu

# Compile on the builder's native CPU, including when the output image targets
# another architecture. This avoids running rustc under CPU emulation.
case "${1:?target architecture is required}" in
    amd64)
        discrakt_target=x86_64-unknown-linux-gnu
        export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=x86_64-linux-gnu-gcc
        ;;
    arm64)
        discrakt_target=aarch64-unknown-linux-gnu
        export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
        ;;
    *)
        printf 'Unsupported architecture: %s\n' "$1" >&2
        exit 1
        ;;
esac

cargo build --locked --release --target "$discrakt_target"
install -D "target/$discrakt_target/release/discrakt" /out/discrakt
