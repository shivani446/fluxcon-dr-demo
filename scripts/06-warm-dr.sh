#!/usr/bin/env bash
# Pre-load every image prod uses into the dr node, so the live bootstrap is fast.
set -euo pipefail
source "$(dirname "$0")/env.sh"
IMAGES=$(kubectl --context kind-prod get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{range .spec.initContainers[*]}{.image}{"\n"}{end}{end}' | sort -u)
for img in $IMAGES; do
  echo "==> $img"
  docker pull -q "$img" >/dev/null && kind load docker-image "$img" --name dr >/dev/null || echo "   (skipped)"
done
echo "dr node warmed."
