# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 rust:1-buster AS amd64
FROM --platform=linux/arm64 rust:1-buster AS arm64

#############################################################################
# Build container                                                           #
#############################################################################

# Use buster instead of bullseye for glibc-2.28
FROM --platform=$BUILDPLATFORM rust:1-buster AS builder

# Expose build env variables
ARG TARGETARCH

# Expose GitHub Actions cache args
ARG ACTIONS_CACHE_URL
ARG ACTIONS_RUNTIME_TOKEN
ARG SCCACHE_GHA_CACHE_MODE

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/rust-sdk/bin:$PATH
ENV PATH=/usr/local/cargo-wrapper/bin:$PATH

ENV CARGO_HOME=/var/cache/cargo
ENV CARGO_INSTALL_ROOT="/build/$TARGETARCH/release"
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

# Install multi-arch libraries
COPY --from=amd64 /lib/x86_64-linux-gnu /lib/x86_64-linux-gnu
COPY --from=amd64 /usr/include/x86_64-linux-gnu /usr/include/x86_64-linux-gnu
COPY --from=amd64 /usr/lib/gcc/x86_64-linux-gnu /usr/lib/gcc/x86_64-linux-gnu
COPY --from=amd64 /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu

COPY --from=arm64 /lib/aarch64-linux-gnu /lib/aarch64-linux-gnu
COPY --from=arm64 /usr/include/aarch64-linux-gnu /usr/include/aarch64-linux-gnu
COPY --from=arm64 /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
COPY --from=arm64 /usr/lib/gcc/aarch64-linux-gnu /usr/lib/gcc/aarch64-linux-gnu

# Install sccache for builds
RUN --mount=target=/usr/local/bin/install-sccache,source=bin/install-sccache \
    --mount=type=cache,target=.,sharing=locked \
    which sccache || install-sccache

# Install cargo bins
RUN --mount=target=/usr/local/bin/install-cargo-bins,source=bin/install-cargo-bins \
    --mount=target=/usr/local/cargo-wrapper/bin/cargo,source=bin/cargo \
    --mount=type=cache,target=/var/cache/cargo/git \
    --mount=type=cache,target=/var/cache/cargo/target \
    --mount=type=cache,target=/var/cache/sccache \
    install-cargo-bins

#############################################################################
# Release container                                                         #
#############################################################################

# Use buster instead of bullseye for glibc-2.28
FROM rust:1-buster AS release

# Expose build env variables
ARG TARGETARCH

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
COPY --from=amd64 /lib/x86_64-linux-gnu /lib/x86_64-linux-gnu
COPY --from=amd64 /usr/include/x86_64-linux-gnu /usr/include/x86_64-linux-gnu
COPY --from=amd64 /usr/lib/gcc/x86_64-linux-gnu /usr/lib/gcc/x86_64-linux-gnu
COPY --from=amd64 /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu

COPY --from=arm64 /lib/aarch64-linux-gnu /lib/aarch64-linux-gnu
COPY --from=arm64 /usr/include/aarch64-linux-gnu /usr/include/aarch64-linux-gnu
COPY --from=arm64 /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
COPY --from=arm64 /usr/lib/gcc/aarch64-linux-gnu /usr/lib/gcc/aarch64-linux-gnu

# Install executables
COPY --from=bufbuild/buf /usr/local/bin/buf /usr/local/rust-sdk/bin/
COPY --from=builder /build/$TARGETARCH/release/bin/* /usr/local/rust-sdk/bin/
COPY bin/cargo /usr/local/cargo-wrapper/bin/

# Cache cargo index
COPY --from=builder /var/cache/cargo/registry /var/cache/cargo/
