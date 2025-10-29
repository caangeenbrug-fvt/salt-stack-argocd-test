#!/usr/bin/env python3
import os
import subprocess
import sys
import time
from pathlib import Path

import yaml

APPLICATION_PATH = Path(os.environ.get("APPLICATION_PATH", "/config/application.yaml"))
WORK_DIR = Path(os.environ.get("ARGO_WORKDIR", "/gitops/worktree"))
STATE_DIR = Path(os.environ.get("ARGO_STATE_DIR", "/gitops/state"))
COMMIT_FILE = STATE_DIR / "commit.sha"
TIMESTAMP_FILE = STATE_DIR / "synced.timestamp"
RECONCILE_SECONDS = int(os.environ.get("RECONCILE_SECONDS", "10"))


def log(message: str) -> None:
    print(f"[argocd] {message}", flush=True)


def run_git(args, check=True):
    cmd = ["git"] + args
    log("Running: " + " ".join(cmd))
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and result.returncode != 0:
        log(result.stdout)
        log(result.stderr)
        raise subprocess.CalledProcessError(result.returncode, cmd)
    return result


def ensure_directories():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)


def load_application():
    with APPLICATION_PATH.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    spec = data["spec"]
    source = spec["source"]
    return source["repoURL"], source["targetRevision"], source.get("path", ".")


def ensure_clone(repo_url: str):
    if (WORK_DIR / ".git").exists():
        run_git(["-C", str(WORK_DIR), "remote", "set-url", "origin", repo_url])
        run_git(["-C", str(WORK_DIR), "fetch", "origin"])
    else:
        run_git(["clone", repo_url, str(WORK_DIR)])


def checkout_revision(target_rev: str) -> str:
    run_git(["-C", str(WORK_DIR), "fetch", "origin"])
    rev = run_git(["-C", str(WORK_DIR), "rev-parse", f"origin/{target_rev}"]).stdout.strip()
    run_git(["-C", str(WORK_DIR), "checkout", rev])
    return rev


def write_commit(commit: str):
    tmp = COMMIT_FILE.with_suffix(".tmp")
    tmp.write_text(commit + "\n", encoding="utf-8")
    tmp.replace(COMMIT_FILE)
    TIMESTAMP_FILE.write_text(str(int(time.time())), encoding="utf-8")
    log(f"Synced commit {commit}")


def main():
    ensure_directories()
    last_commit = COMMIT_FILE.read_text(encoding="utf-8").strip() if COMMIT_FILE.exists() else None
    while True:
        try:
            repo_url, target_rev, _ = load_application()
        except FileNotFoundError:
            log("Waiting for application manifest")
            time.sleep(RECONCILE_SECONDS)
            continue
        except Exception as exc:  # pragma: no cover - diagnostics
            log(f"Failed to read application manifest: {exc}")
            time.sleep(RECONCILE_SECONDS)
            continue

        try:
            ensure_clone(repo_url)
            commit = checkout_revision(target_rev)
        except subprocess.CalledProcessError as exc:
            log(f"Git error while syncing {target_rev}: {exc}")
            time.sleep(RECONCILE_SECONDS)
            continue

        if commit != last_commit:
            write_commit(commit)
            last_commit = commit
        time.sleep(RECONCILE_SECONDS)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
