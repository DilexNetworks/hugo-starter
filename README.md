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

Create a brand new Hugo site repo using the bootstrap script:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/DilexNetworks/hugo-starter/main/utils/bootstrap.sh \
  | bash -s -- my-new-site
```

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
