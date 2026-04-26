# bazzite-moonlight — Architecture

**Date:** 2026-04-26
**Architecture Type:** Pipeline/Composition (Infrastructure-as-Code)
**Primary Pattern:** Layered OCI Image Composition via BlueBuild

## Executive Summary

`bazzite-moonlight` follows a **declarative composition architecture** where a base OS image is progressively layered with packages, Flatpaks, dotfiles, and customizations to produce a signed, immutable OCI container image. The architecture is entirely recipe-driven — no imperative build scripts, no runtime orchestration. All configuration is expressed as YAML and processed by the BlueBuild framework.

## Architecture Pattern

### Layered Image Composition

```
┌──────────────────────────────────────────────────┐
│                  SIGNED OCI IMAGE                │
│  ghcr.io/keithmarcusxiii/bazzite-moonlight:latest│
├──────────────────────────────────────────────────┤
│  Layer 4: Signing                                │
│  ┌────────────────────────────────────────────┐  │
│  │  cosign sign (private key)                  │  │
│  │  Policy injection for automatic updates     │  │
│  └────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────┤
│  Layer 3: Dotfiles (chezmoi)                     │
│  ┌────────────────────────────────────────────┐  │
│  │  Clone git repo → Apply dotfiles           │  │
│  │  Enable chezmoi-init.service               │  │
│  │  Enable chezmoi-update.timer               │  │
│  └────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────┤
│  Layer 2: Flatpaks (default-flatpaks)            │
│  ┌────────────────────────────────────────────┐  │
│  │  System: Celluloid, PDF Arranger,           │  │
│  │          LibreOffice, Android Studio,       │  │
│  │          GDM Settings                       │  │
│  │  Scope: system (all users)                  │  │
│  └────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────┤
│  Layer 1: RPM Packages (dnf)                     │
│  ┌────────────────────────────────────────────┐  │
│  │  Repos: jdxcode/mise (COPR)                │  │
│  │  Install: stow, papirus-icon-theme, mise   │  │
│  │  Remove: hhd, hhd-ui                       │  │
│  └────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────┤
│  Layer 0: Base Image                             │
│  ┌────────────────────────────────────────────┐  │
│  │  ghcr.io/ublue-os/bazzite-dx-gnome:stable  │  │
│  │  Gaming-optimized Fedora Atomic + GNOME    │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### Module Execution Order

The [`recipe.yml`](../recipes/recipe.yml) defines modules in strict execution order:

1. **`common-packages.yml`** — DNF operations (install stow, papirus-icon-theme, mise; remove hhd, hhd-ui). Adds `jdxcode/mise` COPR repository.
2. **`common-flatpaks.yml`** — Flatpak configuration (system-scope installs via Flathub with notification disabled).
3. **`common-dotfiles.yml`** — chezmoi integration (clone dotfiles from `github.com/KeithMarcusXIII/dotfiles.git`, apply to all users, replace on conflict).
4. **`signing`** — Built-in BlueBuild module that injects cosign signing policy and registry verification keys for automatic updates.

## Data Architecture

This project has no traditional database or data models. Configuration "data" flows as:

- **Input:** YAML recipe files define desired state
- **Processing:** BlueBuild GitHub Action interprets recipes into `Containerfile` instructions
- **Output:** Signed OCI image with layered customizations
- **State:** Image tags on GHCR (`latest`, version tags); user systems track deployed image via rpm-ostree

## Component Overview

### Recipe System

| Component | File | Type | Purpose |
|-----------|------|------|---------|
| **Main Recipe** | [`recipe.yml`](../recipes/recipe.yml) | Entry Point | Declares base image, orchestrates modules |
| **Package Layer** | [`common-packages.yml`](../recipes/common-packages.yml) | Module (dnf) | RPM package management via rpm-ostree |
| **Flatpak Layer** | [`common-flatpaks.yml`](../recipes/common-flatpaks.yml) | Module (default-flatpaks) | System Flatpak application provisioning |
| **Dotfile Layer** | [`common-dotfiles.yml`](../recipes/common-dotfiles.yml) | Module (chezmoi) | User configuration synchronization |
| **GNOME Extensions** | [`gnome-extensions.yml`](../recipes/gnome-extensions.yml) | Module | GNOME Shell extension definitions |
| **Signing** | (built-in) | Module (signing) | Cosign signing + policy setup |

### CI/CD Pipeline

| Component | Location | Purpose |
|-----------|----------|---------|
| **Build Workflow** | [`.github/workflows/build.yml`](../.github/workflows/build.yml) | Triggers image build via `blue-build/github-action@v1.11` |
| **Dependabot** | [`.github/dependabot.yml`](../.github/dependabot.yml) | Auto-updates GitHub Actions daily |
| **Code Owners** | [`.github/CODEOWNERS`](../.github/CODEOWNERS) | @xynydev, @fiftydinar |

### System Overlay

| Component | Location | Purpose |
|-----------|----------|---------|
| **Scripts** | [`files/scripts/`](../files/scripts/) | Custom shell scripts added to image |
| **/etc Overlay** | [`files/system/etc/`](../files/system/etc/) | System configuration files |
| **/usr Overlay** | [`files/system/usr/`](../files/system/usr/) | User binaries/libraries |

## Deployment Architecture

### Build Pipeline Flow

```
Git Push / Cron / Manual Dispatch
         │
         ▼
