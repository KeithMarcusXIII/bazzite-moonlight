# bazzite-moonlight — Deployment Guide

**Date:** 2026-04-26
**Deployment Model:** OCI Container Image via GitHub Container Registry

## Infrastructure Requirements

### Build Infrastructure
- **Runner:** GitHub Actions `ubuntu-latest` (GitHub-hosted)
- **Permissions:** `contents: read`, `packages: write`, `id-token: write`
- **Storage:** Maximized build space (`maximize_build_space: true`)
- **Secrets Required:** `SIGNING_SECRET` (cosign private key)

### Consumer Requirements
- Fedora Atomic or Bazzite system with `rpm-ostree` support
- Internet connectivity for image download

## Deployment Process

### Image Publication Flow

```
Developer Push → GitHub Actions → Build → Sign → Push to GHCR → Consumer Rebase
```

### Automated Build Pipeline

The build is fully automated by the BlueBuild GitHub Action (`blue-build/github-action@v1.11`).

#### Build Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `recipe` | `${{ matrix.recipe }}` | Recipe file to build |
| `cosign_private_key` | `${{ secrets.SIGNING_SECRET }}` | Private key for image signing |
| `registry_token` | `${{ github.token }}` | GitHub token for GHCR push |
| `pr_event_number` | `${{ github.event.number }}` | PR number for PR builds |

#### Build Stages

1. **Parse Recipe** — BlueBuild reads [`recipe.yml`](../recipes/recipe.yml) and all included modules
2. **Pull Base** — Fetches `ghcr.io/ublue-os/bazzite-dx-gnome:stable`
3. **Layer Packages** — Applies DNF installs/removals from [`common-packages.yml`](../recipes/common-packages.yml)
4. **Layer Flatpaks** — Installs Flatpaks from [`common-flatpaks.yml`](../recipes/common-flatpaks.yml)
5. **Layer Dotfiles** — Configures chezmoi from [`common-dotfiles.yml`](../recipes/common-dotfiles.yml)
6. **Sign Image** — Signs the final image with cosign using the private key
7. **Push** — Publishes to `ghcr.io/keithmarcusxiii/bazzite-moonlight`

### Build Triggers

| Event | Details |
|-------|---------|
| **Scheduled** | Daily at 06:00 UTC (20 min after uBlue base images build) |
| **Push** | Any push except files matching `**.md` |
| **Pull Request** | Build for validation; published as `pr-<NUMBER>` tag |
| **Manual** | `workflow_dispatch` in GitHub Actions UI |

### Image Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent successful build |
| `pr-<NUMBER>` | Build from a pull request |
| `<version>` | Specific version tag (if configured) |

## Environment Configuration

### GitHub Secrets

```yaml
# Required for signing — generate with:
#   cosign generate-key-pair
# Store the private key:
#   gh secret set SIGNING_SECRET --body "$(cat cosign.key)"

SIGNING_SECRET: <cosign-private-key>
```

The public key is committed to the repository as [`cosign.pub`](../cosign.pub).

### Recipe Configuration

The [`recipe.yml`](../recipes/recipe.yml) defines all deployable state:

```yaml
name: bazzite-moonlight
description: Moonlight Client Bazzite OS image.
base-image: ghcr.io/ublue-os/bazzite-dx-gnome
image-version: stable
```

## CI/CD Pipeline Details

### Workflow: `bluebuild` ([`.github/workflows/build.yml`](../.github/workflows/build.yml))

```yaml
name: bluebuild
on:
  schedule:
    - cron: "00 06 * * *"     # Daily build
  push:
    paths-ignore:
      - "**.md"                # Skip doc-only changes
  pull_request:                # Build on PR
  workflow_dispatch:           # Manual trigger

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true     # One build at a time

jobs:
  bluebuild:
    name: Build Custom Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    strategy:
      fail-fast: false
      matrix:
        recipe:
          - recipe.yml
    steps:
      - name: Build Custom Image
        uses: blue-build/github-action@v1.11
        with:
          recipe: ${{ matrix.recipe }}
          cosign_private_key: ${{ secrets.SIGNING_SECRET }}
          registry_token: ${{ github.token }}
          pr_event_number: ${{ github.event.number }}
          maximize_build_space: true
```

### Dependabot Configuration

GitHub Actions dependencies are auto-updated daily:
```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "daily"
```

## Consumer Installation

### Fresh Install

On any Fedora Atomic or Bazzite system:

```bash
# Step 1: Rebase to unsigned image (installs signing keys)
rpm-ostree rebase ostree-unverified-registry:ghcr.io/keithmarcusxiii/bazzite-moonlight:latest

# Step 2: Reboot
systemctl reboot

# Step 3: Rebase to signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/keithmarcusxiii/bazzite-moonlight:latest

# Step 4: Reboot to complete
systemctl reboot
```

### Updates

Once installed, the system will automatically receive updates via rpm-ostree's update mechanism. The `latest` tag always points to the most recent successful build.

### Offline ISO Installation

An ISO can be generated from the built image for offline/bare-metal installation. See the [BlueBuild ISO generation guide](https://blue-build.org/how-to/generate-iso/).

## Verification

Verify the authenticity of the deployed image:

```bash
# Download the public key
curl -O https://raw.githubusercontent.com/keithmarcusxiii/bazzite-moonlight/main/cosign.pub

# Verify the image
cosign verify --key cosign.pub ghcr.io/keithmarcusxiii/bazzite-moonlight
```

## Rollback

If an update causes issues, rollback with rpm-ostree:

```bash
# Rollback to the previous deployment
rpm-ostree rollback

# Reboot to apply
systemctl reboot
```

---

_Generated using BMAD Method `document-project` workflow_
