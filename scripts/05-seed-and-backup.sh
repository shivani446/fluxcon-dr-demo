#!/usr/bin/env bash
# Put real rows in Postgres on prod, then take the pre-disaster backup.
set -euo pipefail
source "$(dirname "$0")/env.sh"
kubectl config use-context kind-prod

echo "==> waiting for Flux + Postgres"
flux reconcile kustomization apps --with-source >/dev/null 2>&1 || true
kubectl wait kustomization/apps -n flux-system --for=condition=Ready --timeout=10m
kubectl -n demo rollout status deploy/postgres --timeout=5m

echo "==> seeding orders"
kubectl -n demo exec deploy/postgres -- psql -U app -d app -v ON_ERROR_STOP=1 -c "
CREATE TABLE IF NOT EXISTS orders (id serial PRIMARY KEY, customer text, item text, created_at timestamptz DEFAULT now());
TRUNCATE orders;
INSERT INTO orders (customer, item) VALUES
  ('salt-lake-city', 'kubernetes-stickers'),
  ('rajkot',         'flux-tshirt'),
  ('ahmedabad',      'velero-mug'),
  ('fluxcon-2026',   'disaster-recovery-plan');
SELECT * FROM orders;"

echo "==> waiting for Velero BackupStorageLocation"
for i in $(seq 1 60); do
  [ "$(kubectl -n velero get bsl default -o jsonpath='{.status.phase}' 2>/dev/null)" = "Available" ] && break
  sleep 5
done
velero backup-location get

echo "==> backup $BACKUP_NAME"
velero backup delete "$BACKUP_NAME" --confirm >/dev/null 2>&1 || true
sleep 5
velero backup create "$BACKUP_NAME" --include-namespaces demo --default-volumes-to-fs-backup --wait
velero backup describe "$BACKUP_NAME" --details | sed -n '1,60p'
