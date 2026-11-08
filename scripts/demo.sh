#!/usr/bin/env bash
# Live demo driver. Press Enter to run each command; Ctrl+C to stop.
# Prereq: prod running with backup, dr cluster created + prepped (03) + warmed (06), NOT bootstrapped.
source "$(dirname "$0")/env.sh"
BOLD=$'\e[1m'; CYAN=$'\e[36m'; YEL=$'\e[33m'; RST=$'\e[0m'
beat() { echo; echo "${YEL}### $*${RST}"; }
run()  { echo; printf '%s$ %s%s' "$CYAN$BOLD" "$*" "$RST"; read -r _; eval "$@"; }
SQL='kubectl -n demo exec deploy/postgres -- psql -U app -d app -c "SELECT * FROM orders;"'
clear

beat "1. Healthy prod"
run kubectl config use-context kind-prod
run flux get kustomizations
run "$SQL"

beat "2. The backup Git never had"
run velero schedule get
run velero backup get

beat "3. Disaster"
run kind delete cluster --name prod
run "sudo rm -rf $NFS_ROOT/prod/*"
run kubectl get nodes

beat "4. Rebuild with Flux"
run kubectl config use-context kind-dr
run "$(dirname "$0")/04-bootstrap.sh dr"
run kubectl -n flux-system wait kustomization/apps --for=condition=Ready --timeout=10m
run flux get kustomizations
run velero backup get

beat "5. The trap: Ready, but empty"
run flux get kustomizations
run "$SQL"

beat "6. Restore the right way"
run flux suspend kustomization apps
run kubectl delete namespace demo --wait
run velero restore create --from-backup "$BACKUP_NAME" --include-namespaces demo --wait
run flux resume kustomization apps

beat "7. Proof"
run kubectl -n demo rollout status deploy/postgres --timeout=3m
run "$SQL"
run flux get kustomizations
echo; echo "${BOLD}Back to slides.${RST}"
