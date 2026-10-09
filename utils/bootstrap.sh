#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "❌ Bootstrap failed at line ${LINENO}; see the error above." >&2' ERR

# hugo-starter bootstrap script
# Creates a new Hugo site repo based on this starter.
# Does not modify hugo-starter itself.

# Usage:
#   curl -fsSL \
#     https://raw.githubusercontent.com/DilexNetworks/hugo-starter/main/utils/bootstrap.sh \
#     | bash -s -- my-new-site
#
# Optional env vars:
#   ORG=...                      (default: DilexNetworks)
#   STARTER_REPO=...             (default: hugo-starter)
#   CORE_TOOLING_REPO=...        (default: core-tooling)
#   STARTER_REF=...              (branch/tag/SHA; default: latest release tag)
#   TOOLING_TAG=v0.1.1           (override latest release tag)

TARGET_DIR="${1:-}"
if [[ -z "${TARGET_DIR}" ]]; then
  echo "Usage: $0 <target-dir>" >&2
  exit 2
fi

ORG="${ORG:-DilexNetworks}"
STARTER_REPO="${STARTER_REPO:-hugo-starter}"
CORE_TOOLING_REPO="${CORE_TOOLING_REPO:-core-tooling}"
STARTER_REF="${STARTER_REF:-}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing required command: $1" >&2; exit 2; }; }

need_cmd git
need_cmd curl
need_cmd python3
need_cmd rsync
need_cmd make

# GitHub CLI shares authentication across metadata, script downloads, and the
# core-tooling installer. Anonymous GitHub requests return 404 for private repos.
need_cmd gh
if ! gh api --hostname github.com "repos/${ORG}/${CORE_TOOLING_REPO}" >/dev/null; then
  echo "❌ Cannot access ${ORG}/${CORE_TOOLING_REPO}. Run 'gh auth login --hostname github.com' with an account that has repository access (and authorize organization SSO if required)." >&2
  exit 1
fi

latest_release_tag() {
  gh api --hostname github.com "repos/$1/releases/latest" --jq .tag_name
}

github_commit_sha() {
  local encoded_ref
  encoded_ref="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$2")"
  gh api --hostname github.com "repos/$1/commits/${encoded_ref}" --jq .sha
}

github_file() {
  gh api --hostname github.com --method GET "repos/${ORG}/${CORE_TOOLING_REPO}/contents/$1" \
    -f "ref=${TOOLING_TAG}" -H 'Accept: application/vnd.github.raw+json'
}

# Resolve starter ref (latest release unless overridden)
if [[ -z "${STARTER_REF}" ]]; then
  echo "→ Resolving latest release for ${ORG}/${STARTER_REPO}"
  if STARTER_REF="$(latest_release_tag "${ORG}/${STARTER_REPO}")"; then
    :
  else
    echo "ℹ️  Could not resolve latest release for ${ORG}/${STARTER_REPO}; falling back to 'main'"
    STARTER_REF="main"
  fi
fi
echo "→ Using starter ref: ${STARTER_REF}"

# Resolve tooling tag (latest release unless overridden)
TOOLING_TAG="${TOOLING_TAG:-}"
if [[ -z "${TOOLING_TAG}" ]]; then
  echo "→ Resolving latest release for ${ORG}/${CORE_TOOLING_REPO}"
  if ! TOOLING_TAG="$(latest_release_tag "${ORG}/${CORE_TOOLING_REPO}")"; then
    echo "❌ Cannot resolve a core-tooling release. Check the GitHub error above or set TOOLING_TAG to an existing tag." >&2
    exit 1
  fi
fi
echo "→ Using core-tooling tag: ${TOOLING_TAG}"
TOOLING_SHA="$(github_commit_sha "${ORG}/${CORE_TOOLING_REPO}" "${TOOLING_TAG}")"
echo "→ core-tooling commit: ${TOOLING_SHA}"

# Create target directory
if [[ -e "${TARGET_DIR}" ]]; then
  echo "❌ Target path already exists: ${TARGET_DIR}" >&2
  exit 2
fi
mkdir -p "${TARGET_DIR}"
cd "${TARGET_DIR}"

echo "→ Fetching starter: ${ORG}/${STARTER_REPO}@${STARTER_REF}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "${tmp}/starter"
git -C "${tmp}/starter" remote add origin "https://github.com/${ORG}/${STARTER_REPO}.git"
git -C "${tmp}/starter" fetch --depth 1 origin "${STARTER_REF}"
git -C "${tmp}/starter" checkout --detach -q FETCH_HEAD
STARTER_SHA="$(git -C "${tmp}/starter" rev-parse HEAD)"
echo "→ starter commit: ${STARTER_SHA}"

# Copy starter content into target (exclude .git)
rsync -a --exclude .git "${tmp}/starter/" .

# Ensure required dirs exist
mkdir -p scripts tooling

# Install core-tooling into this repo
echo "→ Installing core-tooling: ${ORG}/${CORE_TOOLING_REPO}@${TOOLING_TAG}"
github_file scripts/install-tooling.sh > scripts/install-tooling.sh
chmod +x scripts/install-tooling.sh
./scripts/install-tooling.sh "${TOOLING_TAG}"

# Optional updater
if github_file scripts/update-tooling.sh > scripts/update-tooling.sh; then
  chmod +x scripts/update-tooling.sh
else
  rm -f scripts/update-tooling.sh
  echo "⚠️  Optional updater could not be downloaded." >&2
fi

# Write a provenance manifest for the generated repo
GENERATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
cat > CORE_MANIFEST.toml <<EOF
schema = "core.manifest/v1"
generated_at = "${GENERATED_AT}"

[components.hugo_starter]
repo = "${ORG}/${STARTER_REPO}"
ref = "${STARTER_REF}"
commit = "${STARTER_SHA}"
resolved_ref = "${STARTER_REF}"
bootstrap_script = "utils/bootstrap.sh"
copied_paths = ["site/"]

[components.core_tooling]
repo = "${ORG}/${CORE_TOOLING_REPO}"
tag = "${TOOLING_TAG}"
commit = "${TOOLING_SHA}"
installed_to = "tooling/"
EOF

# Write a minimal root Makefile if the starter didn’t include one
if [[ ! -f Makefile ]]; then
  cat > Makefile <<'MAKEFILE'
SITE_DIR ?= site

include tooling/mk/core.mk
include tooling/mk/help.mk
include tooling/mk/doctor.mk
include tooling/mk/git.mk
include tooling/mk/release.mk

# Optional (Hugo / container-based)
include tooling/mk/container-hugo.mk

# Hugo config lives under config/_default
HUGO_CONFIG_ARGS ?= --config $(SITE_DIR)/config/_default/hugo.toml
MAKEFILE
fi

# Initialize versioning files using templates (preferred)
# If VERSION exists in starter, this is a no-op.
make init-versioning

# Initialize git repo (starter was copied without .git)
git init -q
git checkout -b main -q || true
git add -A
if ! git commit -m "chore: bootstrap site from ${ORG}/${STARTER_REPO}@${STARTER_REF} + core-tooling ${TOOLING_TAG}" -q; then
  echo "❌ Files were created, but the initial commit failed. Configure Git user.name/user.email and commit in ${TARGET_DIR}." >&2
  exit 1
fi

echo ""
echo "✅ Created ${TARGET_DIR}"
echo "Next:"
echo "  cd ${TARGET_DIR}"
echo "  make help"
echo "  make doctor"
echo "  make build"
echo "  make dev"
