# CI — Docker Hub builds (reusable)

App repos do **not** define their own Docker build logic. They call this reusable workflow:

[`reusable-docker-build-push.yml`](../.github/workflows/reusable-docker-build-push.yml)

## Triggered by (in each app repo)

| Event | Branches |
|-------|----------|
| Push / merge to | `main` |
| Push to | `feature-**` (e.g. `feature-login-fix`) |

`api-pulse-deploy` itself does **not** build app images.

Default runner labels: `self-hosted`, `macOS`, `X64`, `beacon`.

## Image tags

On **`main`**:

- `rijantakar1/<service>:latest`
- `rijantakar1/<service>:<package.json version>`
- `rijantakar1/<service>:<version>-<shortsha>`
- `rijantakar1/<service>:main-<shortsha>`

On **`feature-*`**:

- `rijantakar1/<service>:feature-<name>`
- `rijantakar1/<service>:feature-<name>-<shortsha>`

## One-time setup

### 1. Push this workflow to `api-pulse-deploy` `main`

Cross-repo `uses: owner/repo/...@main` only works after the reusable file exists on `main`.

### 2. Fix “workflow was not found” (private repos) — required

Your repos are **private**. GitHub will not let an app repo call a reusable workflow from `api-pulse-deploy` until access is shared.

1. Open: https://github.com/rijantakar1/api-pulse-deploy/settings/actions  
2. Scroll to **Access** (share reusable workflows / composite actions)  
3. Select: **Accessible from repositories owned by the user `rijantakar1`**  
4. Save  

Without this, callers fail with:

```text
error parsing called workflow
... workflow was not found
```

Optional: make `api-pulse-deploy` public instead (also works, but exposes manifests).

### 3. Docker Hub secrets (each app repo)

| Secret | Value |
|--------|--------|
| `DOCKERHUB_USERNAME` | e.g. `rijantakar1` |
| `DOCKERHUB_TOKEN` | Docker Hub access token |

Repo → **Settings → Secrets and variables → Actions**.

> Local `docker login` on your Mac does **not** apply to GitHub Actions.

### 4. Self-hosted runner

Ensure the runner is online and labeled exactly:

`self-hosted`, `macOS`, `X64`, `beacon`

Docker Desktop (or Docker engine) must be available on that machine for image builds.

### 5. Caller workflows

- `api-pulse-web/.github/workflows/build-push.yml`
- `api-pulse-auth-service/.github/workflows/build-push.yml`
- `api-pulse-analytics-service/.github/workflows/build-push.yml`

Override runner from a caller if needed:

```yaml
with:
  image_name: rijantakar1/api-pulse-analytics-service
  runs_on: '["self-hosted", "macOS", "ARM64", "beacon"]'
```
