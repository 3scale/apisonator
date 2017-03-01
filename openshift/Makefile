MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THISDIR_PATH := $(patsubst %/,%,$(abspath $(dir $(MKFILE_PATH))))
PROJECT_PATH := $(patsubst %/,%,$(abspath $(dir $(THISDIR_PATH)/../)))
BUILDDIR_NAME := os-build
BUILDDIR_PATH = $(THISDIR_PATH)/$(BUILDDIR_NAME)
NAME=backend
NAMESPACE=quay.io/3scale
BACKEND_VERSION=2.71.0
ENVIRONMENT=production
GEMINABOX_CREDENTIALS := $(GEMINABOX_CREDENTIALS)
BACKEND_CREDENTIALS := $(BACKEND_CREDENTIALS)
BACKEND_ENDPOINT := $(BACKEND_ENDPOINT)
PORT=3001
VERSION := $(BACKEND_VERSION)
LOCAL_IMAGE := $(NAME):$(VERSION)
REMOTE_IMAGE := $(NAMESPACE)/$(LOCAL_IMAGE)

DOCKER_COMPOSE_VERSION := 1.10.0
DOCKER_COMPOSE := .bin/docker-compose
DOCKER_COMPOSE_BIN := $(DOCKER_COMPOSE)-$(DOCKER_COMPOSE_VERSION)
DOCKER_RUN := docker run --rm

.PHONY: build build-dir new-build-dir rm-build-dir check-env test test-integration \
        listener worker cron bash tag push help all compose default

default: help

.bin:
	@mkdir -p $@

$(DOCKER_COMPOSE): $(DOCKER_COMPOSE_BIN)
	@ln -sf $(realpath $(DOCKER_COMPOSE_BIN)) $(DOCKER_COMPOSE)

WGET := $(shell wget --version 2> /dev/null)

$(DOCKER_COMPOSE_BIN): .bin
ifndef WGET
	$(error missing wget to download Docker Compose)
endif
	@wget --no-verbose https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-`uname -s`-`uname -m` -O $(DOCKER_COMPOSE_BIN)
	@chmod +x $(DOCKER_COMPOSE_BIN)
	@touch $(DOCKER_COMPOSE_BIN)

compose: $(DOCKER_COMPOSE)
	@$(MAKE) $(DOCKER_COMPOSE) > /dev/null
	@echo $(DOCKER_COMPOSE)

all: build

rm-build-dir:
	rm -rf $(shell readlink -e $(BUILDDIR_PATH)) $(BUILDDIR_PATH)

new-build-dir: rm-build-dir
	ln -s $(shell mktemp -d) $(BUILDDIR_PATH)

build-dir: # Generate a clean export of the source code for building
	if test ! -d $(BUILDDIR_PATH); then $(MAKE) new-build-dir; fi
	(git diff-index --quiet --cached HEAD && \
	  git diff-files --quiet && \
	  git diff-index --quiet HEAD) || \
	  (echo error: dirty git state - ensure all diffs are committed >&2; false)
	(cd $(PROJECT_PATH) && \
	  git archive --worktree-attributes --format=tar --prefix=dist/ HEAD) | \
	  (rm -rf $(BUILDDIR_PATH)/* && tar xf - -C $(BUILDDIR_PATH))
	touch $(BUILDDIR_PATH)/ready

# flag file to *assume* whatever is in a build dir is trusted to generate the image
$(BUILDDIR_NAME)/ready:
	$(MAKE) build-dir

check-env:
ifndef GEMINABOX_CREDENTIALS
	$(error GEMINABOX_CREDENTIALS is undefined)
endif

build: $(BUILDDIR_NAME)/ready ## Build docker image with name LOCAL_IMAGE (NAME:VERSION).
	docker build -f $(BUILDDIR_PATH)/dist/$(shell realpath --relative-to \
	  $(PROJECT_PATH) $(THISDIR_PATH))/Dockerfile --pull -t $(LOCAL_IMAGE) \
	  $(BUILDDIR_PATH)/dist
	rm -rf $(BUILDDIR_PATH)

test: ## Test built LOCAL_IMAGE (NAME:VERSION).
	$(DOCKER_RUN) -t --env RACK_ENV=$(ENVIRONMENT) --env CONFIG_INTERNAL_API_USER=foo $(LOCAL_IMAGE) rackup -D
	$(DOCKER_RUN) -t --env RACK_ENV=$(ENVIRONMENT) --env CONFIG_INTERNAL_API_USER=foo $(LOCAL_IMAGE) rackup -s puma -D
	$(DOCKER_RUN) -t $(LOCAL_IMAGE) 3scale_backend --version
	$(DOCKER_RUN) -t --env RACK_ENV=$(ENVIRONMENT) $(LOCAL_IMAGE) 3scale_backend_worker --version
	$(DOCKER_RUN) -t --env RACK_ENV=$(ENVIRONMENT) --env ONCE=1 $(LOCAL_IMAGE) backend-cron | grep "RuntimeError: task crashed" > /dev/null # because redis is not running

test-integration: export LOCAL_IMAGE := $(LOCAL_IMAGE)
test-integration: $(DOCKER_COMPOSE)
ifndef BACKEND_ENDPOINT
test-integration: build
	$(DOCKER_COMPOSE) run --rm test
else
	$(DOCKER_COMPOSE) run --rm -e BACKEND_ENDPOINT=$(BACKEND_ENDPOINT) --no-deps test
endif

listener:
	$(DOCKER_RUN) --env-file .env --env RACK_ENV=$(ENVIRONMENT) -p $(PORT):$(PORT) $(LOCAL_IMAGE) 3scale_backend start -p $(PORT) -x /dev/stdout

worker:
	$(DOCKER_RUN) --env-file .env --env RACK_ENV=$(ENVIRONMENT) $(LOCAL_IMAGE) 3scale_backend_worker run

cron:
	$(DOCKER_RUN) --env-file .env --env RACK_ENV=$(ENVIRONMENT) $(LOCAL_IMAGE) backend-cron

bash: ## Start bash in the build IMAGE_NAME.
	docker run --env-file .env --env RACK_ENV=$(ENVIRONMENT) --entrypoint=/bin/bash -it $(LOCAL_IMAGE)

tag: ## Tag LOCAL_IMAGE (NAME:VERSION) in the remote registry.
	docker tag $(LOCAL_IMAGE) $(REMOTE_IMAGE)

push: ## Push the remote image. Accepts NAME and VERSION.
	docker push $(REMOTE_IMAGE)

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
