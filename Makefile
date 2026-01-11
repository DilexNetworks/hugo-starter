# -----------------------------------------------------------------------------
# Shared tooling
#
# This repo expects shared Makefile includes under ./tooling.
# If tooling is not installed yet, `make` will warn and provide a helper target.
#
# Install:
#   make tooling
# Update:
#   make tooling-update
# -----------------------------------------------------------------------------

TOOLING_DIR ?= tooling
TOOLING_MK_DIR := $(TOOLING_DIR)/mk

# If tooling is missing, don't fail on includes.
HAVE_TOOLING := $(wildcard $(TOOLING_MK_DIR)/core.mk)

ifeq ($(strip $(HAVE_TOOLING)),)
$(warning ⚠️  Shared tooling is not installed (missing $(TOOLING_MK_DIR)/core.mk).)
$(warning    Run: make tooling)
endif

.PHONY: tooling tooling-update

# Default tooling repo/ref can be overridden by env vars.
TOOLING_REPO ?= https://github.com/DilexNetworks/core-tooling.git
TOOLING_REF  ?= main
# Tooling version (override with: make tooling TOOLING_VERSION=vX.Y.Z)
TOOLING_VERSION ?= v0.1.4

# Install tooling into ./tooling (no submodules).
tooling:
	@./scripts/install-tooling.sh $(TOOLING_VERSION)

# Update tooling (re-run install script).
tooling-update: tooling

SITE_DIR ?= site

ifneq ($(strip $(HAVE_TOOLING)),)
include $(TOOLING_MK_DIR)/core.mk
include $(TOOLING_MK_DIR)/help.mk
include $(TOOLING_MK_DIR)/doctor.mk
include $(TOOLING_MK_DIR)/git.mk
include $(TOOLING_MK_DIR)/release.mk

# Optional (Hugo / container-based)
include $(TOOLING_MK_DIR)/container-hugo.mk
endif

# Hugo config lives under config/_default
HUGO_CONFIG_ARGS ?= --config $(SITE_DIR)/config/_default/hugo.toml
