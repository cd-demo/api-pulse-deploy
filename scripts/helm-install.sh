#!/usr/bin/env bash
# Install / upgrade API Pulse from Docker Hub images via Helm.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS="${NAMESPACE:-api-pulse}"
RELEASE="${RELEASE:-api-pulse}"
TAG="${IMAGE_TAG:-latest}"

# Optional private Hub pull:
#   export DOCKERHUB_USERNAME=rajashekhar2390
#   export DOCKERHUB_TOKEN=...
#   export IMAGE_PULL_SECRET=1
#
# If you previously used ./kubernetes/apply.sh, resources exist without Helm
# ownership. This script adopts them. For a clean wipe instead:
#   FORCE_CLEAN=1 ./scripts/helm-install.sh

EXTRA_ARGS=()
if [[ "${IMAGE_PULL_SECRET:-}" == "1" ]]; then
  : "${DOCKERHUB_USERNAME:?set DOCKERHUB_USERNAME}"
  : "${DOCKERHUB_TOKEN:?set DOCKERHUB_TOKEN}"
  EXTRA_ARGS+=(
    --set imagePullSecrets.enabled=true
    --set dockerHub.username="$DOCKERHUB_USERNAME"
    --set dockerHub.password="$DOCKERHUB_TOKEN"
  )
fi

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

if [[ "${FORCE_CLEAN:-}" == "1" ]]; then
  echo "FORCE_CLEAN=1 — deleting Helm release and leftover resources in ${NS}"
  helm uninstall "$RELEASE" -n "$NS" 2>/dev/null || true
  kubectl -n "$NS" delete deploy,svc,ingress,cm,secret,pvc \
    -l 'app in (web,auth-service,analytics-service,mysql)' \
    --ignore-not-found
  kubectl -n "$NS" delete secret api-pulse-secrets dockerhub-cred --ignore-not-found
  kubectl -n "$NS" delete configmap api-pulse-config mysql-init-sql --ignore-not-found
  kubectl -n "$NS" delete pvc mysql-data --ignore-not-found
  kubectl -n "$NS" delete ingress api-pulse --ignore-not-found
fi

# Adopt resources that were created by kubectl apply (missing Helm metadata).
adopt() {
  local kind="$1"
  local name="$2"
  if kubectl -n "$NS" get "$kind" "$name" >/dev/null 2>&1; then
    local managed
    managed="$(kubectl -n "$NS" get "$kind" "$name" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)"
    if [[ "$managed" != "Helm" ]]; then
      echo "Adopting ${kind}/${name} into Helm release ${RELEASE}"
      kubectl -n "$NS" annotate "$kind" "$name" --overwrite \
        meta.helm.sh/release-name="$RELEASE" \
        meta.helm.sh/release-namespace="$NS" >/dev/null
      kubectl -n "$NS" label "$kind" "$name" --overwrite \
        app.kubernetes.io/managed-by=Helm >/dev/null
    fi
  fi
}

adopt secret api-pulse-secrets
adopt configmap api-pulse-config
adopt pvc mysql-data
adopt deployment mysql
adopt deployment auth-service
adopt deployment analytics-service
adopt deployment web
adopt service mysql
adopt service auth-service
adopt service analytics-service
adopt service web
adopt ingress api-pulse

# MySQL seed ConfigMap — managed outside the chart (not a Helm resource)
kubectl -n "$NS" create configmap mysql-init-sql \
  --from-file=01-init.sql="$ROOT/db/init.sql" \
  --dry-run=client -o yaml | kubectl apply -f -

HELM_EXTRA=()
# Helm 3.17+ can take ownership automatically
if helm upgrade --help 2>/dev/null | grep -q -- '--take-ownership'; then
  HELM_EXTRA+=(--take-ownership)
fi

helm upgrade --install "$RELEASE" "$ROOT/charts/api-pulse" \
  --namespace "$NS" \
  --set images.web.tag="$TAG" \
  --set images.auth.tag="$TAG" \
  --set images.analytics.tag="$TAG" \
  --set imagePullPolicy=Always \
  ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} \
  ${HELM_EXTRA[@]+"${HELM_EXTRA[@]}"} \
  "$@"

echo
echo "Deployed ${RELEASE} in ${NS} using Docker Hub tag: ${TAG}"
echo "  rajashekhar2390/api-pulse-web:${TAG}"
echo "  rajashekhar2390/api-pulse-auth-service:${TAG}"
echo "  rajashekhar2390/api-pulse-analytics-service:${TAG}"
echo
echo "Port-forward:  ${ROOT}/scripts/port-forward.sh"
