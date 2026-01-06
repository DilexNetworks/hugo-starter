#!/usr/bin/env bash
set -euo pipefail

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

latest_release_tag() {
  local repo="$1"
  python3 - "${repo}" <<'PY'
import json
import sys
import urllib.request
import urllib.error

repo = sys.argv[1]
url = f"https://api.github.com/repos/{repo}/releases/latest"
req = urllib.request.Request(
    url,
    headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "hugo-starter-bootstrap",
    },
)

try:
    with urllib.request.urlopen(req) as r:
        data = json.load(r)
except urllib.error.HTTPError:
    # Common case: 404 when the repo has no GitHub Releases.
    # Exit non-zero so the bash caller can fall back cleanly.
    sys.exit(1)
except Exception:
    sys.exit(1)

tag = data.get("tag_name")
if not tag:
    sys.exit(1)
print(tag)
PY
}

github_commit_sha() {
  local repo="$1"  # e.g. DilexNetworks/core-tooling
  local ref="$2"   # tag, branch, or sha
  python3 - "${repo}" "${ref}" <<'PY'
import json
import sys
import urllib.request
import urllib.error

repo, ref = sys.argv[1], sys.argv[2]
url = f"https://api.github.com/repos/{repo}/commits/{ref}"
req = urllib.request.Request(
    url,
    headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "hugo-starter-bootstrap",
    },
)

try:
    with urllib.request.urlopen(req) as r:
        data = json.load(r)
except urllib.error.HTTPError:
    sys.exit(1)
except Exception:
    sys.exit(1)

sha = data.get("sha")
if not sha:
    sys.exit(1)
print(sha)
PY
}

# Resolve starter ref (latest release unless overridden)
if [[ -z "${STARTER_REF}" ]]; then
  echo "→ Resolving latest release for ${ORG}/${STARTER_REPO}"
  if STARTER_REF="$(latest_release_tag "${ORG}/${STARTER_REPO}")"; then
    :
  else
    echo "ℹ️  No releases found for ${ORG}/${STARTER_REPO}; falling back to 'main'"
    STARTER_REF="main"
  fi
fi
echo "→ Using starter ref: ${STARTER_REF}"

# Resolve tooling tag (latest release unless overridden)
TOOLING_TAG="${TOOLING_TAG:-}"
if [[ -z "${TOOLING_TAG}" ]]; then
  echo "→ Resolving latest release for ${ORG}/${CORE_TOOLING_REPO}"
  TOOLING_TAG="$(latest_release_tag "${ORG}/${CORE_TOOLING_REPO}")"
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
git clone --depth 1 --single-branch --branch "${STARTER_REF}" "https://github.com/${ORG}/${STARTER_REPO}.git" "${tmp}/starter"
STARTER_SHA="$(git -C "${tmp}/starter" rev-parse HEAD)"
echo "→ starter commit: ${STARTER_SHA}"

# Copy starter content into target (exclude .git)
rsync -a --exclude .git "${tmp}/starter/" .

# Ensure required dirs exist
mkdir -p scripts tooling

# Install core-tooling into this repo
RAW_BASE="https://raw.githubusercontent.com/${ORG}/${CORE_TOOLING_REPO}/${TOOLING_TAG}"
echo "→ Installing core-tooling from ${RAW_BASE}"
curl -fsSL "${RAW_BASE}/scripts/install-tooling.sh" -o scripts/install-tooling.sh
chmod +x scripts/install-tooling.sh
./scripts/install-tooling.sh "${TOOLING_TAG}"

# Optional updater
curl -fsSL "${RAW_BASE}/scripts/update-tooling.sh" -o scripts/update-tooling.sh || true
chmod +x scripts/update-tooling.sh || true

# Write a provenance manifest for the generated repo
GENERATED_AT="$(date -Iseconds)"
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
make init-versioning >/dev/null 2>&1 || true

# Initialize git repo (starter was copied without .git)
git init -q
git checkout -b main -q || true
git add -A
git commit -m "chore: bootstrap site from ${ORG}/${STARTER_REPO}@${STARTER_REF} + core-tooling ${TOOLING_TAG}" -q || true

echo ""
echo "✅ Created ${TARGET_DIR}"
echo "Next:"
echo "  cd ${TARGET_DIR}"
echo "  make help"
echo "  make doctor"
echo "  make build"
echo "  make dev"
