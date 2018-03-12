MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
SHELL = $(PROJECT_PATH)/script/make_report_time.sh
BENCH = $(PROJECT_PATH)/bench.txt
# Jenkins runs the project in ../backend/workspace in its master. Strip that.
PROJECT := $(notdir $(subst /workspace,,$(PROJECT_PATH)))

RUBY_USER := ruby
RUBY_VERSION := $(shell cat $(PROJECT_PATH)/.ruby-version)

# docker does not allow '@' in container names (used by Jenkins)
DOCKER_NAME = $(subst @,,$(PROJECT))
NAME = $(DOCKER_NAME)-build_$(RUBY_VERSION)
DEV_NAME := dev_$(DOCKER_NAME)_$(RUBY_VERSION)
# DOCKER_PROJECT_PATH value is hardcoded in Dockerfile
DOCKER_PROJECT_PATH := /home/$(RUBY_USER)/backend

# Sleep at most this much before giving up on docker reading Dockerfile
# This is used because currently we generate the final form of the Dockerfile on
# the fly, and we don't want to have them lying around or really hitting the
# disk. This hack should be removed if at any point Docker is able to properly
# support STDIN-fed Dockerfiles.
DOCKERFILE_MAXWAIT_SECS := 30

# Jenkins specific. Needed to report test coverage to CodeClimate.
JENKINS_ENV = JENKINS_URL BUILD_TAG BUILD_NUMBER BUILD_URL
JENKINS_ENV += GIT_BRANCH GIT_COMMIT GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_EMAIL GIT_COMMITTER_NAME

ifdef CODECLIMATE_REPO_TOKEN
	JENKINS_ENV += CODECLIMATE_REPO_TOKEN
endif

DOCKER_ENV = $(foreach env,$(JENKINS_ENV),-e "$(env)=$(shell echo $$$(env))" )
DOCKER_ENV += -e "GIT_TIMESTAMP=$(shell git log -n 1 --pretty=format:%ct)"
DOCKER_ENV += -e "GIT_COMMIT_MESSAGE=$(subst ','\'',$(shell git log -n 1 --pretty=format:%B))"
DOCKER_ENV += -e "GIT_COMMITTED_DATE=$(shell git log -n 1 --pretty=format:%ai)"

.PHONY: all bash build build_test clean default dev devclean pull show_bench test

default: | clean test show_bench

include $(PROJECT_PATH)/docker/docker.mk

# this is used to build our image
define build_dockerfile
	($(call docker_build_dockerfile) && \
		((($(call docker_wait_until_read_dockerfile, $(DOCKERFILE), $(DOCKERFILE_MAXWAIT_SECS)) || \
		echo '*** Docker appears to be TOO SLOW. Maybe use a higher timeout?' >&2) ; \
		echo '*** Removing tmp Dockerfile' >&2; rm -f $(DOCKERFILE)) &) && \
		$(call docker_build, $(DOCKER_NAME):$(RUBY_VERSION), -f $(DOCKERFILE), $(PROJECT_PATH)))
endef

pull:
	@ $(call docker_ensure_image, $(DOCKER_REPO):$(DOCKER_BASE_IMG))

test: build_test
	@ $(call docker_run_container, $(DOCKER_NAME):$(RUBY_VERSION), $(NAME), $(DOCKER_ENV))

# bash creates a temporary test container from the Dockerfile each time it is run
# use dev target to keep a persistent container suitable for development
bash: build_test
	@ $(call docker_run_disposable, $(DOCKER_NAME):$(RUBY_VERSION), -u $(RUBY_USER), /bin/bash)

dev: build
	@ ($(call docker_start_n_exec, $(DEV_NAME), -u $(RUBY_USER), /bin/bash)) || \
		($(call docker_run, $(DOCKER_NAME):$(RUBY_VERSION), $(DEV_NAME), -u $(RUBY_USER), /bin/bash))

# we wait just enough for docker to pick up the temporary Dockerfile and remove
# it (limitation in Docker, as it does not do anything useful with STDIN).
build: pull
	@ ($(call docker_check_image, $(DOCKER_NAME):$(RUBY_VERSION))) || \
		($(call build_dockerfile))

# when testing, we always want to make sure the docker image is up-to-date with
# whatever we have in the dockerfile, plus any dependency therein (ie. Bundler).
build_test: pull
	@ $(call build_dockerfile)

clean:
	-@ rm -f $(BENCH)
	-@ $(call docker_rm_f, $(NAME))

devclean:
	-@ $(call docker_rm_f, $(DEV_NAME))

show_bench:
	@ cat $(BENCH)

.PHONY: ci-build
ci-build: APISONATOR_REL?=$(shell ruby -r$(PROJECT_PATH)/lib/3scale/backend/version -e "puts ThreeScale::Backend::VERSION")
ci-build: Dockerfile.ci
	docker build -t apisonator-ci-layered:$(APISONATOR_REL) -f Dockerfile.ci $(PROJECT_PATH)

.PHONY: ci-flatten
ci-flatten: APISONATOR_REL?=$(shell ruby -r$(PROJECT_PATH)/lib/3scale/backend/version -e "puts ThreeScale::Backend::VERSION")
ci-flatten: CI_USER?=$(shell docker run --rm apisonator-ci-layered:$(APISONATOR_REL) whoami)
ci-flatten: CI_PATH?=$(shell docker run --rm apisonator-ci-layered:$(APISONATOR_REL) /bin/bash -c "echo \$${PATH}")
ci-flatten:
	-docker rm dummy-export-apisonator-ci-$(APISONATOR_REL)
	docker run --name dummy-export-apisonator-ci-$(APISONATOR_REL) \
		apisonator-ci-layered:$(APISONATOR_REL) echo
	(docker export dummy-export-apisonator-ci-$(APISONATOR_REL) | \
		docker import -c "USER $(CI_USER)" -c "ENV PATH $(CI_PATH)" - \
		quay.io/3scale/apisonator-ci:$(APISONATOR_REL)) || \
		(echo Failed to flatten image && \
		docker rm dummy-export-apisonator-ci-$(APISONATOR_REL) && false)
	-docker rm dummy-export-apisonator-ci-$(APISONATOR_REL)
