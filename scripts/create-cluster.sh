#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CONFIG_FILE="${REPO_ROOT}/k3d/cluster.yaml"
IMAGES=(git-server:latest cloud-master:latest panelpc:latest worker:latest)

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "[k3d] Cluster config not found at ${CONFIG_FILE}" >&2
  exit 1
fi

CONFIG_NAME=$(awk '/^metadata:/{flag=1; next} flag && $1=="name:" {print $2; exit}' "${CONFIG_FILE}")
CLUSTER_NAME=${CONFIG_NAME:-salt-demo}

if ! command -v k3d >/dev/null 2>&1; then
  echo "[k3d] k3d binary not found. Install k3d before running this script." >&2
  exit 1
fi

if [ "${SKIP_BUILD:-0}" -ne 1 ]; then
  COMPOSE_FILE="${REPO_ROOT}/docker-compose.yml"
  if [ -f "${COMPOSE_FILE}" ]; then
    if command -v docker >/dev/null 2>&1; then
      if docker compose version >/dev/null 2>&1; then
        echo "[k3d] Building images with docker compose" >&2
        sudo docker compose -f "${COMPOSE_FILE}" build
      elif command -v docker-compose >/dev/null 2>&1; then
        echo "[k3d] Building images with docker-compose" >&2
        sudo docker-compose -f "${COMPOSE_FILE}" build
      else
        echo "[k3d] Docker Compose not found; skipping image build" >&2
      fi
    else
      echo "[k3d] Docker CLI not found; skipping image build" >&2
    fi
  fi
fi

existing_clusters=$(k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}')
if printf '%s\n' "${existing_clusters}" | grep -qx "${CLUSTER_NAME}"; then
  echo "[k3d] Cluster ${CLUSTER_NAME} already exists. Skipping creation." >&2
else
  echo "[k3d] Creating cluster ${CLUSTER_NAME} from ${CONFIG_FILE}" >&2
  sudo k3d cluster create --config "${CONFIG_FILE}"
fi

for image in "${IMAGES[@]}"; do
  if docker image inspect "${image}" >/dev/null 2>&1; then
    echo "[k3d] Importing ${image} into cluster ${CLUSTER_NAME}" >&2
    sudo k3d image import "${image}" -c "${CLUSTER_NAME}" >/dev/null
  else
    echo "[k3d] Skipping ${image}; image not found locally" >&2
  fi
done

echo "[k3d] Cluster ${CLUSTER_NAME} is ready." >&2
