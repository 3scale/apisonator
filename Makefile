SHELL = ./script/make_report_time.sh
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
# Jenkins runs the project in .../backend/workspace in its master. Strip that.
PROJECT := $(notdir $(subst /workspace,,$(PROJECT_PATH)))
BENCH = bench.txt

RUBY_USER := ruby
RUBY_VERSION := $(shell cat $(PROJECT_PATH)/.ruby-version)
DOCKERFILE := $(shell mktemp -u -p $(PROJECT_PATH) Dockerfile_$(RUBY_VERSION)_XXXXXXXXXX)
DOCKER_PROJECT_PATH:=/home/$(RUBY_USER)/$(PROJECT)
DEV_NAME := dev_$(PROJECT)_$(RUBY_VERSION)
DOCKER_REPO := quay.io/3scale/docker
DOCKER_BASE_IMG := dev-backend-$(RUBY_VERSION)

DOCKER_EXTRA_VOLUMES := -v $(PROJECT_PATH):$(DOCKER_PROJECT_PATH)

RUN = docker run -v $(PROJECT_PATH)/test/reports:$(DOCKER_PROJECT_PATH)/test/reports -v $(PROJECT_PATH)/spec/reports:$(DOCKER_PROJECT_PATH)/spec/reports
RUN_RM = $(RUN) --rm

# docker does not allow '@' in container names (used by Jenkins)
NAME = $(subst @,,$(PROJECT))-build_$(RUBY_VERSION)

.PHONY: all bash build clean cleandev dev devclean dockerfile prepare_docker \
	pull report_dirs show_bench test

define docker_build_dockerfile
	sed -e 's/\$${RUBY_VERSION}/$(RUBY_VERSION)/g' $(PROJECT_PATH)/Dockerfile > $(DOCKERFILE)
endef

define docker_check_image
	docker history -q $1 > /dev/null 2>&1
endef

define docker_ensure_image
	$(call docker_check_image, $1) || docker pull $1
endef

define docker_start_n_exec
	docker start $1 2> /dev/null && docker exec -t -i -u $2 $1 /bin/bash
endef

all: clean build test show_bench

report_dirs:
	@ mkdir $(PROJECT_PATH)/test/reports $(PROJECT_PATH)/spec/reports 2> /dev/null || true
	-@ chown $(shell whoami): $(PROJECT_PATH)/test/reports $(PROJECT_PATH)/spec/reports

prepare_docker: pull report_dirs

test: report_dirs
	$(RUN_RM) --name $(NAME) $(PROJECT):$(RUBY_VERSION)

$(DOCKERFILE): $(PROJECT_PATH)/Dockerfile
	@$(call docker_build_dockerfile)

dockerfile: $(DOCKERFILE)

pull:
	@$(call docker_ensure_image, $(DOCKER_REPO):$(DOCKER_BASE_IMG))

# bash creates a new, temporal container each time it is run - use dev target to keep a persistent container
bash: build
	@$(RUN_RM) -t -i $(DOCKER_EXTRA_VOLUMES) -u $(RUBY_USER) $(PROJECT):$(RUBY_VERSION) /bin/bash

dev: build
	@$(call docker_start_n_exec, $(DEV_NAME), $(RUBY_USER)) || \
		$(RUN) -t -i $(DOCKER_EXTRA_VOLUMES) -u $(RUBY_USER) --name $(DEV_NAME) $(PROJECT):$(RUBY_VERSION) /bin/bash

build: prepare_docker
	@$(call docker_check_image, $(PROJECT):$(RUBY_VERSION)) || \
		($(call docker_build_dockerfile) && \
		(sleep 4 && rm -f $(DOCKERFILE) &) && \
		docker build -t $(PROJECT):$(RUBY_VERSION) -f $(DOCKERFILE) $(PROJECT_PATH) \
		)

clean:
	-@ rm -f $(BENCH)
	-@ docker rm --force $(NAME)

devclean:
	-@ docker rm --force $(DEV_NAME)

show_bench:
	@cat $(BENCH)
