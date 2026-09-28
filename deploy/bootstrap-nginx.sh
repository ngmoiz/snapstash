#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR line $LINENO (code $?)" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# set nginx configmap
kubectl create configmap nginx-config --from-file="$REPO_ROOT/static/index.html" --from-file="$SCRIPT_DIR/nginx.conf" --dry-run=client -o yaml | kubectl apply -f -

# deploy nginx
echo "deploy nginx"
kubectl apply -f "$REPO_ROOT/k8s/nginx.yaml"

# reload deployment
kubectl rollout restart deploy/nginx

# check deployment status
if ! kubectl rollout status deployment/nginx --timeout=120s; then
    echo "nginx deployment still not ready after 120s" >&2
    echo "current nginx pods status:" >&2
    kubectl get pods -l app=nginx >&2
    exit 1
fi
echo "nginx deployment is ready"
