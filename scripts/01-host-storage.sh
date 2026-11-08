#!/usr/bin/env bash
# NFS server (WSL kernel) + MinIO bucket (Docker). Both live OUTSIDE the clusters.
set -euo pipefail
source "$(dirname "$0")/env.sh"

echo "==> NFS exports: $NFS_ROOT/prod and $NFS_ROOT/dr"
sudo mkdir -p "$NFS_ROOT/prod" "$NFS_ROOT/dr"
sudo chmod 777 "$NFS_ROOT/prod" "$NFS_ROOT/dr"
sudo tee /etc/exports >/dev/null <<EOF
$NFS_ROOT/prod 172.16.0.0/12(rw,sync,no_subtree_check,no_root_squash,insecure)
$NFS_ROOT/dr   172.16.0.0/12(rw,sync,no_subtree_check,no_root_squash,insecure)
EOF
sudo systemctl enable --now nfs-kernel-server 2>/dev/null || sudo service nfs-kernel-server start
sudo exportfs -ra
sudo exportfs -v

echo "==> MinIO on :9000 (console :9001)"
if ! docker ps --format '{{.Names}}' | grep -qx minio; then
  docker rm -f minio >/dev/null 2>&1 || true
  docker run -d --name minio --restart unless-stopped \
    -p 9000:9000 -p 9001:9001 \
    -e MINIO_ROOT_USER="$MINIO_USER" -e MINIO_ROOT_PASSWORD="$MINIO_PASS" \
    -v "$DEMO_HOME/minio-data:/data" \
    minio/minio server /data --console-address ":9001"
  sleep 5
fi
docker run --rm --network host --entrypoint sh minio/mc -c \
  "mc alias set local http://127.0.0.1:9000 $MINIO_USER $MINIO_PASS >/dev/null && mc mb --ignore-existing local/velero && mc ls local"

echo "==> Velero credentials file (kept outside Git): $DEMO_HOME/credentials-velero"
cat > "$DEMO_HOME/credentials-velero" <<EOF
[default]
aws_access_key_id=$MINIO_USER
aws_secret_access_key=$MINIO_PASS
EOF
chmod 600 "$DEMO_HOME/credentials-velero"
echo "Host storage ready."
