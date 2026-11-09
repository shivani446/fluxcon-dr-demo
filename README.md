# FluxCon DR demo: Flux + Velero + NFS CSI on kind

Two kind clusters (`prod`, `dr`) in . NFS server and MinIO run on the shell host, outside both clusters.
Flux installs csi-driver-nfs and Velero (Kopia file-system backup); Postgres runs on an `nfs-csi` PVC.

```
clusters/{prod,dr}/          Flux Kustomizations: infra-controllers -> infra-configs -> apps
infrastructure/controllers/  csi-driver-nfs + Velero HelmReleases (BSL in Velero values)
infrastructure/configs/      nfs-csi StorageClass + Velero Schedule; prod/dr pick the NFS share
apps/                        Postgres (demo namespace)
scripts/                     setup, demo driver, reset
```

Kept **outside Git** (in `~/dr-demo`): MinIO credentials, host IP. `03-prep-cluster.sh` puts them in each cluster before bootstrap.

## 1. One-time setup (Windows side)

1. Give shell enough RAM. In `C:\Users\<you>\.shellconfig`:
   ```
   [shell2]
   memory=10GB
   processors=4
   ```
2. Enable systemd in shell. In `/etc/shell.conf`:
   ```
   [boot]
   systemd=true
   ```
3. From PowerShell: `shell --shutdown`, then reopen Ubuntu.

## 2. One-time setup

```bash
# GitHub: create an empty private repo named fluxcon-dr-demo, then:
cd fluxcon-dr-demo
git init -b main && git add . && git commit -m "demo repo"
git remote add origin git@github.com:<you>/fluxcon-dr-demo.git && git push -u origin main

# edit GITHUB_USER in scripts/env.sh
export GITHUB_TOKEN=<classic PAT with 'repo' scope>

./scripts/00-prereqs.sh          # tools + checks; must print "OK: kernel NFS server"
./scripts/01-host-storage.sh     # NFS exports /srv/nfs/{prod,dr} + MinIO bucket 'velero'
./scripts/02-clusters.sh both    # kind prod + dr, saves HOST_IP
./scripts/03-prep-cluster.sh prod
./scripts/04-bootstrap.sh prod   # 3-5 min first time
./scripts/05-seed-and-backup.sh  # rows in Postgres + backup 'demo-pre-disaster'
./scripts/03-prep-cluster.sh dr
./scripts/06-warm-dr.sh          # preload images into dr so the live bootstrap is fast
```

Check: `flux get kustomizations` all Ready on prod, `velero backup get` shows `demo-pre-disaster` Completed.
MinIO console: http://localhost:9001.

## 3. Rehearse

```bash
./scripts/demo.sh    # press Enter for each command
./scripts/reset.sh   # back to pre-demo state (~10 min)
```

Time it. Target: 8 minutes. Record one clean run (OBS) as the fallback video.

## 4. Talk night (10 Nov, slot 12:55 am IST)

- [ ] 11:00 pm: `export GITHUB_TOKEN=...` then `./scripts/reset.sh`
- [ ] `sudo -v` right before the talk (the demo runs one `sudo rm`)
- [ ] `kubectl config current-context` shows `kind-prod`
- [ ] Terminal font 20pt+, dark theme, notifications off
- [ ] Second laptop: joined to the speaker link as backup, with the fallback recording open
- [ ] Phone hotspot ready (bootstrap needs GitHub)

## Demo beats (scripts/demo.sh)

| # | Beat | Key command |
|---|------|-------------|
| 1 | Healthy prod | `flux get kustomizations`, `SELECT * FROM orders` |
| 2 | Backup exists | `velero schedule get`, `velero backup get` |
| 3 | Disaster | `kind delete cluster --name prod`, wipe `/srv/nfs/prod` |
| 4 | Rebuild | `04-bootstrap.sh dr`, wait for apps, `velero backup get` |
| 5 | The trap | apps Ready, `SELECT` fails (empty DB) |
| 6 | Restore | `flux suspend` -> delete ns -> `velero restore create` -> `flux resume` |
| 7 | Proof | same rows on dr |

## Troubleshooting

| Symptom | Check |
|---|---|
| PVC Pending | `sudo exportfs -v`; `kubectl -n flux-system get cm cluster-vars -o yaml` (HOST_IP = kind network gateway) |
| Postgres `permission denied` | exports need `no_root_squash` (01 script sets it) |
| BSL `Unavailable` | `docker ps` (minio up?), `kubectl -n velero logs deploy/velero` |
| Backups not on dr | wait 10s (sync period), `velero backup-location get` |
| Restore `PartiallyFailed` | `velero restore describe <name> --details`, `velero restore logs <name>` |
| `00-prereqs` says no nfsd | stop and ask: switch to the fallback NFS setup |
