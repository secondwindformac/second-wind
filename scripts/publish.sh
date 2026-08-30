#!/usr/bin/env bash
# Publishes Second Wind to GitHub as the user's PRIVATE repository.
# Developer step (not part of the installer).
# Needs: the administrator password (to install GitHub CLI the first time)
# and completing the GitHub sign-in in the browser.
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/common.sh

REPO_NAME="second-wind"
DESCRIPTION="A second wind for your old Mac — one-click macOS experience for Ubuntu on Macs Apple left behind"

if ! command -v gh >/dev/null 2>&1; then
  info "${MSG[pub_gh]}"
  sudo apt-get update -qq
  sudo apt-get install -y gh
fi

if ! gh auth status >/dev/null 2>&1; then
  info "${MSG[pub_login]}"
  gh auth login --web --git-protocol https
fi

if git remote get-url origin >/dev/null 2>&1; then
  # Repository already published. If it still carries the old project name,
  # rename it on GitHub (old URLs redirect automatically).
  current="$(gh repo view --json name -q .name 2>/dev/null || echo "")"
  if [ -n "$current" ] && [ "$current" != "$REPO_NAME" ]; then
    gh repo rename "$REPO_NAME" --yes
    git remote set-url origin "$(gh repo view --json url -q .url).git"
  fi
  gh repo edit --description "$DESCRIPTION" >/dev/null 2>&1 || true
else
  info "${MSG[pub_create]}"
  gh repo create "$REPO_NAME" --private --source=. --remote=origin \
    --description "$DESCRIPTION"
fi

git push -u origin main
echo
ok "${MSG[pub_done]} $(gh repo view --json url -q .url)"
echo "${MSG[pub_hint]}"
