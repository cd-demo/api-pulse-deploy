# Amazon ECR (replaces Docker Hub for app images)

App images are pushed to ECR and pulled by Minikube via an `ecr-pull` secret.

## Repositories

| ECR repo | Chart |
|----------|--------|
| `api-pulse-web` | api-pulse |
| `api-pulse-auth-service` | api-pulse |
| `api-pulse-analytics-service` | api-pulse |
| `odin-api` | odin |
| `odin-ui` | odin |

URI shape: `<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/<repo>:<tag>`

Default region in values: `us-east-1` (override with `ecr.region` / secret `AWS_REGION`).

## Multi-arch images (required for Apple Silicon Minikube)

CI builds **`linux/amd64` + `linux/arm64`** with `docker buildx` and pushes a manifest list to ECR.

Linux self-hosted runners alone produce amd64-only images; Minikube on Apple Silicon then fails with:

`no matching manifest for linux/arm64/v8`

## GitHub Actions secrets (each app repo)

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | IAM user for ECR push |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret |
| `AWS_REGION` | e.g. `us-east-1` |
| `AWS_ACCOUNT_ID` | 12-digit account id |
| `DEPLOY_REPO_TOKEN` | GitOps write to `api-pulse-deploy` |

CI logs into ECR, pushes tags, then updates Helm values (`ensure_ecr_registry.py` + bump scripts).

## One-time / local Helm values

```bash
cd api-pulse-deploy
./scripts/set-ecr-account.sh <AWS_ACCOUNT_ID> us-east-1
# commit charts/*/values.yaml if you want Argo to pick registry before next CI
```

## Minikube pull secret (refresh every ~12h)

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=<account>
# credentials: same IAM user, or `aws sso login` / profile with ECR pull
./scripts/refresh-ecr-pull-secret.sh api-pulse odin
```

Or during bootstrap:

```bash
ECR_PULL_SECRET=1 AWS_REGION=us-east-1 AWS_ACCOUNT_ID=<account> \
  ./scripts/bootstrap-argocd-app.sh
```

## After migration checklist

1. [ ] ECR repos exist; IAM user can push  
2. [ ] GitHub secrets set on all 5 app repos  
3. [ ] Push / re-run CI on each service `main` (or feature branch) to populate **multi-arch** ECR tags  
4. [ ] `./scripts/set-ecr-account.sh` + commit **or** let first CI write `ecr.accountId`  
5. [ ] Refresh `ecr-pull` secret; Argo syncs; pods Running  

MySQL still uses public `mysql:9.7` from Docker Hub (no pull secret required for that image). Never let GitOps bump overwrite `images.mysql.tag`.
