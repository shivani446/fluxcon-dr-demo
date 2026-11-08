#!/usr/bin/env bash
# Create kind clusters. Usage: 02-clusters.sh [prod|dr|both]   (default: both)
set -euo pipefail
source "$(dirname "$0")/env.sh"
WHICH="${1:-both}"

create() {
  local name=$1
  if kind get clusters | grep -qx "$name"; then echo "cluster $name exists"; return; fi
  kind create cluster --name "$name" --wait 120s
}

case "$WHICH" in
  prod) create prod ;;
  dr)   create dr ;;
  both) create prod; create dr ;;
  *) echo "usage: $0 [prod|dr|both]"; exit 1 ;;
esac

# Gateway of the 'kind' Docker network = how nodes reach NFS + MinIO on the WSL host
HOST_IP=$(docker network inspect kind | jq -r '.[0].IPAM.Config[] | select(.Gateway != null and (.Gateway | test("^[0-9.]+$"))) | .Gateway' | head -1)
echo "$HOST_IP" > "$DEMO_HOME/host-ip"
echo "HOST_IP=$HOST_IP (saved to $DEMO_HOME/host-ip)"
kind get clusters
