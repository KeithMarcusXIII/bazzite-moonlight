#!/usr/bin/env bash
set -euo pipefail
# Proxy launcher: passes the JSON configuration to the managed-flatpaks.nu module.
# The BlueBuild CLI discovers modules via <name>.sh and executes them directly
# in the Containerfile (respecting shebangs). This proxy delegates to the
# nushell implementation at build time.
exec /usr/libexec/bluebuild/nu/nu "$(dirname "$0")/managed-flatpaks.nu" "$1"
