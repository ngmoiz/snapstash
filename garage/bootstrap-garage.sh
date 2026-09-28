#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR line $LINENO (code $?)" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# set garage configmap
kubectl create configmap garage-config --from-file="$SCRIPT_DIR/garage.toml" --dry-run=client -o yaml | kubectl apply -f -

# set garage secrets
if [[ ! -f "$REPO_ROOT/k8s/garage-secrets.yaml" ]]; then
    echo "garage secrets file \"$REPO_ROOT/k8s/garage-secrets.yaml\" not found" >&2
    echo "create garage secrets from k8s/garage-secrets.yaml.example" >&2
    exit 1
fi
kubectl apply -f "$REPO_ROOT/k8s/garage-secrets.yaml"

# deploy garage
echo "deploy garage"
kubectl apply -f "$REPO_ROOT/k8s/garage.yaml"

# check deployment status

if ! kubectl rollout status deployment/garage --timeout=120s; then
    echo "garage deployment still not ready after 120s" >&2
    echo "current garage pods status:" >&2
    kubectl get pods -l app=garage >&2
    exit 1
fi
echo "garage deployment is ready"

# init garage pod
bash "$SCRIPT_DIR"/init-garage-k8s.sh
