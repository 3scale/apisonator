#
# 3scale Backend Docker image build process.
#
# You might want to run "make help" for a full list of targets.
#
# This Makefile is intended to safe and functional when invoked from external
# directories with "make -f ../path/to/Makefile".
#
# Useful variables when invoking build targets:
#
# GIT_DIRTY_CHECK: set to 0 to allow dirty builds (non-committed changes).
# BUILD_CLEANUP: set to 0 to skip removing the build directory after build.
# VERSION: set to the base version of the software, ie. 2.0.1.
# EXTRAVERSION: set to the extra version of the software, ie. -rc3.
# RELEASE: set instead of VERSION and EXTRAVERSION.
# PROJECT_NAME: set to the project name (autodetected from directory by default).
#
# If you want to create new build targets:
#
# You need to create a new target invoking theb build target after pointing to
# your Dockerfile and setting up BUILD_ARGS.
#

MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THISDIR_PATH := $(patsubst %/,%,$(abspath $(dir $(MKFILE_PATH))))
PROJECT_PATH := $(patsubst %/,%,$(abspath $(dir $(THISDIR_PATH)/../)))
PROJECT_NAME:=$(shell basename $(PROJECT_PATH))

NAME:=amp
NAMESPACE:=quay.io/3scale
ENVIRONMENT:=production

DISTRO:=ubi/8
DOCKERFILE_PATH=$(THISDIR_PATH)/distro/$(DISTRO)

include $(THISDIR_PATH)/mk/git-export-sources.mk
include $(THISDIR_PATH)/mk/docker-compose.mk
include $(THISDIR_PATH)/mk/build.mk
include $(THISDIR_PATH)/mk/help.mk
include $(THISDIR_PATH)/mk/docker.mk
include $(THISDIR_PATH)/mk/docker-repo.mk
include $(THISDIR_PATH)/mk/backend.mk

GIT_VERSION=$(shell cd $(PROJECT_PATH) && git describe --dirty)
VERSION=$(GIT_VERSION)
RELEASE=$(VERSION)$(EXTRAVERSION)
RELEASE_NAME=$(PROJECT_NAME)-$(RELEASE)
LOCAL_IMAGE=$(NAME):$(RELEASE_NAME)
REMOTE_IMAGE := $(NAMESPACE)/$(LOCAL_IMAGE)

.PHONY: all default

default: help

all: build

# generate a build target that handles export and tmp directories out of _build
$(call build_target,build,_build)

## Build docker image with your own DOCKERFILE and BUILD_ARGS settings.
.PHONY: _build
_build:
	@echo ======================================================================
	@echo "* Image: $(LOCAL_IMAGE)"
	@echo "* Dockerfile: $(DOCKERFILE)"
	@echo ======================================================================
	$(call docker_build,$(DOCKERFILE),$(LOCAL_IMAGE),$(BUILD_ARGS))

# build targets
.PHONY: build
build: export DOCKERFILE?=$(DOCKERFILE_PATH)/Dockerfile ## Build dev image with your own DOCKERFILE and BUILD_ARGS.

.PHONY: build-release
build-release: export DOCKERFILE?=$(DOCKERFILE_PATH)/Dockerfile
build-release: export BUILD_ARGS=--build-arg CACHE_FRIENDLY=false \
	  --build-arg GEM_UPDATE=false \
	  --build-arg BUNDLE_VERSION_MATCH=false \
	  --build-arg BUNDLE_WITHOUT=development:test \
	  --build-arg RACK_ENV=production
build-release: ## Build dev image with release-like settings.
	$(MAKE) -f $(MKFILE_PATH) build

.PHONY: release
release: export DOCKERFILE=$(DOCKERFILE_PATH)/release/Dockerfile
release: ## Build release image, a smaller equivalent of build-release
	@echo === RELEASE BUILD ===
	$(MAKE) -f $(MKFILE_PATH) build

.PHONY: release-min
release-min: export DOCKERFILE:=$(DOCKERFILE_PATH)/release/Dockerfile.min
release-min: ## Build minimum size release image (no shared layer with other projects)
	@echo === MINIMAL SIZE RELEASE BUILD ===
	$(MAKE) -f $(MKFILE_PATH) build
