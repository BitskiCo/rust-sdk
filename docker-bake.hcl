group "default" {
  targets = ["release"]
}

target "defaults" {
  context = "."
  dockerfile = "Dockerfile"
}

target "docker-metadata-action" {
  tags = [
    "ghcr.io/bitskico/rust-sdk:latest",
    "quay.io/bitski/rust-sdk:latest"
  ]
}

target "local" {
  inherits = [
    "defaults",
    "docker-metadata-action"
  ]
}

target "release" {
  inherits = [
    "defaults",
    "docker-metadata-action"
  ]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
