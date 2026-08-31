#!/usr/bin/env bash
# Publishes Second Wind to GitHub (public repository) and cuts releases.
# Developer step (not part of the installer).
#
#   ./scripts/publish.sh                  push main (creates the repo the first time)
#   ./scripts/publish.sh --release 1.0.0  tag + payload tarball + SHA-256 checksums
#                                         published as a GitHub release
#
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

# --- Release mode: tarball of the exact commit + SHA-256 checksums ---------
if [ "${1:-}" = "--release" ]; then
  version="${2:-}"
  [[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
    echo "Usage: ./scripts/publish.sh --release X.Y.Z" >&2; exit 1; }
  tag="v$version"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    warn "${MSG[pub_tag_exists]} ($tag)"; exit 1
  fi

  out="$(mktemp -d)"
  tarball="second-wind-$version.tar.gz"
  # Archive of the exact released commit — same mechanism the USB payload uses.
  git archive --format=tar.gz --prefix="second-wind/" -o "$out/$tarball" HEAD
  (cd "$out" && sha256sum "$tarball" > SHA256SUMS)
  info "${MSG[pub_sums]}"
  cat "$out/SHA256SUMS"

  git tag -a "$tag" -m "Second Wind $version"
  git push origin main "$tag"
  gh release create "$tag" "$out/$tarball" "$out/SHA256SUMS" \
    --verify-tag --title "Second Wind $version" --generate-notes
  rm -rf "$out"
  echo
  ok "${MSG[pub_rel_done]} $(gh release view "$tag" --json url -q .url)"
  exit 0
fi

# --- Sync mode: create the repo if needed, push main -----------------------
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
  gh repo create "$REPO_NAME" --public --source=. --remote=origin \
    --description "$DESCRIPTION"
fi

git push -u origin main
echo
ok "${MSG[pub_done]} $(gh repo view --json url -q .url)"
echo "${MSG[pub_hint]}"
