MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THISDIR_PATH := $(patsubst %/,%,$(abspath $(dir $(MKFILE_PATH))))
PROJECT_PATH := $(patsubst %/,%,$(abspath $(dir $(THISDIR_PATH)/../)))
NAME=backend
NAMESPACE=quay.io/3scale
BACKEND_VERSION=2.68.0
ENVIRONMENT=production
GEMINABOX_CREDENTIALS := $(GEMINABOX_CREDENTIALS)
BACKEND_CREDENTIALS := $(BACKEND_CREDENTIALS)
BACKEND_ENDPOINT := $(BACKEND_ENDPOINT)
PORT=3001
VERSION := $(BACKEND_VERSION)
LOCAL_IMAGE := $(NAME):$(VERSION)
REMOTE_IMAGE := $(NAMESPACE)/$(LOCAL_IMAGE)

DOCKER_COMPOSE_VERSION := 1.8.0
DOCKER_COMPOSE := .bin/docker-compose
DOCKER_COMPOSE_BIN := $(DOCKER_COMPOSE)-$(DOCKER_COMPOSE_VERSION)

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

check-env:
ifndef GEMINABOX_CREDENTIALS
	$(error GEMINABOX_CREDENTIALS is undefined)
endif

build:
	docker build -f $(THISDIR_PATH)/Dockerfile --pull -t $(LOCAL_IMAGE) $(PROJECT_PATH)

test: build
	docker run -t --env RACK_ENV=$(ENVIRONMENT) $(LOCAL_IMAGE) rackup -D
	docker run -t $(LOCAL_IMAGE) 3scale_backend --version
	docker run -t --env RACK_ENV=$(ENVIRONMENT) $(LOCAL_IMAGE) 3scale_backend_worker --version
	docker run -t --env RACK_ENV=$(ENVIRONMENT) --env ONCE=1 $(LOCAL_IMAGE) backend-cron | grep "RuntimeError: task crashed" > /dev/null # because redis is not running

test-integration: export LOCAL_IMAGE := $(LOCAL_IMAGE)
test-integration: $(DOCKER_COMPOSE)
ifndef BACKEND_ENDPOINT
test-integration: build
	$(DOCKER_COMPOSE) run --rm test
else
	$(DOCKER_COMPOSE) run --rm -e BACKEND_ENDPOINT=$(BACKEND_ENDPOINT) --no-deps test
endif

listener:
	docker run --rm --env-file .env --env RACK_ENV=$(ENVIRONMENT) -p $(PORT):$(PORT) $(LOCAL_IMAGE) 3scale_backend start -p $(PORT) -x /dev/stdout

worker:
	docker run --rm --env-file .env --env RACK_ENV=$(ENVIRONMENT) $(LOCAL_IMAGE) 3scale_backend_worker run

cron:
	docker run --rm --env-file .env --env RACK_ENV=$(ENVIRONMENT) $(LOCAL_IMAGE) backend-cron

bash:
	docker run --env-file .env --env RACK_ENV=$(ENVIRONMENT) --entrypoint=/bin/bash -it $(LOCAL_IMAGE)

tag:
	docker tag $(LOCAL_IMAGE) $(REMOTE_IMAGE)

push:
	docker push $(REMOTE_IMAGE)
