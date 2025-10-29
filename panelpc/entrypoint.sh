#!/bin/sh
set -eu
COMMIT_FILE=${COMMIT_FILE:-/gitops/state/commit.sha}
GIT_REMOTE=${GIT_REMOTE:-git://git-server/salt-states.git}
REPO_DIR=${REPO_DIR:-/srv/gitops}
SALT_STATE_DIR="$REPO_DIR/salt"
SALT_PILLAR_DIR="$REPO_DIR/pillar"
PILLAR_FILE="$SALT_PILLAR_DIR/gitops.sls"
PANEL_ID=${PANEL_ID:-panelpc}
CLOUD_MASTER=${CLOUD_MASTER:-cloud-master}

wait_for_file() {
  file="$1"
  while [ ! -f "$file" ]; do
    echo "[panelpc] Waiting for $file" >&2
    sleep 2
  done
}

sync_repo() {
  commit="$1"
  if [ ! -d "$REPO_DIR/.git" ]; then
    echo "[panelpc] Cloning $GIT_REMOTE" >&2
    git clone "$GIT_REMOTE" "$REPO_DIR"
  else
    echo "[panelpc] Fetching latest refs" >&2
    git -C "$REPO_DIR" fetch origin
  fi
  git -C "$REPO_DIR" checkout "$commit"
}

update_pillar_commit() {
  commit="$1"
  if [ -f "$PILLAR_FILE" ]; then
    sed -i "s/^\(\s*commit:\s*\).*/\1$commit/" "$PILLAR_FILE"
  fi
}

configure_master() {
  mkdir -p /etc/salt/master.d
  cat <<CONF > /etc/salt/master.d/gitops.conf
auto_accept: True
syndic_master: $CLOUD_MASTER
file_roots:
  base:
    - $SALT_STATE_DIR
pillar_roots:
  base:
    - $SALT_PILLAR_DIR
open_mode: True
CONF
}

configure_minion() {
  mkdir -p /etc/salt/minion.d
  cat <<CONF > /etc/salt/minion.d/local.conf
master: localhost
id: ${PANEL_ID}-minion
environment: base
CONF
  cat <<CONF > /etc/salt/grains
roles:
  - panel
panel_master: $PANEL_ID
syndic_master: $CLOUD_MASTER
CONF
}

wait_for_file "$COMMIT_FILE"
COMMIT=$(cat "$COMMIT_FILE")

sync_repo "$COMMIT"
update_pillar_commit "$COMMIT"
configure_master
configure_minion

echo "[panelpc] Starting services for commit $COMMIT"
salt-master -l info -d
salt-syndic -l info -d
exec salt-minion -l info
