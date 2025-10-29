# Salt Stack Syndic Demo (k3d + Argo CD)

This project spins up the hybrid SaltStack topology you described (cloud master → panel PC syndic → worker) inside a local [k3d](https://k3d.io/) Kubernetes cluster. Argo CD declaratively owns the desired `saltenv` commit and reconciles the panel PC and worker pods. All Salt daemons run in containers built from this repository.

## Components
- **git-server (Deployment)** – Seeds and serves the `salt-states.git` bare repository containing Salt states, pillars, and the Kubernetes manifests in `salt-states-repo/`.
- **cloud-master (Deployment)** – Cloud salt-master that checks out the commit declared by Argo CD and exposes the standard 4505/4506 ports inside the cluster.
- **panelpc (Deployment managed by Argo CD)** – Runs a local salt-master + syndic + minion. It pulls the repo at the commit Argo declares and forwards jobs/results upstream.
- **worker (Deployment managed by Argo CD)** – Plain salt-minion managed by the panel PC master.
- **Argo CD Application** – Points at this repository (or your fork) and reconciles `k8s/base`, which holds the panelpc/worker deployments, the git server, cloud master, and the GitOps commit ConfigMap.

Each Salt container reads the desired commit from the `salt-gitops` ConfigMap (`data.commit`) before starting, ensuring Argo CD dictates the `saltenv` revision end-to-end. The ConfigMap is generated with a hash suffix so that changing the commit automatically rolls the workloads.

## Repository Layout
```
argocd/                    # Argo CD Application manifest (update repoURL before applying)
cloud-master/              # Cloud master Dockerfile + entrypoint
panelpc/                   # Panel PC (master + syndic + minion)
worker/                    # Worker minion
git-server/                # Bare git repo seed + daemon entrypoint
salt-states-repo/          # Salt states, pillars, and Kubernetes manifests (seeded into git-server image)
  └── k8s/                 # Kustomize base reconciled by Argo CD
docker-compose.yml         # Convenience for building images locally
```

## Prerequisites
- Docker Engine 24+
- Docker Compose v2 (optional but convenient for building)
- `kubectl`
- `k3d`
- Argo CD CLI (`argocd`, optional but handy for port-forwarding and sync operations)

## 1. Build the Container Images
Use Compose to build everything in one go (or run `docker build` per directory):
```sh
docker compose build
```
This produces the tagged images used inside the cluster:
`git-server:latest`, `cloud-master:latest`, `panelpc:latest`, and `worker:latest`.

## 2. Create a k3d Cluster and Load Images
```sh
k3d cluster create salt-demo --agents 1 --servers 1
k3d image import git-server:latest cloud-master:latest panelpc:latest worker:latest -c salt-demo
```
> If you rerun the build, re-import the images so Kubernetes can pull the latest layers.

## 3. Install Argo CD
```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
Wait until all pods in `argocd` are ready:
```sh
kubectl get pods -n argocd
```

## 4. Update the Argo Application Manifest
Edit `argocd/application.yaml` and set `spec.source.repoURL` to the git remote that hosts this repository (for example your GitHub fork). Commit and push so Argo CD can reach it. The repo must contain the `salt-states-repo/` directory because the git-server image seeds from it.

## 5. Bootstrap the Stack Through Argo CD
Apply the Application manifest and let Argo sync:
```sh
kubectl apply -f argocd/application.yaml -n argocd
```
(Optional) Port-forward the Argo API/server if you want to watch the UI:
```sh
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd login https://localhost:8080 --username admin --password <initial-password>
```
When the Application syncs you should see pods for `git-server`, `cloud-master`, `panelpc`, and `worker` in the `salt-demo` namespace.

## 6. Verify the Salt Chain
- Check pod status:
  ```sh
  kubectl get pods -n salt-demo
  ```
- Inspect the commit Argo declared (ConfigMap value):
  ```sh
  kubectl get configmap -n salt-demo \
    -l app.kubernetes.io/name=salt-gitops \
    -o jsonpath='{.items[0].data.commit}' && echo
  ```
- Confirm the worker picked up the commit:
  ```sh
  kubectl exec -n salt-demo deploy/worker -c worker -- cat /etc/demo/worker-status.txt
  ```
  You should see the same commit hash in the file contents.
- Run a quick Salt ping from the cloud master:
  ```sh
  kubectl exec -n salt-demo deploy/cloud-master -c cloud-master -- salt '*' test.ping
  ```

## Changing the Desired Commit
1. Edit `salt-states-repo/k8s/base/gitops-commit.env` and set `commit=<desired-git-sha>`.
2. Commit and push the change.
3. Argo CD notices the update, syncs the ConfigMap (producing a new hash), and Kubernetes performs a rolling restart of the Salt deployments with the new `saltenv`.

## Cleanup
```sh
k3d cluster delete salt-demo
```
This tears down the cluster and frees resources. Optionally remove the locally built images with `docker image rm` if you no longer need them.

## Optional: Local Docker Compose Run
`docker-compose.yml` still defines the same containers for ad-hoc local execution. Set `GITOPS_COMMIT` (and optionally expose ports) if you want to run without Kubernetes.

---
Feel free to extend the Salt states in `salt-states-repo/salt/`, add additional minions, or integrate real application workloads that consume the Salt-managed files.
