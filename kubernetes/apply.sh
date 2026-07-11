#!/usr/bin/env bash
# Load db/init.sql into the mysql-init-sql ConfigMap and apply core manifests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS=api-pulse

kubectl apply -f "$ROOT/kubernetes/namespace.yaml"
kubectl apply -f "$ROOT/kubernetes/secret.yaml"
kubectl apply -f "$ROOT/kubernetes/configmap.yaml"

kubectl -n "$NS" create configmap mysql-init-sql \
  --from-file=01-init.sql="$ROOT/db/init.sql" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$ROOT/kubernetes/mysql.yaml"
kubectl apply -f "$ROOT/kubernetes/auth-service.yaml"
kubectl apply -f "$ROOT/kubernetes/analytics-service.yaml"
kubectl apply -f "$ROOT/kubernetes/web.yaml"
kubectl apply -f "$ROOT/kubernetes/ingress.yaml"

echo "Applied API Pulse manifests to namespace ${NS}."
echo "Remember to build/load images into Minikube before pods become Ready."
