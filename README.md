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
docker run --rm -it quay.io/bitski/rust-sdk:latest
```

Use as cross-compiler in a `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1

# Use the native builder image
FROM --platform=$BUILDPLATFORM quay.io/bitski/rust-sdk AS builder

# Expose the `TARGETARCH` env variable
ARG TARGETARCH

# Setup the environment and install the binary
RUN --mount=target=/workspace \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/var/cache,sharing=locked \
    eval "$(cargo-cross-env)" && \
    cargo install --root "/dist"

# Use the target release image
FROM registry.access.redhat.com/ubi8/ubi-minimal AS release

# Copy the built binaries
COPY --from=builder /dist/* /usr/local/bin/

# Set the image command
CMD ["/usr/local/bin/hello-world"]
```

If you run into any issues, see [`cross-rs/cross`][cross] for possible missing
environmental variables.

## Development

### Local build

Build a local image:

```sh
docker buildx build --tag quay.io/bitski/rust-sdk:latest --load .
```

### Publish

> **Warning**
>
> The multi-platform currently fails on AMD64 machines due to `dpkg` issues when
> running under Qemu emulation.

Login Quay.io:

```sh
docker login quay.io
```

Then build and publish the [multi-platform image][docker-multiplatform]:

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag quay.io/bitski/rust-sdk:latest \
  --push .
```

[buildkit]: https://github.com/moby/buildkit
[cross]: https://github.com/cross-rs/cross
[docker-multiplatform]: https://docs.docker.com/build/buildx/multiplatform-images/
[docker]: https://www.docker.com/get-started/
[rust]: https://www.rust-lang.org
[ubi8]: https://catalog.redhat.com/software/containers/ubi8-minimal/5c64772edd19c77a158ea216
