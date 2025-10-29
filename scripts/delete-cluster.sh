#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CONFIG_FILE="${REPO_ROOT}/k3d/cluster.yaml"

CONFIG_NAME=""
if [ -f "${CONFIG_FILE}" ]; then
  CONFIG_NAME=$(awk '/^metadata:/{flag=1; next} flag && $1=="name:" {print $2; exit}' "${CONFIG_FILE}")
fi

CLUSTER_NAME=${CONFIG_NAME:-salt-demo}

if ! command -v k3d >/dev/null 2>&1; then
  echo "[k3d] k3d binary not found. Install k3d before running this script." >&2
  exit 1
fi

clusters=$(sudo k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}')
if printf '%s\n' "${clusters}" | grep -qx "${CLUSTER_NAME}"; then
  echo "[k3d] Deleting cluster ${CLUSTER_NAME}" >&2
  sudo k3d cluster delete "${CLUSTER_NAME}" >/dev/null
  echo "[k3d] Cluster ${CLUSTER_NAME} removed." >&2
else
  echo "[k3d] Cluster ${CLUSTER_NAME} not found." >&2
fi
