#!/usr/bin/env bash
# Get back to the pre-demo state after a rehearsal (~10 min).
# Result: prod healthy with fresh backup, dr created + prepped + warmed, not bootstrapped.
set -euo pipefail
source "$(dirname "$0")/env.sh"
D="$(dirname "$0")"
: "${GITHUB_TOKEN:?export GITHUB_TOKEN first}"

kind delete cluster --name dr || true
kind delete cluster --name prod || true
sudo rm -rf "${NFS_ROOT:?}/prod/"* "${NFS_ROOT:?}/dr/"*

# drop the dr bootstrap commit so the live bootstrap is a real first install
git -C "$D/.." pull -q
if [ -d "$D/../clusters/dr/flux-system" ]; then
  git -C "$D/.." rm -rq clusters/dr/flux-system
  git -C "$D/.." commit -qm "reset dr for demo"
  git -C "$D/.." push -q
fi

"$D/02-clusters.sh" both
"$D/03-prep-cluster.sh" prod
"$D/04-bootstrap.sh" prod
"$D/05-seed-and-backup.sh"
"$D/03-prep-cluster.sh" dr
"$D/06-warm-dr.sh"
kubectl config use-context kind-prod
echo "Ready for the demo: ./scripts/demo.sh"
