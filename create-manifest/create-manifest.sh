#!/bin/bash
set -xe

# Creates a multi-arch OCI manifest from arch-specific images that are already
# pushed to the registry, then pushes the manifest as the unified tags.
#
# Expected env vars:
#   container_name  - full image name, e.g. ghcr.io/org/image
#   container_tag   - version tag from kiwi metadata
#   architectures   - space-separated arch list, e.g. "amd64 aarch64"
#   git_tag         - optional git tag to push in addition to version tag and latest

_manifest="local-manifest-$$"

podman manifest create ${_manifest}

for _arch in ${architectures}; do
    podman manifest add ${_manifest} docker://${container_name}:${container_tag}-${_arch}
done

podman manifest push --all ${_manifest} docker://${container_name}:${container_tag}
podman manifest push --all ${_manifest} docker://${container_name}:latest

if [ -n "${git_tag}" ]; then
    podman manifest push --all ${_manifest} docker://${container_name}:${git_tag}
fi

podman manifest rm ${_manifest}
