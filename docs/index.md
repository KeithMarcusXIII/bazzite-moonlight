# bazzite-moonlight Documentation Index

**Type:** Monolith
**Primary Language:** YAML (BlueBuild recipes), Shell
**Architecture:** Infrastructure-as-Code — Layered OCI Image Composition
**Last Updated:** 2026-04-26

## Project Overview

`bazzite-moonlight` is a custom [Bazzite](https://bazzite.gg/) OS image tailored for Moonlight game-streaming clients. Built with [BlueBuild](https://blue-build.org/) on top of `ghcr.io/ublue-os/bazzite-dx-gnome:stable`, it layers packages, Flatpaks, dotfiles, and GNOME extensions into a signed, immutable OCI container image distributed via GitHub Container Registry (`ghcr.io/keithmarcusxiii/bazzite-moonlight`).

## Quick Reference

- **Tech Stack:** BlueBuild (YAML), DNF/rpm-ostree, Flatpak/Flathub, chezmoi, Cosign/Sigstore, GitHub Actions
- **Entry Point:** [`recipes/recipe.yml`](../recipes/recipe.yml) — main recipe declaration
- **Architecture Pattern:** Pipeline/Composition — layered recipe execution producing an OCI image
- **Deployment:** `rpm-ostree rebase ostree-image-signed:docker://ghcr.io/keithmarcusxiii/bazzite-moonlight:latest`
- **Registry:** `ghcr.io/keithmarcusxiii/bazzite-moonlight`

## Generated Documentation

### Core Documentation

- [Project Overview](./project-overview.md) — Executive summary, tech stack, and high-level architecture
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory structure with critical folders
- [Architecture](./architecture.md) — Detailed technical architecture and design decisions
- [Development Guide](./development-guide.md) — Local setup, recipe development, and common tasks
- [Deployment Guide](./deployment-guide.md) — CI/CD pipeline, build process, and consumer installation

### Optional Documentation

Documents not applicable to this infrastructure-as-code project:
- ~~API Contracts~~ — N/A (no API endpoints)
- ~~Data Models~~ — N/A (no database or data models)
- ~~Component Inventory~~ — N/A (infra project type; no UI components)
- ~~Integration Architecture~~ — N/A (single-part monolith)
- ~~Contribution Guide~~ — _(To be generated)_

## Existing Documentation

- [README.md](../README.md) — Project introduction, installation instructions, and signature verification
- [CODEOWNERS](../.github/CODEOWNERS) — Repository ownership (@xynydev, @fiftydinar)
- [LICENSE](../LICENSE) — Project license

## Getting Started

### For Consumers

```bash
# Install on Fedora Atomic / Bazzite
rpm-ostree rebase ostree-unverified-registry:ghcr.io/keithmarcusxiii/bazzite-moonlight:latest
systemctl reboot
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/keithmarcusxiii/bazzite-moonlight:latest
systemctl reboot
```

### For Developers

```bash
git clone https://github.com/keithmarcusxiii/bazzite-moonlight.git
cd bazzite-moonlight
# Edit recipes/ files, push to trigger automatic build
```

### Verify Image

```bash
cosign verify --key cosign.pub ghcr.io/keithmarcusxiii/bazzite-moonlight
```

---

_Generated using BMAD Method `document-project` workflow_
