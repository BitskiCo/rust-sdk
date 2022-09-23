# syntax=docker/dockerfile:1

#############################################################################
# Build container                                                           #
#############################################################################

# Use buster instead of bullseye for glibc-2.28
FROM --platform=$BUILDPLATFORM rust:1-buster AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

# Set cargo target dir for caching
ENV CARGO_TARGET_DIR=/var/cache/cargo/target

# Install scripts
COPY bin/cargo-cross-env /usr/local/bin/

# Install dependencies
RUN --mount=target=/usr/local/bin/install-deps,source=bin/install-deps \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && install-deps

# Run builder
RUN --mount=target=/usr/local/bin/install-cargo-bins,source=bin/install-cargo-bins \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/var/cache/cargo \
    install-cargo-bins

#############################################################################
# Release container                                                         #
#############################################################################

# Use buster instead of bullseye for glibc-2.28
FROM rust:1-buster AS release

ARG DEBIAN_FRONTEND=noninteractive

# Set cargo target dir for caching
ENV CARGO_TARGET_DIR=/var/cache/cargo/target

# Install dependencies
RUN --mount=target=/usr/local/bin/install-deps,source=bin/install-deps \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    for arch in amd64 arm64; do TARGETARCH=$arch install-deps; done

# Download public key for github.com
RUN mkdir -p -m 0600 ~/.ssh && \
    ssh-keyscan github.com | \
    tee -a /etc/ssh/ssh_known_hosts

# Configure env
RUN echo 'eval "$(cargo-cross-env)"' >> /etc/profile

# Install executables
COPY --from=builder /usr/local/bin/* /usr/local/bin/

# Install buf
COPY --from=bufbuild/buf /usr/local/bin/buf /usr/local/bin/

WORKDIR /workspace
