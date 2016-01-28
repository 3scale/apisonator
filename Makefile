MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
SHELL = $(PROJECT_PATH)/script/make_report_time.sh
BENCH = $(PROJECT_PATH)/bench.txt
# Jenkins runs the project in ../backend/workspace in its master. Strip that.
PROJECT := $(notdir $(subst /workspace,,$(PROJECT_PATH)))

RUBY_USER := ruby
RUBY_VERSION := $(shell cat $(PROJECT_PATH)/.ruby-version)

# docker does not allow '@' in container names (used by Jenkins)
NAME = $(subst @,,$(PROJECT))-build_$(RUBY_VERSION)
DEV_NAME := dev_$(PROJECT)_$(RUBY_VERSION)
DOCKER_PROJECT_PATH := /home/$(RUBY_USER)/$(PROJECT)

.PHONY: all bash build clean default dev devclean pull show_bench test

default: | clean test show_bench

include $(PROJECT_PATH)/docker/docker.mk

pull:
	@$(call docker_ensure_image, $(DOCKER_REPO):$(DOCKER_BASE_IMG))

test: build
	@$(call docker_run_cmd, $(PROJECT):$(RUBY_VERSION), $(NAME))

# bash creates a new, temporary container each time it is run
# use dev target to keep a persistent container
bash: build
	@ $(call docker_run_disposable, $(PROJECT):$(RUBY_VERSION), -u $(RUBY_USER), /bin/bash)

dev: build
	@ ($(call docker_start_n_exec, $(DEV_NAME), -u $(RUBY_USER), /bin/bash)) || \
		($(call docker_run, $(PROJECT):$(RUBY_VERSION), $(DEV_NAME), -u $(RUBY_USER), /bin/bash))

# we wait just enough for docker to pick up the temporary Dockerfile and remove
# it (limitation in Docker, as it does not do anything useful with STDIN).
build: pull
	@ $(call docker_check_image, $(PROJECT):$(RUBY_VERSION)) || \
		($(call docker_build_dockerfile) && \
		(sleep 4 && rm -f $(DOCKERFILE) &) && \
		$(call docker_build, $(PROJECT):$(RUBY_VERSION), -f $(DOCKERFILE), $(PROJECT_PATH)) \
		)

clean:
	-@ rm -f $(BENCH)
	-@ $(call docker_rm_f, $(NAME))

devclean:
	-@ $(call docker_rm_f, $(DEV_NAME))

show_bench:
	@ cat $(BENCH)
