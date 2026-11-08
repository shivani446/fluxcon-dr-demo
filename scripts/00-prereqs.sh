#!/usr/bin/env bash
# One-time: CLI tools, kernel limits, and the NFS-server check. Run inside WSL (Ubuntu).
set -euo pipefail
source "$(dirname "$0")/env.sh"

echo "==> apt packages"
sudo apt-get update -y
sudo apt-get install -y curl jq git nfs-kernel-server nfs-common

ARCH=amd64
BIN=/usr/local/bin

if ! command -v kubectl >/dev/null; then
  echo "==> kubectl"
  V=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${V}/bin/linux/${ARCH}/kubectl"
  sudo install -m 0755 /tmp/kubectl "$BIN/kubectl"
fi

if ! command -v kind >/dev/null; then
  echo "==> kind"
  V=$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r .tag_name)
  curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/${V}/kind-linux-${ARCH}"
  sudo install -m 0755 /tmp/kind "$BIN/kind"
fi

if ! command -v flux >/dev/null; then
  echo "==> flux"
  curl -fsSL https://fluxcd.io/install.sh | sudo bash
fi

if ! velero version --client-only 2>/dev/null | grep -q "${VELERO_VERSION}"; then
  echo "==> velero ${VELERO_VERSION}"
  curl -fsSLo /tmp/velero.tgz "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-${ARCH}.tar.gz"
  tar -xzf /tmp/velero.tgz -C /tmp
  sudo install -m 0755 "/tmp/velero-${VELERO_VERSION}-linux-${ARCH}/velero" "$BIN/velero"
fi

echo "==> inotify limits (two kind clusters need more)"
sudo tee /etc/sysctl.d/99-kind.conf >/dev/null <<'EOF'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF
sudo sysctl --system >/dev/null

echo "==> checks"
docker info >/dev/null || { echo "Docker is not running in WSL. Start it: sudo service docker start"; exit 1; }
[ "$(ps -p 1 -o comm=)" = "systemd" ] || echo "WARN: systemd is off. Add [boot] systemd=true to /etc/wsl.conf, then 'wsl --shutdown' from Windows."
sudo modprobe nfsd 2>/dev/null || true
if grep -q nfsd /proc/filesystems; then
  echo "OK: kernel NFS server is available in this WSL kernel"
else
  echo "STOP: this WSL kernel has no NFS server (nfsd). Tell Claude: we'll switch to the fallback."
  exit 1
fi

kubectl version --client | head -1; kind version; flux version --client; velero version --client-only
echo "Prereqs done."
