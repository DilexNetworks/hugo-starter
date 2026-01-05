#!/usr/bin/env bash
set -euo pipefail

# Simple patch-only release helper for hugo-starter
# - bumps VERSION (patch)
# - commits the change
# - tags vX.Y.Z
# - pushes commit + tag

REMOTE="origin"
BRANCH="main"

if [[ ! -f VERSION ]]; then
  echo "❌ VERSION file not found" >&2
  exit 2
fi

current="$(cat VERSION)"
IFS='.' read -r major minor patch <<<"${current}"

if [[ -z "${major}" || -z "${minor}" || -z "${patch}" ]]; then
  echo "❌ Invalid VERSION format: ${current}" >&2
  exit 2
fi

next_patch=$((patch + 1))
next="${major}.${minor}.${next_patch}"

echo "→ Releasing patch ${current} → ${next}"

echo "${next}" > VERSION

git add VERSION

git commit -m "chore(release): v${next}" || {
  echo "❌ Git commit failed" >&2
  exit 2
}

tag="v${next}"

git tag "${tag}"

git push "${REMOTE}" "${BRANCH}"

git push "${REMOTE}" "${tag}"

echo "✅ Released ${tag}"
