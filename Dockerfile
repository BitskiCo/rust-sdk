# syntax=docker/dockerfile:1

ARG BUILDER_BASE=rust:1-buster

#############################################################################
# Build container                                                           #
#############################################################################

FROM --platform=linux/amd64 rust:1-buster AS amd64
FROM --platform=linux/arm64 rust:1-buster AS arm64

# Use buster instead of bullseye for glibc-2.28
FROM --platform=$BUILDPLATFORM $BUILDER_BASE AS builder

# Expose build env variables
ARG TARGETARCH

# Expose GitHub Actions cache args
ARG ACTIONS_CACHE_URL
ARG ACTIONS_RUNTIME_TOKEN
ARG GITHUB_SHA
ARG SCCACHE_GHA_CACHE_MODE

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/rust-sdk/bin:$PATH
ENV PATH=/usr/local/cargo-wrapper/bin:$PATH

ENV CARGO_HOME=/var/cache/cargo
ENV CARGO_INSTALL_ROOT=/build/release
ENV CARGO_TARGET_DIR=/var/cache/cargo/target
ENV SCCACHE_DIR=/var/cache/sccache

WORKDIR /workspace

# Install dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=private \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=private \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    clang \
    cmake \
    lld \
    llvm

# Install sccache for builds
RUN --mount=target=/usr/local/bin/install-sccache,source=bin/install-sccache \
    --mount=type=cache,target=.,sharing=locked \
    which sccache || install-sccache

# Install multi-arch libraries
RUN --mount=target=/usr/local/bin/install-libs,source=bin/install-libs \
    --mount=target=/sysroot/x86_64-linux-gnu,from=amd64 \
    --mount=target=/sysroot/aarch64-linux-gnu,from=arm64 \
    install-libs

# Install cargo bins
RUN --mount=target=/usr/local/bin/install-cargo-bins,source=bin/install-cargo-bins \
    --mount=target=/usr/local/cargo-wrapper/bin/cargo,source=bin/cargo \
    --mount=type=cache,target=/var/cache/cargo \
    --mount=type=cache,target=/var/cache/sccache \
    install-cargo-bins

# Cache cargo index
RUN cargo search --limit 0

#############################################################################
# Release container                                                         #
#############################################################################

# Use buster instead of bullseye for glibc-2.28
FROM rust:1-buster AS release

ENV PATH=/usr/local/rust-sdk/bin:$PATH
ENV PATH=/usr/local/cargo-wrapper/bin:$PATH

ENV CARGO_HOME=/var/cache/cargo
ENV CARGO_TARGET_DIR=/var/cache/cargo/target
ENV SCCACHE_DIR=/var/cache/cargo/target/sccache

WORKDIR /workspace

# Install dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=private \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=private \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    clang \
    cmake \
    jq \
    lld \
    llvm \
    protobuf-compiler \
    zstd

# Download public key for github.com
RUN ssh-keyscan github.com | tee -a /etc/ssh/ssh_known_hosts

# Install multi-arch libraries
RUN --mount=target=/usr/local/bin/install-libs,source=bin/install-libs \
    --mount=target=/sysroot/x86_64-linux-gnu,from=amd64 \
    --mount=target=/sysroot/aarch64-linux-gnu,from=arm64 \
    install-libs

# Install executables
COPY --from=bufbuild/buf /usr/local/bin/buf /usr/local/rust-sdk/bin/
COPY --from=builder /build/release/bin/* /usr/local/rust-sdk/bin/
COPY bin/cargo /usr/local/cargo-wrapper/bin/

# Cache cargo index
COPY --from=builder /var/cache/cargo/registry /var/cache/cargo/registry

# Cache cargo toolchain
RUN --mount=target=rust-toolchain.toml,source=rust-toolchain.toml \
    rustup show
