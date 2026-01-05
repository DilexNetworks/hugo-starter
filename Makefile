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
