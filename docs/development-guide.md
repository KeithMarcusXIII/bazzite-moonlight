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
| `podman` or `docker` | Required for local image builds and pushing |
| Local Bazzite VM | Proxmox VM at `192.168.30.171` / `bazzite.local.keithmarcus.com` |
| Cross-arch emulation | Build host is `arm64` (Apple Silicon); target is `x86_64`. Requires `--platform linux/amd64` on all build commands (see below) |

#### Step-by-Step: Build Locally

1. **Build the image** from the recipe, targeting `x86_64`:

   ```bash
   cd bazzite-moonlight
   bluebuild build recipes/recipe.yml --platform linux/amd64
   ```

   If `bluebuild` does not support `--platform`, use the environment variable instead:
   ```bash
   DOCKER_DEFAULT_PLATFORM=linux/amd64 bluebuild build recipes/recipe.yml
   ```

   This produces a local container image tagged `bazzite-moonlight:latest` in the local container storage.

2. **Verify the image exists locally and check its architecture:**

   ```bash
   podman images localhost/bazzite-moonlight

   # Confirm the image is amd64, not arm64
   podman inspect localhost/bazzite-moonlight:latest --format '{{.Architecture}}'
   # Must output: amd64
   ```

#### Step-by-Step: Deploy to the Test VM

The test VM (`192.168.30.171` / `bazzite.local.keithmarcus.com`) is an existing Proxmox VM with a Bazzite installation. Three deployment strategies are available, listed from lowest to highest latency.

```mermaid
flowchart LR
    subgraph Mac["MacBook Pro Mac15,3 - arm64"]
        BB["bluebuild CLI"]
        ARCH["--platform linux/amd64"]
        BB -->|builds| ARCH
    end

    subgraph Registry["Existing LAN Registry"]
        REG["registry.home.keithmarcus.com"]
        IP["192.168.20.7:80"]
    end

    subgraph VM["Bazzite VM 192.168.30.171 - x86_64"]
        PULL["podman pull from registry"]
        REBASE["rpm-ostree rebase"]
        PULL --> REBASE
    end

    ARCH -->|podman push x86_64 image| REG
    REG -->|podman pull| PULL
```

##### Strategy C: Push to existing LAN registry — lowest latency, recommended

This strategy leverages the existing container registry at `registry.home.keithmarcus.com` (reverse-proxied by Caddy, upstream at `192.168.20.7:80`). The Mac pushes the locally-built image to it, and the Bazzite VM pulls directly over the LAN. No image data touches the internet, layers are cached, and incremental rebuilds transfer only changed layers.

> **⚠️ Architecture mismatch:** The build host (`arm64` Apple Silicon) and deployment target (`x86_64`) differ. Without specifying `--platform linux/amd64`, `bluebuild` produces an `arm64` image that the Bazzite VM cannot run — resulting in:
> ```
> WARNING: image platform (linux/arm64) does not match the expected platform (linux/amd64)
> ```
> All build and push commands below include `--platform linux/amd64` to force cross-architecture compilation. Docker Desktop on Apple Silicon supports this via Rosetta emulation; `podman` uses `qemu-user-static`. Verify emulation is available with `podman run --rm --platform linux/amd64 alpine uname -m` (should output `x86_64`).

###### Push Target

You have two ways to address the registry:

| Endpoint | Type | Notes |
|----------|------|-------|
| `registry.home.keithmarcus.com` | Hostname with TLS | Caddy reverse-proxy with auto TLS. Preferred — works with default podman settings. Verify TLS: `curl -v https://registry.home.keithmarcus.com/v2/` — a valid response confirms TLS is operational. |
| `192.168.20.7:80` | Raw LAN IP | Plain HTTP. Requires configuring the destination as an insecure registry or using `--tls-verify=false` with appropriate registries.conf entry. |

###### Build and Push to Registry

The image reference must include the registry address — `localhost/name:tag` doesn't tell `podman` or `docker` where to push. Two approaches:

**Option A: Tag then push** (explicit, two commands)

