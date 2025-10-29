#!/bin/sh
set -eu
COMMIT_FILE=${COMMIT_FILE:-/gitops/state/commit.sha}
GIT_REMOTE=${GIT_REMOTE:-git://git-server/salt-states.git}
REPO_DIR=${REPO_DIR:-/srv/gitops}
SALT_STATE_DIR="$REPO_DIR/salt"
SALT_PILLAR_DIR="$REPO_DIR/pillar"
TEMPLATE_PILLAR="$SALT_PILLAR_DIR/gitops.sls"

wait_for_file() {
  file="$1"
  while [ ! -f "$file" ]; do
    echo "[cloud-master] Waiting for $file" >&2
    sleep 2
  done
}

sync_repo() {
  commit="$1"
  if [ ! -d "$REPO_DIR/.git" ]; then
    echo "[cloud-master] Cloning $GIT_REMOTE" >&2
    git clone "$GIT_REMOTE" "$REPO_DIR"
  else
    echo "[cloud-master] Fetching latest refs" >&2
    git -C "$REPO_DIR" fetch origin
  fi
  git -C "$REPO_DIR" checkout "$commit"
}

update_pillar_commit() {
  commit="$1"
  if [ -f "$TEMPLATE_PILLAR" ]; then
    sed -i "s/^\(\s*commit:\s*\).*/\1$commit/" "$TEMPLATE_PILLAR"
  fi
}

write_master_config() {
  mkdir -p /etc/salt/master.d
  cat <<CONF > /etc/salt/master.d/gitops.conf
auto_accept: True
file_roots:
  base:
    - $SALT_STATE_DIR
pillar_roots:
  base:
    - $SALT_PILLAR_DIR
open_mode: True
CONF
}

wait_for_file "$COMMIT_FILE"
COMMIT=$(cat "$COMMIT_FILE")

sync_repo "$COMMIT"
update_pillar_commit "$COMMIT"
write_master_config

echo "[cloud-master] Starting salt-master for commit $COMMIT"
exec salt-master -l info
