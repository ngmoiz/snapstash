#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR line $LINENO (code $?)" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# set db init file
kubectl create configmap db-init --from-file="$SCRIPT_DIR/init.sql" --dry-run=client -o yaml | kubectl apply -f -

# set db secrets
if [[ ! -f "$REPO_ROOT/k8s/db-secrets.yaml" ]]; then
    echo "db secrets file \"$REPO_ROOT/k8s/db-secrets.yaml\" not found" >&2
    echo "create db secrets from k8s/db-secrets.yaml.example" >&2
    exit 1
fi
kubectl apply -f "$REPO_ROOT/k8s/db-secrets.yaml"

# deploy db
echo "deploy db"
kubectl apply -f "$REPO_ROOT/k8s/db.yaml"

# check deployment status
if ! kubectl rollout status deployment/db --timeout=120s; then
    echo "db deployment still not ready after 120s" >&2
    echo "current db pods status:" >&2
    kubectl get pods -l app=db >&2
    exit 1
fi
echo "db deployment is ready"

