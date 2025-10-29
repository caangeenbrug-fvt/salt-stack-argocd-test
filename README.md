# Salt Stack Syndic Demo

This repository packages a reproducible demo of the hybrid SaltStack architecture you described. Everything runs locally with Docker Compose so you can see how a cloud Salt master, ArgoCD-driven GitOps workflow, a panel PC syndic, and a downstream worker minion interact end-to-end.

## Components
- **git-server**: Minimal git daemon that seeds the `salt-states` repository with example Salt states and pillar data.
- **argocd**: Lightweight controller that reads `argocd/application.yaml`, resolves the requested `targetRevision`, and writes the resolved commit hash into a shared volume (`/gitops/state/commit.sha`). Other services wait for this file so no Salt process starts before ArgoCD declares the desired revision.
- **cloud-master**: Salt master that clones the repo at the commit selected by ArgoCD, rewrites the pillar with that commit, and serves it to downstream masters/minions.
- **panelpc**: Simulated on-prem panel PC that acts as a lower Salt master, syndic, and minion. It mirrors the repo at the declared commit and forwards jobs/results to the cloud master.
- **worker**: Salt minion connected to the panel PC master representing the sorting line worker node.

All services share the `gitops-data` Docker volume so they can read the synchronized commit metadata from ArgoCD.

## File Layout
```
argocd/                # ArgoCD controller container (application manifest + reconciler)
cloud-master/          # Cloud master container definition and bootstrap script
git-server/            # Git daemon container with seed repository
panelpc/               # Panel PC (master + syndic + minion) container
worker/                # Worker minion container
salt-states-repo/      # Salt states and pillar that seed the git repository
docker-compose.yml     # Brings the full stack up locally
```

## Prerequisites
- Docker Engine 24+
- Docker Compose v2 plugin (`docker compose` CLI)

## Running the Demo
1. Build the images (only needed once or after changes):
   ```sh
   docker compose build
   ```
2. Start the full environment:
   ```sh
   docker compose up
   ```
   The order is orchestrated so that:
   - `git-server` starts and seeds the repository.
   - `argocd` resolves `spec.source.targetRevision` to an exact commit and writes it to `/gitops/state/commit.sha`.
   - `cloud-master`, `panelpc`, and `worker` block until that commit file exists, ensuring ArgoCD has declared the saltenv commit before Salt services launch.

Once everything is healthy you should see the panel and worker minions connect (log lines similar to `salt-minion ... [INFO] Minion ... is ready`).

## Observing the Workflow
- Inspect the resolved commit:
  ```sh
  docker compose exec argocd cat /gitops/state/commit.sha
  ```
- Confirm the cloud master serving that revision:
  ```sh
  docker compose exec cloud-master salt-run manage.status
  ```
- Check that the worker applied the state rendered with the commit from pillar:
  ```sh
  docker compose exec worker cat /etc/demo/worker-status.txt
  ```
  The file includes the commit hash injected by the cloud master during startup.

## Changing the Desired Commit
1. Update `argocd/application.yaml` and set `spec.source.targetRevision` to another commit, tag, or branch (a literal commit hash satisfies the “ArgoCD holds the saltenv commit” requirement).
2. Rebuild or restart the `argocd` container so it reconciles the new value:
   ```sh
   docker compose restart argocd
   ```
3. Restart the Salt services so they pick up the new commit and rewrite their configs:
   ```sh
   docker compose restart cloud-master panelpc worker
   ```

## Cleanup
Stop and remove containers:
```sh
docker compose down
```
Add `-v` to also remove the shared `gitops-data` volume if you want a clean slate.

## Extending the Demo
- Drop additional states or pillars into `salt-states-repo/`, rebuild the `git-server` image, and the next run will seed them automatically.
- Point `argocd/application.yaml` at an external repository to test real Git hosting instead of the bundled seed.
- Layer additional services (e.g., application containers) that depend on the Salt-managed files to simulate a full production rollout.