```bash
# 1. Build the image for x86_64 target
cd bazzite-moonlight
bluebuild build recipes/recipe.yml --platform linux/amd64

# 2. Verify the image architecture
podman inspect localhost/bazzite-moonlight:latest --format '{{.Architecture}}'
# Must output: amd64

# 3. Tag with registry prefix and push
podman tag localhost/bazzite-moonlight:latest \
  registry.home.keithmarcus.com/bazzite-moonlight:latest
podman push registry.home.keithmarcus.com/bazzite-moonlight:latest

# OR via LAN IP
podman tag localhost/bazzite-moonlight:latest \
  192.168.20.7:80/bazzite-moonlight:latest
podman push --tls-verify=false 192.168.20.7:80/bazzite-moonlight:latest
```

**Option B: Push with destination URI** (single command, podman only)

```bash
podman push localhost/bazzite-moonlight:latest \
  docker://registry.home.keithmarcus.com/bazzite-moonlight:latest

# OR via LAN IP
podman push localhost/bazzite-moonlight:latest \
  docker://192.168.20.7:80/bazzite-moonlight:latest
```

> **🔧 Platform flag alternatives:** If `bluebuild build --platform` is not supported:
> ```bash
> # Force via environment variable
> DOCKER_DEFAULT_PLATFORM=linux/amd64 bluebuild build recipes/recipe.yml
> ```
> Or build directly with `podman build` after `bluebuild` generates the Containerfile:
> ```bash
> podman build --platform linux/amd64 -t localhost/bazzite-moonlight:latest .
> ```

> **Docker Desktop variant:** If using `docker` instead of `podman` on the Mac, the `--tls-verify=false` flag is not available and the `docker://` URI isn't needed. Docker Desktop on Apple Silicon emulates x86_64 via Rosetta — ensure "Use Rosetta for x86/amd64 emulation on Apple Silicon" is enabled in Docker Desktop → Settings → General.
> ```bash
> # Build for x86_64
> docker build --platform linux/amd64 -t localhost/bazzite-moonlight:latest .
>
> # Tag and push
> docker tag localhost/bazzite-moonlight:latest \
>   registry.home.keithmarcus.com/bazzite-moonlight:latest
> docker push registry.home.keithmarcus.com/bazzite-moonlight:latest
>
> # OR via LAN IP — requires daemon.json config first (see below)
> docker tag localhost/bazzite-moonlight:latest \
>   192.168.20.7:80/bazzite-moonlight:latest
> docker push 192.168.20.7:80/bazzite-moonlight:latest
> ```
>
> **Docker Desktop insecure registry config:** To push to the LAN IP over HTTP, add it to Docker Engine config:
> 1. Open Docker Desktop → Settings → Docker Engine
> 2. Add to the JSON:
>    ```json
>    {
>      "insecure-registries": ["192.168.20.7:80"]
>    }
>    ```
> 3. Click **Apply & Restart**
>
> The hostname endpoint (`registry.home.keithmarcus.com`) works without this step because Caddy provides TLS.

> **Container networking note:** If `bluebuild` runs inside a docker-compose container, the built image may reside in the container's storage. Export it to the host first. **Ensure `--platform linux/amd64` is passed during the build inside the container** so the exported image targets the correct architecture:
> ```bash
> # Using podman on the host
> docker-compose -p local -f /Users/digitsolu/local/compose.yaml \
>   exec -w /bluebuild/bazzite-moonlight bluebuild \
>   podman save localhost/bazzite-moonlight:latest | \
>   podman load
> podman tag localhost/bazzite-moonlight:latest registry.home.keithmarcus.com/bazzite-moonlight:latest
> podman push registry.home.keithmarcus.com/bazzite-moonlight:latest
>
> # Using docker on the host — replace podman with docker
> docker-compose -p local -f /Users/digitsolu/local/compose.yaml \
>   exec -w /bluebuild/bazzite-moonlight bluebuild \
>   docker save localhost/bazzite-moonlight:latest | \
>   docker load
> docker tag localhost/bazzite-moonlight:latest registry.home.keithmarcus.com/bazzite-moonlight:latest
> docker push registry.home.keithmarcus.com/bazzite-moonlight:latest
> ```

###### Pull and Rebase on the Destination

On the Bazzite VM, pull from the LAN registry and rebase:

