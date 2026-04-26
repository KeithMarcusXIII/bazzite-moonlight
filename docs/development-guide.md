# bazzite-moonlight — Development Guide

**Date:** 2026-04-26
**Project Type:** Infrastructure-as-Code (BlueBuild Custom OS Image)

## Prerequisites

### For Image Consumers
- A Fedora Atomic or Bazzite system (any variant)
- Internet connectivity for `rpm-ostree rebase` and image pulls
- `cosign` CLI (optional, for signature verification)

### For Image Developers
- Git
- A GitHub account with access to the repository
- Understanding of YAML and BlueBuild recipe schema
- Familiarity with rpm-ostree layering, Flatpak, and chezmoi

## Environment Setup

### Clone the Repository

```bash
git clone https://github.com/keithmarcusxiii/bazzite-moonlight.git
cd bazzite-moonlight
```

### Initialize the Dotfiles Subtree

The dotfiles repository at `dotfiles/` is managed as a git subtree (referenced in the chezmoi recipe [`common-dotfiles.yml`](../recipes/common-dotfiles.yml)). After cloning the main project, add the subtree the first time:

```bash
# First-time setup — registers the subtree in the host repo:
git subtree add --prefix=dotfiles https://github.com/KeithMarcusXIII/dotfiles.git main

# Subsequent updates — pull latest changes from the dotfiles remote:
git subtree pull --prefix=dotfiles https://github.com/KeithMarcusXIII/dotfiles.git main
```

`git subtree add` creates the `dotfiles/` directory and registers it as a subtree in the host repo. After that, `git subtree pull` fetches updates. Changes made inside `dotfiles/` should be committed and pushed from within that directory — the subtree maintains its own history on GitHub.

> **Note:** The `dotfiles/` directory with its own `.git` is tracked as a single merge commit in the host repo. The dotfiles repo's full history remains on GitHub and is only squashed into the host on add/pull.

### Repository Configuration

