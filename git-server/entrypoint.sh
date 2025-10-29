#!/bin/sh
set -eu
REPO_DIR=/srv/git
REPO_NAME=salt-states.git
REPO_PATH="$REPO_DIR/$REPO_NAME"
SEED_DIR=/seed

mkdir -p "$REPO_DIR"

if [ ! -d "$REPO_PATH" ]; then
  echo "[git-server] Seeding salt state repository"
  git init --bare "$REPO_PATH"
  tmpdir=$(mktemp -d)
  git clone "$REPO_PATH" "$tmpdir/work"
  cp -R "$SEED_DIR"/. "$tmpdir/work/"
  (cd "$tmpdir/work" && \
    git config user.name "Seed" && \
    git config user.email "seed@example.com" && \
    git add . && \
    git commit -m "Initial salt state commit" && \
    git branch -M main && \
    git push origin main)
  git --git-dir="$REPO_PATH" symbolic-ref HEAD refs/heads/main
  rm -rf "$tmpdir"
fi

echo "[git-server] Serving $REPO_NAME on git://0.0.0.0:9418"
exec git daemon \
  --base-path="$REPO_DIR" \
  --export-all \
  --enable=receive-pack \
  --reuseaddr \
  --verbose \
  --listen=0.0.0.0 \
  --port=9418
