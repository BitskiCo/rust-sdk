# `rust-sdk`

[Rust][rust] SDK.

## Prerequisites

Install [Docker][docker] and configure [BuildKit][buildkit]:

```sh
docker buildx create --use --name buildkit
```

## Usage

Use as builder:

```sh
docker run --rm -it ghcr.io/jakelee8/rust-sdk:latest
```

Use as cross-compiler in a `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1

#############################################################################
# Build container                                                           #
#############################################################################

# Use the native builder image
FROM --platform=$BUILDPLATFORM ghcr.io/jakelee8/rust-sdk AS builder

# Expose build env variables
ARG TARGETARCH

# Expose GitHub Actions cache args
ARG ACTIONS_CACHE_URL
ARG ACTIONS_RUNNER_DEBUG
ARG ACTIONS_RUNTIME_TOKEN
ARG GITHUB_SHA
ARG SCCACHE_GHA_CACHE_MODE

# Build and install the binary
RUN --mount=target=. \
    --mount=type=cache,target=/var/cache/cargo/git \
    --mount=type=cache,target=/var/cache/cargo/target,sharing=private \
    cargo install --locked --root /usr/local

#############################################################################
# Release container                                                         #
#############################################################################

# Use the target release image
FROM registry.access.redhat.com/ubi8/ubi-minimal AS release

# Copy the built binaries
COPY --from=builder /usr/local/bin/* /usr/local/bin/

# Set the image command
CMD ["/usr/local/bin/hello-world"]
```

If you run into any issues, see [`cross-rs/cross`][cross] for possible missing
environmental variables.

## Development

### Local build

Build a local image:

```sh
docker buildx bake --load local
```

### Publish

Login to GitHub and Quay.io:

```sh
docker login ghcr.io
docker login quay.io
```

If you are not using Docker Desktop, install QEMU binaries:

```sh
docker run --rm --privileged tonistiigi/binfmt:latest --install arm64
```

Then build and publish the [multi-platform image][docker-multiplatform]:

```sh
docker buildx bake --push
```

[buildkit]: https://github.com/moby/buildkit
[cross]: https://github.com/cross-rs/cross
[docker-multiplatform]: https://docs.docker.com/build/buildx/multiplatform-images/
[docker]: https://www.docker.com/get-started/
[rust]: https://www.rust-lang.org
[ubi8]: https://catalog.redhat.com/software/containers/ubi8-minimal/5c64772edd19c77a158ea216
