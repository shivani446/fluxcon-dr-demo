# Shared settings. Edit GITHUB_USER and REPO, then `source scripts/env.sh`.
export GITHUB_USER="${GITHUB_USER:-shivani446}"
export REPO="${REPO:-fluxcon-dr-demo}"
export DEMO_HOME="$HOME/dr-demo"          # things kept OUTSIDE Git (keys, creds)
export NFS_ROOT="/srv/nfs"
export MINIO_USER="minioadmin"
export MINIO_PASS="minioadmin-fluxcon"
export VELERO_VERSION="v1.18.0"
export BACKUP_NAME="demo-pre-disaster"
mkdir -p "$DEMO_HOME"
export KUBECONFIG="$HOME/dr-demo/kubeconfig"