┌─────────────────────────────────┐
│   GitHub Actions (ubuntu-latest) │
│   blue-build/github-action@v1.11 │
├─────────────────────────────────┤
│  1. Parse recipe.yml             │
│  2. Pull base image              │
│  3. Apply DNF layer              │
│  4. Apply Flatpak layer          │
│  5. Apply dotfile layer          │
│  6. Apply signing layer          │
│  7. Build OCI image              │
│  8. Sign with cosign             │
│  9. Push to ghcr.io              │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  GitHub Container Registry       │
│  ghcr.io/keithmarcusxiii/        │
│  bazzite-moonlight:latest        │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Consumer Systems                │
│  rpm-ostree rebase → reboot      │
└─────────────────────────────────┘
```

### Trust Model

1. **Build Phase:** Image is built and signed with a private cosign key stored in GitHub Secrets (`SIGNING_SECRET`)
2. **Distribution Phase:** Signed image published to `ghcr.io` with attached Sigstore signature
3. **Verification Phase:** Consumers verify with `cosign verify --key cosign.pub ghcr.io/keithmarcusxiii/bazzite-moonlight`

## Development Workflow

### Making Changes

1. Edit the relevant recipe YAML file(s) in [`recipes/`](../recipes/)
2. Commit and push to the repository
3. GitHub Actions automatically triggers a build (unless only `.md` files changed)
4. Monitor build status via the Actions tab
5. Once built, consumers rebase to the new `latest` tag

### Adding Packages

Add entries to [`common-packages.yml`](../recipes/common-packages.yml):
```yaml
type: dnf
repos:
  copr:
    enable:
      - <copr-repo>
install:
  packages:
    - <package-name>
remove:
  packages:
    - <package-to-remove>
```

### Adding Flatpaks

Add entries to [`common-flatpaks.yml`](../recipes/common-flatpaks.yml):
```yaml
type: default-flatpaks
configurations:
  - scope: system
    install:
      - <flatpak-id>
```

### Adding System Files

Place files in [`files/system/`](../files/system/):
- `etc/` → system configuration (`/etc`)
- `usr/` → binaries and libraries (`/usr`)

### Adding Custom Scripts

Place scripts in [`files/scripts/`](../files/scripts/) — they become available in the image's `$PATH`.

## Testing Strategy

- **Build Verification:** Every push and PR triggers a build; failures are visible in GitHub Actions
- **Signature Verification:** `cosign verify --key cosign.pub ghcr.io/keithmarcusxiii/bazzite-moonlight` validates image authenticity
- **Integration Testing:** Rebase a test system to the unsigned image, reboot, rebase to the signed image, reboot, verify functionality
- **ISO Testing:** Generate an offline ISO for bare-metal testing (see [BlueBuild ISO guide](https://blue-build.org/how-to/generate-iso/))

---

_Generated using BMAD Method `document-project` workflow_