```bash
# Pull via hostname (TLS via Caddy)
podman pull registry.home.keithmarcus.com/bazzite-moonlight:latest

# Verify the pulled image is x86_64 before rebasing
podman inspect registry.home.keithmarcus.com/bazzite-moonlight:latest \
  --format '{{.Architecture}}'
# Must output: amd64

# OR pull via LAN IP and verify
podman pull --tls-verify=false 192.168.20.7:80/bazzite-moonlight:latest
podman inspect 192.168.20.7:80/bazzite-moonlight:latest \
  --format '{{.Architecture}}'

# Then rebase to the locally-pulled image
rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
systemctl reboot
```

###### Incremental Rebuilds

On subsequent changes, only modified layers transfer:

```bash
# Rebuild and push on Mac — always include --platform
bluebuild build recipes/recipe.yml --platform linux/amd64
podman tag localhost/bazzite-moonlight:latest registry.home.keithmarcus.com/bazzite-moonlight:latest
podman push registry.home.keithmarcus.com/bazzite-moonlight:latest

# On Bazzite VM — pulls only changed layers
podman pull registry.home.keithmarcus.com/bazzite-moonlight:latest
rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
systemctl reboot
```

> **Why this is fastest:** The registry is OCI-native — layer hashes are compared before transfer. Only layers that actually changed (e.g., a new RPM package) cross the LAN. The base image layers from `ghcr.io/ublue-os/bazzite-dx-gnome:stable` are also cached in the registry after the first push, so they never re-transfer to the VM either.

##### Strategy A: Tarball transfer via SSH

This approach serializes the full image to a tarball and pipes it over SSH. Useful as a fallback when a registry isn't available.

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
| `rpm-ostree rebase` hangs during layer pull | Network congestion / registry throttling | Use **Strategy B**: `podman pull` base image first, then rebase to `containers-storage:` |
| `bluebuild build` fails on image pull | Transient podman/registry issue | Retry with `podman pull` for the base image independently, then re-run `bluebuild build` |
| Image layers repeatedly stuck | `rpm-ostree` or `podman` bug (UNCONFIRMED) | Clear local storage: `podman system prune -a`, then rebuild from scratch |
| Cannot reach `bazzite.local.keithmarcus.com` | DNS / mDNS failure | Use IP directly: `ssh 192.168.30.171` |
| `podman push registry.home.keithmarcus.com/...` fails with `x509` cert error | Caddy TLS certificate issue | If using Let's Encrypt staging or self-signed cert, add `--tls-verify=false` to push/pull commands. For production LE certs, no flag needed. |
| `podman push 192.168.20.7:80/...` fails with `pinging container registry` error | Podman refuses HTTP registries by default | Add `192.168.20.7:80` as an insecure registry: `sudo sh -c 'echo "unqualified-search-registries = [\"docker.io\"]" > /etc/containers/registries.conf.d/local.conf && echo "[[registry]]\nlocation=\"192.168.20.7:80\"\ninsecure=true" >> /etc/containers/registries.conf.d/local.conf'`. Or use the hostname endpoint instead. |
| `podman pull registry.home.keithmarcus.com/...` hangs or times out | DNS cannot resolve the hostname from the VM | Check DNS on the Bazzite VM: `dig registry.home.keithmarcus.com`. If unresolved, add a static `/etc/hosts` entry: `192.168.20.7 registry.home.keithmarcus.com` or use the LAN IP endpoint directly. |
| Built image not visible on host after `bluebuild build` | Image lives in docker-compose container storage | Export: `docker-compose exec ... podman save ... \| podman load` (see container note in Strategy C) |
| `WARNING: image platform (linux/arm64) does not match the expected platform (linux/amd64)` | Built on `arm64` Mac without `--platform linux/amd64` | Rebuild with `bluebuild build --platform linux/amd64` (or `DOCKER_DEFAULT_PLATFORM=linux/amd64`). Verify with `podman inspect ... --format '{{.Architecture}}'` — must be `amd64`. |
| Cross-arch build fails with `exec format error` or `standard_init_linux.go` error | Container runtime lacks `qemu-user-static` for arm64→x86_64 emulation | For podman: `sudo podman run --rm --privileged multiarch/qemu-user-static --reset -p yes`. For Docker Desktop: enable "Use Rosetta" in Settings → General. Test with `podman run --rm --platform linux/amd64 alpine uname -m`. |

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
