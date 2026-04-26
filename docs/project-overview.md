# bazzite-moonlight — Project Overview

**Date:** 2026-04-26
**Type:** Infrastructure-as-Code (Custom OS Image)
**Architecture:** Recipe-based OCI Image Composition

## Executive Summary

`bazzite-moonlight` is a custom [Bazzite](https://bazzite.gg/) OS image tailored for Moonlight game-streaming clients. Built on top of `ghcr.io/ublue-os/bazzite-dx-gnome:stable` using the [BlueBuild](https://blue-build.org/) framework, it layers additional packages (via DNF/rpm-ostree), Flatpaks, dotfiles (via chezmoi), and GNOME extensions into a signed, versioned OCI container image published to GitHub Container Registry (`ghcr.io/keithmarcusxiii/bazzite-moonlight`).

The image is built daily via GitHub Actions, signed with Sigstore/cosign, and deployed to Fedora Atomic systems via `rpm-ostree rebase`.

## Project Classification

- **Repository Type:** Monolith — single cohesive project
- **Project Type(s):** Infra (Infrastructure-as-Code)
- **Primary Language(s):** YAML (BlueBuild recipes), Shell (system scripts)
- **Architecture Pattern:** Pipeline/Composition — layered recipe execution producing an OCI image

## Technology Stack Summary

| Category | Technology | Version | Justification |
|----------|-----------|---------|---------------|
| **Image Framework** | BlueBuild | v1 (schema) | Declarative OS image composition |
| **Base OS** | Bazzite DX GNOME | stable | Gaming-focused Fedora Atomic with GNOME desktop |
| **Package Manager** | DNF (rpm-ostree) | — | RPM package layering in immutable OS |
| **Flatpak Runtime** | Flathub | — | Sandboxed desktop application delivery |
| **Dotfile Manager** | chezmoi | — | Declarative user-configuration management |
| **CI/CD** | GitHub Actions | blue-build/github-action@v1.11 | Automated daily builds with matrix strategy |
| **Image Signing** | Sigstore cosign | — | Cryptographic image verification |
| **Container Registry** | GitHub Container Registry | ghcr.io | OCI image hosting and distribution |
| **GNOME Extensions** | GNOME Shell Extensions | — | Desktop UX customization |

## Key Features

- **Immutable OS base** — Bazzite DX GNOME provides a gaming-optimized, atomic Fedora foundation
- **Pre-configured Moonlight client** — Turn-key game-streaming client OS
- **Signed images** — Cosign/Sigstore signing for authenticity verification
- **Automated daily builds** — GitHub Actions CI/CD with cron scheduling at 06:00 UTC
- **Declarative configuration** — All customization defined in YAML recipes; fully reproducible
- **Dotfile automation** — chezmoi integration syncs user dotfiles from a Git repository
- **Flatpak application bundle** — Pre-installed system Flatpaks (Celluloid, PDF Arranger, LibreOffice, Android Studio, GDM Settings)

## Architecture Highlights

1. **Layered Recipe Pipeline:** [`recipe.yml`](../recipes/recipe.yml) is the single entry point that orchestrates module loading: packages → flatpaks → dotfiles → signing
2. **OCI-Native Delivery:** Output is a standard OCI container image published to `ghcr.io`, consumed by Fedora Atomic's `rpm-ostree rebase`
3. **Immutable + Overlay:** Base OS is immutable (read-only `/usr`); customizations are layered via rpm-ostree package overlays and Flatpak installs
4. **Trust Chain:** Images are signed at build time with a private cosign key; consumers verify against the public key in [`cosign.pub`](../cosign.pub)

## Development Overview

### Prerequisites

- A Fedora Atomic or Bazzite system (or a BlueBuild-compatible build environment)
- GitHub repository with BlueBuild GitHub Action configured
- cosign key pair for image signing (private key stored in GitHub Secrets as `SIGNING_SECRET`)

### Getting Started

To rebase an existing Fedora Atomic installation:
1. Rebase to the unsigned image (installs signing keys): `rpm-ostree rebase ostree-unverified-registry:ghcr.io/keithmarcusxiii/bazzite-moonlight:latest`
2. Reboot: `systemctl reboot`
3. Rebase to the signed image: `rpm-ostree rebase ostree-image-signed:docker://ghcr.io/keithmarcusxiii/bazzite-moonlight:latest`
4. Reboot again to complete

### Key Commands

- **Build:** Triggered via `workflow_dispatch` in GitHub Actions, or automatically on push (excluding `.md` changes) and daily at 06:00 UTC
- **Verify signature:** `cosign verify --key cosign.pub ghcr.io/keithmarcusxiii/bazzite-moonlight`
- **Generate ISO:** Follow [BlueBuild ISO generation guide](https://blue-build.org/how-to/generate-iso/)

## Repository Structure

```
bazzite-moonlight/
├── .github/workflows/build.yml   # CI/CD pipeline (daily + on push)
├── .github/CODEOWNERS             # Repository ownership
├── .github/dependabot.yml         # Auto-update GitHub Actions
├── recipes/
│   ├── recipe.yml                 # Main entry point; defines base image + module order
│   ├── common-packages.yml        # DNF package installs/removals
│   ├── common-flatpaks.yml        # Flatpak application installs
│   ├── common-dotfiles.yml        # chezmoi dotfile sync
│   └── gnome-extensions.yml       # GNOME Shell extension definitions
├── files/
│   ├── scripts/                   # Custom shell scripts for the image
│   └── system/
│       ├── etc/                    # /etc overlay files
│       └── usr/                    # /usr overlay files
├── modules/                       # Custom BlueBuild modules
├── cosign.pub                     # Sigstore public key for verification
├── LICENSE
└── README.md
```

## Documentation Map

For detailed information, see:

- [index.md](./index.md) — Master documentation index
- [architecture.md](./architecture.md) — Detailed technical architecture
- [source-tree-analysis.md](./source-tree-analysis.md) — Annotated directory structure
- [development-guide.md](./development-guide.md) — Development workflow and local setup
- [deployment-guide.md](./deployment-guide.md) — CI/CD pipeline and deployment process

---

_Generated using BMAD Method `document-project` workflow_
