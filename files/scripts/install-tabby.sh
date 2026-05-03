#!/usr/bin/env bash
set -oue pipefail

echo "=== Installing Tabby Terminal ==="

# Map RPM architecture to Tabby's naming convention
TABBY_ARCH="$(rpm --eval '%{_arch}' | sed 's/x86_64/x64/;s/aarch64/arm64/')"
echo "Detected architecture: $(rpm --eval '%{_arch}') → Tabby arch: ${TABBY_ARCH}"

# Fetch the latest version from Tabby's auto-updater manifest
echo "Fetching latest version manifest..."
curl -fsSL \
  "https://github.com/Eugeny/tabby/releases/latest/download/latest-${TABBY_ARCH}-linux.yml" \
  -o /tmp/tabby-manifest.yml

TABBY_VER="$(grep '^version:' /tmp/tabby-manifest.yml | awk '{print $2}')"
echo "Latest version: ${TABBY_VER}"

# Download and install the RPM
RPM_URL="https://github.com/Eugeny/tabby/releases/download/v${TABBY_VER}/tabby-${TABBY_VER}-linux-${TABBY_ARCH}.rpm"
echo "Downloading: ${RPM_URL}"
curl -fsSL "${RPM_URL}" -o /tmp/tabby.rpm

echo "Installing RPM via rpm-ostree..."
rpm-ostree install /tmp/tabby.rpm

echo "=== Tabby installation complete ==="
