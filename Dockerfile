# syntax=docker/dockerfile:1

#############################################################################
# Build container                                                           #
#############################################################################
FROM --platform=$BUILDPLATFORM rust:1-buster AS builder

ARG TARGETARCH

# Install scripts
COPY bin/cargo-cross-env /usr/local/bin/

# Upgrade and install dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=target=/usr/local/bin/install-deps,source=bin/install-deps \
    --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    install-deps

# Run builder
RUN --mount=target=/usr/local/bin/install-cargo-bins,source=bin/install-cargo-bins \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    install-cargo-bins

# ------------------------------------------------------------------------- #
FROM bufbuild/buf AS buf

#############################################################################
# Release container                                                         #
#############################################################################
FROM rust:1-buster AS release

# Upgrade and install dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=target=/usr/local/bin/install-deps,source=bin/install-deps \
    --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    install-deps

# Install executables
COPY --from=builder \
    /dist/* \
    /usr/local/bin/cargo-cross-env \
    /usr/local/bin/

# Install buf
COPY --from=buf /usr/local/bin/buf /usr/local/bin/

WORKDIR /workspace
