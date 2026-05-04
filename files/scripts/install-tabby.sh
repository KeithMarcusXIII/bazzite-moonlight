#!/usr/bin/env bash
set -oue pipefail

echo "=== Installing Tabby Terminal ==="

# Map RPM architecture to Tabby's naming convention
TABBY_ARCH="$(rpm --eval '%{_arch}' | sed 's/x86_64/x64/;s/aarch64/arm64/')"
echo "Detected architecture: $(rpm --eval '%{_arch}') → Tabby arch: ${TABBY_ARCH}"

# Fetch the latest release tag from GitHub API (stable, no dependency on Electron Builder manifests)
echo "Fetching latest release info..."
TABBY_TAG=$(curl -fsSL "https://api.github.com/repos/Eugeny/tabby/releases/latest" \
  | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')

if [ -z "${TABBY_TAG}" ]; then
  echo "ERROR: Failed to determine latest Tabby release tag" >&2
  exit 1
fi
echo "Latest release: ${TABBY_TAG}"

# Construct and download the RPM
# Tag format: v1.0.231 → RPM filename: tabby-1.0.231-linux-x64.rpm
RPM_URL="https://github.com/Eugeny/tabby/releases/download/${TABBY_TAG}/tabby-${TABBY_TAG#v}-linux-${TABBY_ARCH}.rpm"
echo "Downloading: ${RPM_URL}"
curl -fsSL "${RPM_URL}" -o /tmp/tabby.rpm

echo "Installing RPM via rpm-ostree..."
rpm-ostree install /tmp/tabby.rpm

echo "=== Tabby installation complete ==="
