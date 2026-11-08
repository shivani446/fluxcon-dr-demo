#!/usr/bin/env bash
# "Restore the keys from the vault": things Git must NOT hold, created before bootstrap.
# Usage: 03-prep-cluster.sh prod|dr
set -euo pipefail
source "$(dirname "$0")/env.sh"
C="${1:?usage: $0 prod|dr}"
kubectl config use-context "kind-$C"
HOST_IP=$(cat "$DEMO_HOME/host-ip")

kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

kubectl -n flux-system create configmap cluster-vars \
  --from-literal=HOST_IP="$HOST_IP" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n velero create secret generic velero-minio-creds \
  --from-file=cloud="$DEMO_HOME/credentials-velero" --dry-run=client -o yaml | kubectl apply -f -

echo "kind-$C prepped (cluster-vars HOST_IP=$HOST_IP, velero-minio-creds)."
