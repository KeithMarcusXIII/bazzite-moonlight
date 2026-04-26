# bazzite-moonlight — Source Tree Analysis

**Generated:** 2026-04-26
**Scan Level:** Quick (pattern-based)

## Complete Directory Structure

```
bazzite-moonlight/                          # Project root
│
├── .agents/                                # BMAD Agent Skills (AI-assisted development)
│   └── skills/                             # Installed BMAD skill definitions
│       ├── bmad-agent-architect/           # Winston — System Architect
│       ├── bmad-agent-dev/                 # Amelia — Developer Agent
│       ├── bmad-agent-analyst/             # Mary — Business Analyst
│       ├── bmad-agent-pm/                  # John — Product Manager
│       ├── bmad-agent-tech-writer/         # Paige — Tech Writer
│       ├── bmad-agent-ux-designer/         # Sally — UX Designer
│       └── ... (workflow skills)           # PRD, Architecture, Epics, etc.
│
├── .github/                                # GitHub Configuration & CI/CD
│   ├── CODEOWNERS                          # Repository owners: @xynydev, @fiftydinar
│   ├── dependabot.yml                      # Auto-update GitHub Actions daily
│   └── workflows/
│       └── build.yml                       # ⭐ ENTRY POINT — BlueBuild image build pipeline
│
├── docs/                                   # Generated Project Documentation (this folder)
│   ├── index.md                            # Master documentation index
│   ├── project-overview.md                 # Executive summary & tech stack
│   ├── architecture.md                     # Technical architecture details
│   ├── source-tree-analysis.md             # ← This file
│   ├── development-guide.md                # Local development workflow
│   └── deployment-guide.md                 # CI/CD and deployment process
│
├── files/                                  # System Files Overlay (merged into OS image)
│   ├── scripts/
│   │   └── example.sh                      # Example shell script
│   └── system/
│       ├── etc/                            # /etc overlay — system configuration files
│       │   └── .gitkeep
│       └── usr/                            # /usr overlay — user binaries & libraries
│           └── .gitkeep
│
├── modules/                                # Custom BlueBuild Modules
│   └── .gitkeep                            # Placeholder; add custom modules here
│
├── recipes/                                # ⭐ BlueBuild Recipe Definitions
│   ├── recipe.yml                          # 🔑 MAIN ENTRY POINT — defines base image + module order
│   ├── common-packages.yml                 # DNF package layer (rpm-ostree installs/removals)
│   ├── common-flatpaks.yml                 # Flatpak application layer (Flathub installs)
│   ├── common-dotfiles.yml                 # Dotfile layer (chezmoi sync from Git repo)
│   └── gnome-extensions.yml               # GNOME Shell extensions definition
│
├── .venv/                                  # Python Virtual Environment (local dev, gitignored)
├── .gitignore                              # Git ignore rules
├── cosign.pub                              # 🔐 Sigstore public key for image verification
├── LICENSE                                 # Project license
└── README.md                               # Project README with installation instructions
```

## Critical Directories

### `recipes/` — 🔑 The Heart of the Project
All BlueBuild recipe YAML files live here. [`recipe.yml`](../recipes/recipe.yml) is the single entry point that:
1. Declares the base image (`ghcr.io/ublue-os/bazzite-dx-gnome:stable`)
2. Loads supporting modules in order: packages → flatpaks → dotfiles → signing

Each `*-packages.yml`, `*-flatpaks.yml`, and `*-dotfiles.yml` file defines a layer that gets composed into the final OCI image.

### `.github/workflows/` — CI/CD Pipeline
[`build.yml`](../.github/workflows/build.yml) orchestrates:
- **Trigger:** Daily cron (06:00 UTC), push (excluding `.md` changes), PR, manual dispatch
- **Concurrency:** Only one build at a time (grouped by workflow + ref)
- **Strategy:** Matrix of recipe files (currently just `recipe.yml`)
- **Action:** `blue-build/github-action@v1.11` handles the build, cosign signing, and registry push

### `files/system/` — OS Customization Overlay
Files placed here are merged into the target OS image:
- `etc/` → Merged into `/etc` (system configuration)
- `usr/` → Merged into `/usr` (user binaries, libraries, shared data)

### `files/scripts/` — Utility Scripts
Custom shell scripts included in the image. [`example.sh`](../files/scripts/example.sh) is a placeholder.

### `modules/` — Custom BlueBuild Modules
Extensibility point for custom BlueBuild module definitions. Currently empty (`.gitkeep`).

## Entry Points

| Entry Point | Type | File |
|-------------|------|------|
| **Image Build** | CI/CD trigger | [`.github/workflows/build.yml`](../.github/workflows/build.yml) |
| **Recipe Composition** | Build configuration | [`recipes/recipe.yml`](../recipes/recipe.yml) |
| **Image Installation** | Consumer endpoint | `rpm-ostree rebase ostree-image-signed:docker://ghcr.io/keithmarcusxiii/bazzite-moonlight:latest` |
| **Signature Verification** | Consumer verification | `cosign verify --key cosign.pub ghcr.io/keithmarcusxiii/bazzite-moonlight` |
