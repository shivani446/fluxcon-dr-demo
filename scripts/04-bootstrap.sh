#!/usr/bin/env bash
# Flux bootstrap. Needs GITHUB_TOKEN exported. Usage: 04-bootstrap.sh prod|dr
set -euo pipefail
source "$(dirname "$0")/env.sh"
C="${1:?usage: $0 prod|dr}"
: "${GITHUB_TOKEN:?export GITHUB_TOKEN first}"
kubectl config use-context "kind-$C"
flux bootstrap github \
  --owner="$GITHUB_USER" \
  --repository="$REPO" \
  --branch=main \
  --path="clusters/$C" \
  --personal
flux get kustomizations
