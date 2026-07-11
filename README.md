# API Pulse — Deploy

Shared Docker Compose, MySQL bootstrap, tenant scripts, and Kubernetes manifests for the **API Pulse** demo.

Sibling application repos (expected next to this folder under `argocd-demo/`):

| Repo | Role |
|------|------|
| [`api-pulse-web`](../api-pulse-web) | React UI |
| [`api-pulse-auth-service`](../api-pulse-auth-service) | JWT auth |
| [`api-pulse-analytics-service`](../api-pulse-analytics-service) | Metrics API |

Personal GitHub setup (BMC config untouched): see [`../PERSONAL-GIT-SETUP.md`](../PERSONAL-GIT-SETUP.md).

## Layout

```
api-pulse-deploy/
├── db/
│   ├── init.sql                 # registry + Acme / Globex seed
│   └── scripts/add-tenant.sh    # add a new tenant schema
├── docker-compose.yml
├── kubernetes/
│   └── build-images-minikube.sh
└── kubernetes/
    ├── namespace.yaml
    ├── configmap.yaml
    ├── secret.yaml
    ├── mysql.yaml
    ├── auth-service.yaml
    ├── analytics-service.yaml
    ├── web.yaml
    ├── ingress.yaml
    └── apply.sh
```

## Docker Compose (local)

From this directory, with sibling repos present:

```bash
cp .env.example .env
docker compose up --build
```

| Service | URL |
|---------|-----|
| Web | http://localhost:8080 |
| Auth | http://localhost:4001 |
| Analytics | http://localhost:4002 |
| MySQL | localhost:3306 |

Demo logins (password `password123`):

- `admin@acme.demo` (teal theme)
- `admin@globex.demo` (amber theme)

### Add a tenant

```bash
chmod +x db/scripts/add-tenant.sh
./db/scripts/add-tenant.sh initech "Initech" "#1D4ED8" admin@initech.demo password123
```

## Minikube

```bash
minikube start
minikube addons enable ingress

# Build images into Minikube's Docker daemon
chmod +x scripts/build-images-minikube.sh kubernetes/apply.sh
./scripts/build-images-minikube.sh

# Apply manifests (creates mysql-init-sql ConfigMap from db/init.sql)
./kubernetes/apply.sh

# Point host at the ingress
echo "$(minikube ip) api-pulse.local" | sudo tee -a /etc/hosts

# Or use tunnel (separate terminal)
minikube tunnel
```

Open http://api-pulse.local

Ingress paths:

- `/` → web
- `/auth/*` → auth-service (strip prefix)
- `/analytics/*` → analytics-service (strip prefix)

Bump versions for demos by editing `AUTH_VERSION` / `ANALYTICS_VERSION` / `UI_VERSION` in `kubernetes/configmap.yaml` and rebuilding images with `IMAGE_TAG`.

## Tenancy model (this phase)

- **Shared deployments** in namespace `api-pulse` — one UI + Auth + Analytics for all tenants.
- **Database-per-tenant** (`tenant_acme`, `tenant_globex`, …) plus `api_pulse_registry.tenants`.
- Tenant resolved at login; theme color comes from the tenant row.

## Future

Per-tenant service versions via Argo CD + a tenant-manager (UI/backend) and a git mapping of tenant → image tags is intentionally out of scope here.