The primary build pipeline runs in GitHub Actions. However, **local builds are fully supported** via the [`bluebuild` CLI](https://blue-build.org/how-to/local/) — enabling fast iteration without waiting for CI, and working around intermittent network or daemon issues.

### Required Secrets (GitHub)

| Secret Name | Location | Purpose |
|-------------|----------|---------|
| `SIGNING_SECRET` | Repository Settings → Secrets → Actions | cosign private key for image signing |
| `github.token` | Auto-provided by GitHub Actions | Push to GHCR |

## Development Workflow

### Making Changes

1. **Edit recipes** in the [`recipes/`](../recipes/) directory
2. **Add system files** in [`files/system/`](../files/system/)
3. **Add scripts** in [`files/scripts/`](../files/scripts/)
4. **Commit and push** to trigger an automatic build
5. **Monitor** the build in the Actions tab of GitHub

> **Note:** Changes to `.md` files only will NOT trigger a build (configured in [`build.yml`](../.github/workflows/build.yml))

### Build Triggers

| Trigger | Behavior |
|---------|----------|
| **Push** (non-`.md`) | Automatic build |
| **Pull Request** | Build for validation |
| **Daily Cron** (06:00 UTC) | Scheduled rebuild |
| **workflow_dispatch** | Manual trigger via GitHub UI |

### Concurrency

Only one build runs at a time. If a new build is triggered while another is in progress, the in-progress build is cancelled. This is controlled by:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true
```

## Recipe Development

### Recipe Schema

All recipes use the BlueBuild v1 schema:
```yaml
# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json
```

### Module Types

| Module Type | File | What It Does |
|-------------|------|-------------|
| **dnf** | `common-packages.yml` | Install/remove RPM packages via rpm-ostree |
| **default-flatpaks** | `common-flatpaks.yml` | Pre-install Flatpak applications |
| **chezmoi** | `common-dotfiles.yml` | Sync dotfiles from a Git repository |
| **signing** | (built-in) | Set up signing policies for signed images |

### Adding a New Module

1. Create a new YAML file in [`recipes/`](../recipes/)
2. Add the file to the `modules` list in [`recipe.yml`](../recipes/recipe.yml):
   ```yaml
   modules:
     - from-file: common-packages.yml
     - from-file: common-flatpaks.yml
     - from-file: your-new-module.yml  # ← Add here
   ```
3. Modules are executed in order — position matters

### Package Management (DNF)

In [`common-packages.yml`](../recipes/common-packages.yml):
```yaml
type: dnf
repos:
  copr:
    enable:
      - <copr-repo-name>
install:
  packages:
    - <package-name>
remove:
  packages:
    - <package-to-remove>
```

Currently configured:
- **Repos enabled:** `jdxcode/mise` (COPR)
- **Installed:** `stow`, `papirus-icon-theme`, `mise`
- **Removed:** `hhd`, `hhd-ui`

### Flatpak Management

In [`common-flatpaks.yml`](../recipes/common-flatpaks.yml):
```yaml
type: default-flatpaks
configurations:
  - notify: false
    scope: system
    install:
      - io.github.celluloid_player.Celluloid
```

- **`scope: system`** — Available to all users, cannot be removed by users
- **`notify: false`** — Suppress desktop notification after install
- **`scope: user`** — Per-user Flatpaks (currently empty)

### Dotfile Management (chezmoi)

In [`common-dotfiles.yml`](../recipes/common-dotfiles.yml):
```yaml
type: chezmoi
repository: "https://github.com/KeithMarcusXIII/dotfiles.git"
all-users: true
file-conflict-policy: replace
```

- **`all-users: true`** — Enables `chezmoi-init.service` and `chezmoi-update.timer` for all users
- **`file-conflict-policy: replace`** — Overwrites existing files with dotfile versions

### GNOME Extensions

In [`gnome-extensions.yml`](../recipes/gnome-extensions.yml):
- Currently empty — add GNOME Shell extension IDs here

## Custom Modules

The [`modules/`](../modules/) directory holds custom BlueBuild module definitions. Add custom modules here when the built-in types (dnf, flatpak, chezmoi, etc.) don't cover your needs.

## Testing

### CI-Based Testing (GitHub Actions)

The standard path for validating changes — push to a branch and let CI handle the build:

1. Push changes to a branch
2. Wait for the PR build to complete
3. Test the built image by rebasing a test system:
   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/keithmarcusxiii/bazzite-moonlight:pr-<PR_NUMBER>
   systemctl reboot
   ```

PR builds are automatically published to GHCR with a `pr-<number>` tag for testing before merge.

### Local Build & Test (bluebuild CLI)

The [`bluebuild` CLI](https://blue-build.org/how-to/local/) enables building images entirely on your local machine — bypassing GitHub Actions, slow network pulls, and transient `rpm-ostree`/`podman` issues. This is the **preferred workflow** during rapid iteration or when GitHub Actions builds are stalled.

#### Prerequisites

| Requirement | Notes |
|-------------|-------|
| `bluebuild` CLI | Install from [blue-build.org](https://blue-build.org/how-to/local/) |
| `podman` | Required by bluebuild for local image builds |
| Local Bazzite VM | Proxmox VM at `192.168.30.171` / `bazzite.local.keithmarcus.com` |

#### Step-by-Step: Build Locally

1. **Build the image** from the recipe:

   ```bash
   cd bazzite-moonlight
   bluebuild build recipes/recipe.yml
   ```

   This produces a local container image tagged `bazzite-moonlight:latest` in the local container storage.

2. **Verify the image exists locally:**

   ```bash
   podman images localhost/bazzite-moonlight
   ```

#### Step-by-Step: Deploy to the Test VM

The test VM (`192.168.30.171` / `bazzite.local.keithmarcus.com`) is an existing Proxmox VM with a Bazzite installation. Two deployment strategies are available.

##### Strategy A: Push to local registry then rebase (recommended)

This approach pushes the locally-built image to an on-VM container registry, then rebases the VM's OS to it.

1. **Transfer the image** to the test VM via `podman` over SSH:

   ```bash
   # Save the image locally
   podman save localhost/bazzite-moonlight:latest | \
     ssh bazzite.local.keithmarcus.com podman load
   ```

2. **On the test VM**, rebase to the local image:

   ```bash
   # Check current status
   brh status
   # Expected output:
   #   Active: ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
   #   (or similar local reference)

   rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
   systemctl reboot
   ```

   > **Tip:** Use `brh` (a bazzite helper) to quickly check the current deployment and available images.

##### Strategy B: Manual podman pull + rebase (network workaround)

When network conditions are poor, or `bluebuild` / `rpm-ostree` exhibit bugs that cause image layer pulls to hang, bypass the automated pull by building and loading the image manually with `podman`.

1. **Build** with bluebuild as above (or use `podman build` directly if you have the Containerfile).

2. **On the test VM**, manually pull the base layers (if needed) and load the custom image:

   ```bash
   # Pull the base image separately (retry-friendly)
   podman pull ghcr.io/ublue-os/bazzite-dx-gnome:stable

   # Load the locally-built overlay
   podman load < bazzite-moonlight.tar
   ```

3. **Rebase** to the local image:

   ```bash
   rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
   systemctl reboot
   ```

   This approach separates the base-image pull (which can be retried independently) from the rebase, avoiding the common hang where `rpm-ostree` gets stuck mid-pull.

#### Troubleshooting Network & Daemon Issues

| Symptom | Likely Cause | Workaround |
|---------|-------------|------------|
| `rpm-ostree rebase` hangs during layer pull | Network congestion / registry throttling | Use **Strategy B**: `podman pull` the base image first, then rebase to `containers-storage:` |
| `bluebuild build` fails on image pull | Transient podman/registry issue | Retry with `podman pull` for the base image independently, then re-run `bluebuild build` |
| Image layers repeatedly stuck | `rpm-ostree` or `podman` bug (UNCONFIRMED) | Clear local storage: `podman system prune -a`, then rebuild from scratch |
| Cannot reach `bazzite.local.keithmarcus.com` | DNS / mDNS failure | Use IP directly: `ssh 192.168.30.171` |

### Signature Verification

Verify the image signature (CI-built images only — local builds are unsigned):

```bash
cosign verify --key cosign.pub ghcr.io/keithmarcusxiii/bazzite-moonlight
```

## Common Tasks

### Update Base Image Version

Edit the `image-version` field in [`recipe.yml`](../recipes/recipe.yml):
```yaml
image-version: stable  # or latest, or a specific tag
```

### Add a New Recipe to the Build Matrix

If you create additional recipe files, add them to the build matrix in [`build.yml`](../.github/workflows/build.yml):
```yaml
strategy:
  matrix:
    recipe:
      - recipe.yml
      - your-new-recipe.yml  # ← Add here
```

### Change Build Schedule

Edit the cron expression in [`build.yml`](../.github/workflows/build.yml):
```yaml
on:
  schedule:
    - cron: "00 06 * * *"  # Currently: daily at 06:00 UTC
```

---

_Generated using BMAD Method `document-project` workflow_
