$(THISDIR_PATH)/.bin:
	mkdir -p $@

DOCKER_COMPOSE_VERSION := 1.11.2
DOCKER_COMPOSE := $(THISDIR_PATH)/.bin/docker-compose
DOCKER_COMPOSE_BIN := $(DOCKER_COMPOSE)-$(DOCKER_COMPOSE_VERSION)

$(DOCKER_COMPOSE): $(DOCKER_COMPOSE_BIN)
	ln -sf $(realpath $(DOCKER_COMPOSE_BIN)) $(DOCKER_COMPOSE)

WGET := $(shell wget --version 2> /dev/null)

$(DOCKER_COMPOSE_BIN): $(THISDIR_PATH)/.bin
ifndef WGET
	$(error missing wget to download Docker Compose)
endif
	@wget --no-verbose https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-`uname -s`-`uname -m` -O $(DOCKER_COMPOSE_BIN)
	@chmod +x $(DOCKER_COMPOSE_BIN)
	@touch $(DOCKER_COMPOSE_BIN)

.PHONY: compose
compose: $(DOCKER_COMPOSE)
	@$(MAKE) -f $(MKFILE_PATH) $(DOCKER_COMPOSE) > /dev/null
	@echo $(DOCKER_COMPOSE)
