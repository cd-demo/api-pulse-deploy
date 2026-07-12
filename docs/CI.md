# CI — Docker Hub builds

App repos use **self-contained** workflows (`.github/workflows/build-push.yml`) so CI does not depend on
cross-repo reusable-workflow access. That avoids the common private-org error:

```text
workflow was not found
-> cd-demo/api-pulse-deploy/.github/workflows/reusable-docker-build-push.yml@main
```

The reusable workflow in this repo remains the **reference implementation** if you later enable Access and switch callers back.

## Triggers

| Event | Branches |
|-------|----------|
| Push / merge | `main` |
| Push | `feature-**` |
| Manual | `workflow_dispatch` |

## Images (Docker Hub user `rajashekhar2390`)

- `rajashekhar2390/api-pulse-web`
- `rajashekhar2390/api-pulse-auth-service`
- `rajashekhar2390/api-pulse-analytics-service`

## Secrets (each app repo, or org secrets)

| Secret | Value |
|--------|--------|
| `DOCKERHUB_USERNAME` | `rajashekhar2390` |
| `DOCKERHUB_TOKEN` | Docker Hub access token |

Org secrets: https://github.com/organizations/cd-demo/settings/secrets/actions

## Runner

Org or repo runner with labels: `self-hosted`, `macOS`, `X64`, `beacon`

## Optional: restore cross-repo reusable calls

1. https://github.com/cd-demo/api-pulse-deploy/settings/actions  
2. **Access** → **Accessible from repositories in the `cd-demo` organization**  
3. Point callers at `cd-demo/api-pulse-deploy/.github/workflows/reusable-docker-build-push.yml@main`
