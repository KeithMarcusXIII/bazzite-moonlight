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

### Initialize the BlueBuild Modules Subtree

The [`modules/`](../modules/) directory is populated from the community [blue-build/modules](https://github.com/blue-build/modules) repository via git subtree. This gives you local copies of reusable BlueBuild module definitions (e.g., `default-flatpaks`, `chezmoi`, `brew`) without copying them manually.

> **Important:** All subtree commands must run from the **homelab** repository root (`/Users/digitsolu/dev/homelab`), not from `bazzite-moonlight/`. This is because `bazzite-moonlight` is itself a git subtree within homelab — only the parent repo owns the git history. Adjust the `--prefix` paths below if your directory layout differs.

#### First-Time Setup

Add the remote, fetch, and pull a specific module directory as a subtree:

```bash
cd /Users/digitsolu/dev/homelab

# 1. Register the remote
git remote add bluebuild-modules https://github.com/blue-build/modules.git
git fetch bluebuild-modules main

# 2. Temporarily checkout the remote — git subtree split requires the
#    --prefix to exist in the working tree
git checkout -b bb-temp bluebuild-modules/main

# 3. Split: extract only the desired module directory into a synthetic branch
git subtree split --prefix="modules/default-flatpaks" -b bb-split

# 4. Return to your branch
git checkout main

# 5. Add the split branch as a subtree at the target path
git subtree add \
  --prefix="common/ublue/bazzite-moonlight/modules/default-flatpaks" \
  bb-split

# 6. Clean up temporary branches
git branch -D bb-temp bb-split
```

**What happens:**
- `git subtree split --prefix="modules/default-flatpaks"` extracts only that directory from the remote's history, stripping the path prefix. Both `v1/` and `v2/` (and any other subdirectories) are included since the prefix targets their parent.
- `git subtree add` places the split content at `common/ublue/bazzite-moonlight/modules/default-flatpaks/` in your homelab repo.
- The temp checkout (`bb-temp`) works around a `git subtree split` quirk: it validates the `--prefix` against the local working tree, not just the remote commit. Checking out the remote branch makes the prefix available so the split can proceed.

#### Pulling Updates

When the upstream `blue-build/modules` repo publishes changes to a module you've already added:

```bash
cd /Users/digitsolu/dev/homelab

git fetch bluebuild-modules main
git checkout -b bb-temp bluebuild-modules/main
git subtree split --prefix="modules/default-flatpaks" -b bb-split
git checkout main

git subtree pull \
  --prefix="common/ublue/bazzite-moonlight/modules/default-flatpaks" \
  bb-split

git branch -D bb-temp bb-split
```

> **Note:** This is a **read-only** workflow. There is no pushing back to `bluebuild-modules` — changes to module behaviour should be made in your own recipe files, not in the subtree.

#### Adding Additional Modules from the Same Remote

To pull another module directory from `bluebuild-modules` (e.g., `modules/chezmoi`, `modules/brew`, `modules/script`), repeat the split+add pattern with a different `--prefix`:

```bash
cd /Users/digitsolu/dev/homelab

# Example: adding the chezmoi module
git fetch bluebuild-modules main
git checkout -b bb-temp bluebuild-modules/main
git subtree split --prefix="modules/chezmoi" -b bb-split
git checkout main

git subtree add \
  --prefix="common/ublue/bazzite-moonlight/modules/chezmoi" \
  bb-split

git branch -D bb-temp bb-split
```

Each module becomes an independent subtree entry in the homelab repo — they can be updated individually with `git subtree pull`. The resulting `modules/` directory will look like:

```
bazzite-moonlight/modules/
├── default-flatpaks/    ← subtree from modules/default-flatpaks
│   ├── module.yml
│   ├── v1/
│   └── v2/
├── chezmoi/             ← subtree from modules/chezmoi (future)
├── brew/                ← subtree from modules/brew (future)
└── script/              ← subtree from modules/script (future)
```

> **Consistency tip:** Always map the source module name directly (e.g., `modules/default-flatpaks` → `modules/default-flatpaks`). This keeps BlueBuild `from-file` references predictable and avoids confusion when the origin needs to be traced.

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

The [`modules/`](../modules/) directory holds reusable BlueBuild module definitions pulled from the community [blue-build/modules](https://github.com/blue-build/modules) repository. See [Initialize the BlueBuild Modules Subtree](#initialize-the-bluebuild-modules-subtree) above for setup and update procedures.

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
| `colima` | Container runtime on the Mac. Config: `runtime: docker`, `rosetta: true`, `binfmt: true`, `vmType: vz`. Provides Docker CLI and x86_64 emulation. |
| `docker` CLI | Colima exposes the Docker socket — all Mac-side commands use `docker`. |
| Local Bazzite VM | Proxmox VM at `192.168.30.171` / `bazzite.local.keithmarcus.com`. Uses `podman` natively. |
| Cross-arch emulation | Build host is `arm64` (Apple Silicon); target is `x86_64`. Colima's `rosetta: true` and `binfmt: true` provide transparent emulation. `bluebuild` supports `--platform linux/amd64` natively. |

#### Step-by-Step: Build Locally

1. **Build the image** from the recipe, targeting `x86_64`:

   ```bash
   cd bazzite-moonlight
   bluebuild build recipes/recipe.yml --platform linux/amd64
   ```

   This produces a local container image tagged `bazzite-moonlight:latest` in colima's docker storage.

2. **Verify the image exists locally and check its architecture:**

   ```bash
   docker images localhost/bazzite-moonlight

   # Confirm the image is amd64, not arm64
   docker inspect localhost/bazzite-moonlight:latest --format '{{.Architecture}}'
   # Must output: amd64
   ```

#### Step-by-Step: Deploy to the Test VM

The test VM (`192.168.30.171` / `bazzite.local.keithmarcus.com`) is an existing Proxmox VM with a Bazzite installation. Three deployment strategies are available, listed from lowest to highest latency.

```mermaid
flowchart LR
    subgraph Mac["MacBook Pro Mac15,3 - arm64"]
        BB["bluebuild CLI --platform linux/amd64"]
        DOCKER["docker push"]
        BB --> DOCKER
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

    DOCKER -->|push x86_64 image| REG
    REG -->|podman pull| PULL
```

##### Strategy C: Push to existing LAN registry — lowest latency, recommended

This strategy leverages the existing container registry at `registry.home.keithmarcus.com` (reverse-proxied by Caddy, upstream at `192.168.20.7:80`). The Mac pushes the locally-built image to it, and the Bazzite VM pulls directly over the LAN. No image data touches the internet, layers are cached, and incremental rebuilds transfer only changed layers.

> **⚠️ Architecture mismatch:** The build host (`arm64` Apple Silicon) and deployment target (`x86_64`) differ. Without `--platform linux/amd64`, `bluebuild` produces an `arm64` image that the Bazzite VM cannot run — resulting in:
> ```
> WARNING: image platform (linux/arm64) does not match the expected platform (linux/amd64)
> ```
> Colima provides transparent x86_64 emulation via `rosetta: true` and `binfmt: true`. `bluebuild` supports `--platform` natively. Verify emulation: `docker run --rm --platform linux/amd64 alpine uname -m` (should output `x86_64`).

###### Push Target

You have two ways to address the registry:

| Endpoint | Type | Notes |
|----------|------|-------|
| `registry.home.keithmarcus.com` | Hostname with TLS | Caddy reverse-proxy with auto TLS. Preferred — works with default Docker settings. Verify TLS: `curl -v https://registry.home.keithmarcus.com/v2/` — a valid response confirms TLS is operational. |
| `192.168.20.7:80` | Raw LAN IP | Plain HTTP. Requires `insecure-registries` colima config (see below). |

###### Build and Push to Registry

The image reference must include the registry address — `localhost/name:tag` doesn't tell Docker where to push.

```bash
# 1. Build the image for x86_64 target
cd bazzite-moonlight
bluebuild build recipes/recipe.yml --platform linux/amd64

# 2. Verify the image architecture
docker inspect localhost/bazzite-moonlight:latest --format '{{.Architecture}}'
# Must output: amd64

# 3. Tag with registry prefix and push via hostname (TLS, no extra config)
docker tag localhost/bazzite-moonlight:latest \
  registry.home.keithmarcus.com/bazzite-moonlight:latest
docker push registry.home.keithmarcus.com/bazzite-moonlight:latest

# OR push via LAN IP — requires insecure-registries (see below)
docker tag localhost/bazzite-moonlight:latest \
  192.168.20.7:80/bazzite-moonlight:latest
docker push 192.168.20.7:80/bazzite-moonlight:latest
```

> **Colima insecure registry config for LAN IP:** Add to `~/.colima/default/colima.yaml`:
> ```yaml
> docker:
>   insecure-registries:
>     - 192.168.20.7:80
> ```
> Then restart colima: `colima restart`. The hostname endpoint (`registry.home.keithmarcus.com`) works without this because Caddy provides TLS.

> **Container networking note:** If `bluebuild` runs inside a docker-compose container, the built image may reside in the container's storage. Export it to the host first:
> ```bash
> docker-compose -p local -f /Users/digitsolu/local/compose.yaml \
>   exec -w /bluebuild/bazzite-moonlight bluebuild \
>   docker save localhost/bazzite-moonlight:latest | \
>   docker load
> docker tag localhost/bazzite-moonlight:latest registry.home.keithmarcus.com/bazzite-moonlight:latest
> docker push registry.home.keithmarcus.com/bazzite-moonlight:latest
> ```

###### Pull and Rebase on the Destination

On the Bazzite VM, rebase directly from the LAN registry. **Two approaches**, listed in order of preference:

###### Approach 1: Direct Registry Rebase (Recommended)

`rpm-ostree` supports the `registry:` transport, which pulls the image directly from the container registry — no `podman pull`, no retag, no `containers-storage:` needed:

```bash
# Rebase directly from the LAN registry
rpm-ostree rebase ostree-unverified-image:registry:registry.home.keithmarcus.com/bazzite-moonlight:latest
systemctl reboot

# OR rebase via LAN IP — requires --tls-verify=false
rpm-ostree rebase ostree-unverified-image:registry:192.168.20.7:80/bazzite-moonlight:latest
systemctl reboot
```

> **Why this is preferred:** The `registry:` transport avoids the `containers-storage:` pitfalls entirely — no duplicate image storage, no `sudo` required, no root vs user storage confusion. rpm-ostree pulls and deploys directly.

###### Approach 2: Podman Pull + containers-storage (Fallback)

If the registry is unreachable from `rpm-ostree` (e.g., TLS/Cert trust issues), pull the image into podman storage first, then rebase via `containers-storage:`.

> **⚠️ Root storage caveat:** `rpm-ostree` reads from **root's** podman storage (`/var/lib/containers/storage`), NOT the user's (`~/.local/share/containers/storage`). All `podman pull` commands must use `sudo` or the image will be invisible to `rpm-ostree`.

```bash
# Pull into root's storage (sudo is required)
sudo podman pull registry.home.keithmarcus.com/bazzite-moonlight:latest

# Verify architecture
sudo podman inspect registry.home.keithmarcus.com/bazzite-moonlight:latest \
  --format '{{.Architecture}}'
# Must output: amd64

# ⚠️ containers-storage: transport requires localhost/ prefix
sudo podman tag registry.home.keithmarcus.com/bazzite-moonlight:latest \
  localhost/bazzite-moonlight:latest

# Rebase from root's containers-storage
rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
systemctl reboot

# OR pull via LAN IP — same retag required
sudo podman pull --tls-verify=false 192.168.20.7:80/bazzite-moonlight:latest
sudo podman tag 192.168.20.7:80/bazzite-moonlight:latest localhost/bazzite-moonlight:latest
rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
systemctl reboot
```

> **Why retag?** The `containers-storage:` transport in `rpm-ostree` does not accept registry-prefixed references like `registry.home.keithmarcus.com/name:tag`. Images must be tagged with a `localhost/` prefix (e.g., `localhost/bazzite-moonlight:latest`) for `rpm-ostree` to find them in root's podman storage. Attempting to rebase without retagging produces:
> ```
> error: reference "registry.home.keithmarcus.com/bazzite-moonlight:latest" does not resolve to an image ID
> ```

> **Why `sudo`?** User-space `podman pull` stores images in `~/.local/share/containers/storage`. `rpm-ostree` reads from `/var/lib/containers/storage` (root's storage). An image pulled without `sudo` will produce:
> ```
> error: Old and new refs are equal: ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
> ```
> Or, if you try a different tag:
> ```
> error: reference "localhost/bazzite-moonlight:v2" does not resolve to an image ID
> ```
> Both errors indicate rpm-ostree cannot see the image you pulled. Always use `sudo podman` when preparing images for `containers-storage:` rebase.

###### Incremental Rebuilds

On subsequent changes, only modified layers transfer:

```bash
# Rebuild and push on Mac (docker via colima)
bluebuild build recipes/recipe.yml --platform linux/amd64
docker tag localhost/bazzite-moonlight:latest registry.home.keithmarcus.com/bazzite-moonlight:latest
docker push registry.home.keithmarcus.com/bazzite-moonlight:latest

# On Bazzite VM — direct registry rebase (no podman pull needed)
rpm-ostree rebase ostree-unverified-image:registry:registry.home.keithmarcus.com/bazzite-moonlight:latest
systemctl reboot
```

> **Why this is fastest:** The registry is OCI-native — layer hashes are compared before transfer. Only layers that actually changed (e.g., a new RPM package) cross the LAN. The base image layers from `ghcr.io/ublue-os/bazzite-dx-gnome:stable` are also cached in the registry after the first push, so they never re-transfer to the VM either. The `registry:` transport in rpm-ostree pulls directly without requiring an intermediate `podman pull` step — one command end-to-end.

##### Strategy A: Tarball transfer via SSH

This approach serializes the full image to a tarball and pipes it over SSH. Useful as a fallback when a registry isn't available. Uses `docker save` on the Mac, `sudo podman load` on the VM — the OCI format is compatible across both.

> **⚠️ Root storage:** `docker save` outputs to stdout, which `ssh` pipes into the VM's `podman load`. On the VM side, images load into the user's podman storage. However, `rpm-ostree` reads from **root's** containers-storage. Use `sudo podman load` so the image lands in root's storage where rpm-ostree can find it.

1. **Transfer the image** to the test VM via SSH:

   ```bash
   # Save from colima/docker on Mac, load into root's podman on VM
   docker save localhost/bazzite-moonlight:latest | \
     ssh bazzite.local.keithmarcus.com sudo podman load
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
   # Pull the base image separately (retry-friendly) — use sudo for root storage
   sudo podman pull ghcr.io/ublue-os/bazzite-dx-gnome:stable

   # Load the locally-built overlay into root's storage (sudo required)
   sudo podman load < bazzite-moonlight.tar
   ```

3. **Rebase** to the local image:

   ```bash
   rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest
   systemctl reboot
   ```

   This approach separates the base-image pull (which can be retried independently) from the rebase, avoiding the common hang where `rpm-ostree` gets stuck mid-pull.

> **Why `sudo` in this workflow?** Same reason as Strategy C — rpm-ostree reads root's `/var/lib/containers/storage`, not the user's `~/.local/share/containers/storage`. Without `sudo`, `podman load` or `podman pull` puts the image in user storage, and `rpm-ostree redeploy ...` will fail with `Old and new refs are equal` or `does not resolve to an image ID`.

#### Troubleshooting Network & Daemon Issues

| Symptom | Likely Cause | Workaround |
|---------|-------------|------------|
| `rpm-ostree rebase` hangs during layer pull | Network congestion / registry throttling | Use **Strategy B**: `sudo podman pull` base image first, then rebase to `containers-storage:` |
| `bluebuild build` fails on image pull | Transient registry issue | Retry with `docker pull ghcr.io/ublue-os/bazzite-dx-gnome:stable` then re-run `bluebuild build` |
| Image layers repeatedly stuck | `rpm-ostree` or `podman` bug (UNCONFIRMED) | Clear VM storage: `sudo podman system prune -a`, then rebuild from Mac |
| Cannot reach `bazzite.local.keithmarcus.com` | DNS / mDNS failure | Use IP directly: `ssh 192.168.30.171` |
| `docker push registry.home.keithmarcus.com/...` fails with `x509` cert error | Caddy TLS certificate issue | If using Let's Encrypt staging or self-signed cert, use the LAN IP endpoint instead, or fix Caddy's TLS config |
| `docker push 192.168.20.7:80/...` fails with `http: server gave HTTP response to HTTPS client` | Docker requires `insecure-registries` config for HTTP | Add `192.168.20.7:80` to `~/.colima/default/colima.yaml` under `docker.insecure-registries`, then `colima restart`. Or use the hostname endpoint instead. |
| `podman pull registry.home.keithmarcus.com/...` hangs or times out | DNS cannot resolve the hostname from the VM | Check DNS on the Bazzite VM: `dig registry.home.keithmarcus.com`. If unresolved, add a static `/etc/hosts` entry: `192.168.20.7 registry.home.keithmarcus.com` or use the LAN IP endpoint directly. |
| Built image not visible on host after `bluebuild build` | Image lives in docker-compose container storage | Export: `docker-compose exec ... docker save ... \| docker load` (see container note in Strategy C) |
| `rpm-ostree rebase` fails with `reference "registry.home.keithmarcus.com/...:latest" does not resolve to an image ID` | `containers-storage:` transport does not accept registry-prefixed image references | Retag the pulled image: `sudo podman tag registry.home.keithmarcus.com/bazzite-moonlight:latest localhost/bazzite-moonlight:latest`. Then rebase to `ostree-unverified-image:containers-storage:localhost/bazzite-moonlight:latest`. |
| `rpm-ostree rebase` fails with `Old and new refs are equal` | Image in root's containers-storage is identical to the current deployment (image was pulled into user storage instead) | Either use the `registry:` transport directly: `rpm-ostree rebase ostree-unverified-image:registry:registry.home.keithmarcus.com/bazzite-moonlight:latest`, OR pull into root's storage: `sudo podman pull ... && rpm-ostree upgrade` |
| `rpm-ostree rebase` fails with `does not resolve to an image ID` for a locally-tagged image | The tag exists in user podman storage but not in root's containers-storage where rpm-ostree looks | Verify: `sudo podman image ls localhost/bazzite-moonlight`. Retag with `sudo podman tag` if missing. Always use `sudo podman` for image preparation. |
| `rpm-ostree upgrade` fails with `min-free-space-percent '3%' would be exceeded` | Insufficient disk space on the Bazzite VM for the new deployment | Free space: `rpm-ostree cleanup -r` (remove rolled-back deployments), then `sudo podman system prune -a` (remove unused images). Retry `rpm-ostree upgrade`. |
| `WARNING: image platform (linux/arm64) does not match the expected platform (linux/amd64)` | Built on `arm64` Mac without `--platform linux/amd64` | Rebuild with `bluebuild build recipes/recipe.yml --platform linux/amd64`. Verify with `docker inspect ... --format '{{.Architecture}}'` — must be `amd64`. |
| Cross-arch build fails with `exec format error` | Colima missing x86_64 emulation support | Ensure colima config has `rosetta: true` and `binfmt: true`. Verify: `docker run --rm --platform linux/amd64 alpine uname -m` — should output `x86_64`. If not, `colima delete && colima start --arch host --vm-type vz --rosetta`. |

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
