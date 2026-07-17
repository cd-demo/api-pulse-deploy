# Odin + Istio version routing

Odin is the Tenant Manager Service (UI + API). It onboards tenants and pins
global / per-tenant service versions. Pins live in Git; Argo CD syncs Istio
VirtualServices that route on the `X-Tenant-Slug` header.

## Architecture

```text
Browser  --X-Tenant-Slug-->  Istio Gateway  -->  VirtualServices
                                                    |
                                                    +--> api-pulse-web-<tag>
                                                    +--> api-pulse-auth-<tag>
                                                    +--> api-pulse-analytics-<tag>

Odin UI --> Odin API --> routing/tenants.yaml (+ render) --> git commit
                                                              |
                                                           Argo CD
                                                              |
                                                    routing/generated/*.yaml
```

**Resolution:** for each service, `tenant[svc] ?? global[svc]`.

**Demo diagram (Excalidraw):** [`docs/demo-e2e-flow.excalidraw`](./demo-e2e-flow.excalidraw) — CI → Argo CD → Odin pin → Istio rewiring.

## Timing (what to expect)

| Step | Typical latency |
|------|-----------------|
| Odin render + `kubectl apply` | **1–5 seconds** (instant rewiring) |
| Git push → Argo auto-sync | **30–90 seconds** (if kubectl apply is off) |
| Browser seeing new web pin | Reload / re-login after apply (cookie routes the document) |

Local demos: set `ODIN_GIT_PUSH=true` and `ODIN_KUBECTL_APPLY=true` in `odin-api/.env`.

**Do not port-forward cluster `odin-api` to `:4100` for pin changes** unless you set a GitHub token.
Cluster Odin uses `https://github.com/...` with an empty token → `could not read Username for 'https://github.com'`.
Use the local API instead (SSH remote + `kubectl apply`).

Quick check: `curl -s http://localhost:4100/health` should show `"version":"0.1.0"` (local).
If you see an ECR-style tag like `20260717-…`, a kubectl port-forward has stolen `:4100` — kill it.

```bash
# stop any kubectl port-forward on 4100, then:
cd odin-api && set -a && source .env && set +a
nohup node src/index.js >/tmp/odin-api.log 2>&1 &
curl -s http://localhost:4100/health; echo
```

## Phase A — Platform

### 1. Multi-version Helm

[`charts/api-pulse/values.yaml`](../charts/api-pulse/values.yaml) lists concurrent tags:

```yaml
versionsActive:
  web: ["latest", "20260713-abc1234"]
  auth: ["latest"]
  analytics: ["latest"]
```

Each entry becomes Deployment + Service `api-pulse-{svc}-{tag}`.

CI `bump_values.py` appends the new tag (keeps `versionsActiveMax`).

### 2. Routing source of truth

[`routing/tenants.yaml`](../routing/tenants.yaml) → render:

```bash
python3 scripts/render-istio-routing.py
# writes routing/generated/{gateway,vs-*}.yaml
```

Argo Application: [`argocd/application-routing.yaml`](../argocd/application-routing.yaml)

### 3. Install Istio on Minikube

```bash
./scripts/install-istio.sh
./scripts/bootstrap-argocd-app.sh   # applies api-pulse + routing (+ odin if present)
./scripts/port-forward-istio.sh     # http://localhost:8080
```

For gateway demos, set browser URLs via Helm overlay:

```bash
# values-istio.yaml sets:
#   authUrl: http://localhost:8080/auth
#   analyticsUrl: http://localhost:8080/analytics
```

Direct (no Istio) port-forward still works:

```bash
./scripts/port-forward.sh
# WEB_TAG=... AUTH_TAG=... ANALYTICS_TAG=... optional
```

### 4. Prove header routing

With two web tags active and `tenants.yaml`:

```yaml
global:
  web: "tag-a"
tenants:
  acme:
    web: "tag-b"
```

Re-render, commit, Argo sync, then:

```bash
curl -sH 'X-Tenant-Slug: acme' http://localhost:8080/ | head
curl -s http://localhost:8080/ | head   # global tag-a
```

Environment Info in the UI shows the **pod** version after login. Login sets an
`api_pulse_tenant` cookie and reloads so the HTML/JS themselves come from the
tenant-pinned web build (browsers cannot send `X-Tenant-Slug` on navigation).

## Phase B — Odin

Repos:

| Path | Role |
|------|------|
| `../odin-api` | Express TMS API |
| `../odin-ui` | React admin console |
| `charts/odin` | Helm + Argo App `odin` |

Local API (writes to sibling deploy checkout; push optional):

```bash
cd ../odin-api
cp .env.example .env
# DEPLOY_REPO_DIR=../api-pulse-deploy
# ODIN_GIT_PUSH=false for local commits only
npm install && npm run dev
```

```bash
cd ../odin-ui && npm install && npm run dev
# http://localhost:5174  — odin / odin-admin
```

In-cluster Odin only pushes to Git when `odin.gitToken` is set (PAT with contents
write on `api-pulse-deploy`). Default `odin.gitPush` is `false` so HTTPS without a
token does not error.

For the Minikube pin demo, prefer **local** `odin-api` (SSH + `kubectl apply`).
Only port-forward the UI if needed — do **not** forward cluster API onto `:4100`
while the local API is running (that recreates the HTTPS username error):

```bash
kubectl -n odin port-forward svc/odin-ui 5174:80
# Local UI (odin-ui vite) should call http://localhost:4100 (local odin-api)
```

## Phase C — Demo script

```bash
./scripts/demo-odin.sh
```

Manual checklist:

1. Ensure two `versionsActive.web` tags are running.
2. In Odin: onboard `initech` (or pin `acme` web to tag B).
3. Confirm `routing/tenants.yaml` + `routing/generated` updated; Argo syncs.
4. Login to API Pulse as that tenant; Environment Info shows pinned versions.
5. Retire unused tag in Odin Versions tab (after clearing pins).

## Retire versions

`POST /api/versions/retire` `{ "service": "web", "tag": "..." }` removes the tag from
`versionsActive` when no global/tenant pin references it. App chart prune is **off**,
so delete leftover Deployments manually or enable prune later.
