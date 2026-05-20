# Raptor OS — Custom Bazzite Image
# Built via BlueBuild; this file is intentionally minimal.
# All customisation is declared in recipe.yml.
#
# To build locally for testing:
#   podman build -t raptor-os:local .
#
# For production, the blue-build/github-action handles everything.

FROM ghcr.io/ublue-os/bazzite:stable

# Image labels (OCI standard)
LABEL org.opencontainers.image.title="Raptor OS" \
      org.opencontainers.image.description="Gaming, development, and creative Bazzite-based custom image" \
      org.opencontainers.image.url="https://github.com/cerberus9-dev/raptor-os" \
      org.opencontainers.image.source="https://github.com/cerberus9-dev/raptor-os" \
      org.opencontainers.image.vendor="cerberus9-dev" \
      org.opencontainers.image.licenses="Apache-2.0"
