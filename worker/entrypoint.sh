#!/bin/sh
set -eu
COMMIT_FILE=${COMMIT_FILE:-/gitops/state/commit.sha}
GITOPS_COMMIT=${GITOPS_COMMIT:-}
PANEL_MASTER=${PANEL_MASTER:-panelpc}
WORKER_ID=${WORKER_ID:-worker}

wait_for_file() {
  file="$1"
  while [ ! -f "$file" ]; do
    echo "[worker] Waiting for $file" >&2
    sleep 2
  done
}

configure_minion() {
  commit="$1"
  mkdir -p /etc/salt/minion.d
  cat <<CONF > /etc/salt/minion.d/master.conf
master: $PANEL_MASTER
id: ${WORKER_ID}-minion
environment: base
CONF
  cat <<CONF > /etc/salt/grains
roles:
  - worker
panel_master: $PANEL_MASTER
gitops_commit: $commit
CONF
}

if [ -n "$GITOPS_COMMIT" ]; then
  COMMIT="$GITOPS_COMMIT"
else
  wait_for_file "$COMMIT_FILE"
  COMMIT=$(cat "$COMMIT_FILE")
fi
configure_minion "$COMMIT"

echo "[worker] Starting salt-minion for commit $COMMIT"
exec salt-minion -l info
