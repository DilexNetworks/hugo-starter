# hugo-starter

A minimal, opinionated **Hugo starter repository** designed to be used with the
`core-tooling` process layer.

This repo is intentionally public and contains **no secrets**. It exists to
provide:

- a clean, minimal Hugo site layout
- a reproducible starting point for new sites
- a one-command bootstrap workflow

---

## Quick start (recommended)

The starter is public, but `DilexNetworks/core-tooling` is private. You need
GitHub CLI (`gh`) authenticated as an account with read access to that repository.
A public starter URL does not grant access to its private dependency.

Prerequisites: Bash, Git, curl, Python 3, rsync, make, and GitHub CLI. Configure
Git `user.name` and `user.email` for the initial commit. Authenticate once:

```bash
gh auth login --hostname github.com
gh api repos/DilexNetworks/core-tooling --jq .full_name
```

For automation, `GH_TOKEN` may supply GitHub CLI authentication; it must have
read access to the private repository (and organization SSO authorization if
required). Never put a token in the download URL.

Create a brand new Hugo site repo using the bootstrap script:

```bash
set -o pipefail
curl -fsSL \
  https://raw.githubusercontent.com/DilexNetworks/hugo-starter/main/utils/bootstrap.sh \
  | bash -s -- my-new-site
```

`pipefail` ensures a failed script download is reported as a failed command.
The script uses authenticated GitHub API requests for release metadata and
installer files. The tooling installer uses `gh` to clone its release tag;
no uploaded release assets are needed.

By default the script downloads the starter's latest release (`main` is the
fallback) and the latest tooling release. To pin versions, set variables on
**the Bash side** of the pipe, for example:

```bash
set -o pipefail
curl -fsSL \
  https://raw.githubusercontent.com/DilexNetworks/hugo-starter/main/utils/bootstrap.sh \
  | STARTER_REF=v0.1.5 TOOLING_TAG=v0.1.13 bash -s -- my-new-site
```

`STARTER_REF` accepts a branch, tag, or full commit SHA. The target must not exist.
An inaccessible tooling repository or release stops setup with an error before
creating the target directory. If a later step fails, inspect the error and any
partially created directory before retrying with a fresh target.

This will:

- copy the starter Hugo site into a new directory
- install the latest release of `core-tooling`
- generate versioning files (`VERSION`, `.bumpversion.cfg`)
- initialize a git repository and make an initial commit

After it completes:

```bash
cd my-new-site
make help
make doctor
make build
make dev
```

---

## What this repository contains

```text
site/
  config/_default/
    hugo.toml          # base Hugo configuration
  content/_index.md   # placeholder content
  layouts/partials/
    extend-head.html  # extension hook for modules/themes
  assets/
  static/

utils/
  bootstrap.sh        # one-shot project bootstrap script

Makefile              # enabled once core-tooling is installed
.gitignore
README.md
```

Everything under `site/` is copied verbatim into new projects.

---

## Tooling and workflow

This starter is designed to work with the **core process layer**:

- [`core-tooling`](https://github.com/DilexNetworks/core-tooling)
  - Makefile includes
  - release/versioning workflow
  - container-based Hugo helpers (optional)

New projects vendor `core-tooling` locally so behavior is:

- explicit
- reviewable
- pinned to a specific version

---

## Hugo configuration

Hugo configuration lives under:

```text
site/config/_default/
```

The default `hugo.toml` supports Hugo Modules and is intended to be extended
rather than replaced.

The starter includes an `extend-head.html` partial compatible with Blowfish and
other module-based themes. It safely includes module-provided head assets when
present.

---

## Design principles

- boring over clever
- explicit over magical
- process separated from product
- easy to replace or rewrite

This repo is intentionally small. It should be easy to understand in one sitting.

---

## License

MIT

## Bootstrap regression tests

Run `python3 -m unittest discover -s tests -v` for offline tests covering private
repository access, release lookup errors, and invalid tooling references.
