# syntax=docker/dockerfile:1

#############################################################################
# Build container                                                           #
#############################################################################

# Use buster instead of bullseye for glibc-2.28
FROM --platform=$BUILDPLATFORM rust:1-buster AS builder

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/rust-sdk/bin:$PATH
ENV PATH=/usr/local/cargo-wrapper/bin:$PATH

ENV CARGO_HOME=/var/cache/cargo
ENV CARGO_TARGET_DIR=/var/cache/cargo/target
ENV SCCACHE_DIR=/var/cache/sccache

# Install dependencies
RUN --mount=target=/usr/local/bin/install-deps,source=bin/install-deps \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    install-deps

# Install cargo bins
COPY bin/cargo-cross-env /usr/local/rust-sdk/bin/
RUN --mount=target=/usr/local/bin/install-cargo-bins,source=bin/install-cargo-bins \
    --mount=type=cache,target=/var/cache/cargo \
    --mount=type=cache,target=/var/cache/cargo/target,sharing=private \
    install-cargo-bins

#############################################################################
# Release container                                                         #
#############################################################################

# Use buster instead of bullseye for glibc-2.28
FROM rust:1-buster AS release

ARG TARGETARCH

ENV PATH=/usr/local/rust-sdk/bin:$PATH
ENV PATH=/usr/local/cargo-wrapper/bin:$PATH

ENV CARGO_HOME=/var/cache/cargo
ENV CARGO_TARGET_DIR=/var/cache/cargo/target
ENV SCCACHE_DIR=/var/cache/sccache

# Install dependencies
# $TARGETARCH must be last to support native builds
RUN --mount=target=/usr/local/bin,source=bin \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    for arch in amd64 arm64 $TARGETARCH; do \
    TARGETARCH=$arch install-deps; \
    done

# Download public key for github.com
RUN ssh-keyscan github.com | tee -a /etc/ssh/ssh_known_hosts

# Install executables
COPY --from=bufbuild/buf /usr/local/bin/buf /usr/local/rust-sdk/bin/
COPY --from=builder /usr/local/rust-sdk/bin/* /usr/local/rust-sdk/bin/
COPY bin/cargo /usr/local/cargo-wrapper/bin/

WORKDIR /workspace

# Cache cargo index
RUN cargo search --limit 0
