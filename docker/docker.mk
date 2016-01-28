# This file needs the following variables:
#
# PROJECT_PATH = path to project's root
# DOCKER_PROJECT_PATH = path to project's root inside Docker
# RUBY_VERSION = the Ruby version to build the image with
#
DOCKERFILE := $(shell mktemp -u -p $(PROJECT_PATH) Dockerfile_$(RUBY_VERSION)_XXXXXXXXXX)
DOCKER_REPO := quay.io/3scale/docker
DOCKER_BASE_IMG := dev-backend-$(RUBY_VERSION)

DOCKER_EXTRA_VOLUMES := -v $(PROJECT_PATH):$(DOCKER_PROJECT_PATH)

RUN = docker run
RUN_RM = $(RUN) --rm

define docker_build_dockerfile
	sed -e 's/\$${RUBY_VERSION}/$(RUBY_VERSION)/g' $(PROJECT_PATH)/Dockerfile > $(DOCKERFILE)
endef

define docker_check_image
	docker history -q $1 > /dev/null 2>&1
endef

define docker_ensure_image
	($(call docker_check_image, $1)) || docker pull $1
endef

define docker_start_n_exec
	docker start $1 > /dev/null 2>&1 && docker exec -t -i $2 $1 $3
endef

define docker_run_disposable
	docker run --rm -t -i $(DOCKER_EXTRA_VOLUMES) $2 $1 $3
endef

define docker_run_cmd
	docker run --name $2 $(DOCKER_EXTRA_VOLUMES) $1
endef

define docker_run
	docker run --name $2 -h $(shell echo '$2' | sed -e 's/[.\s]/_/g') -t -i $(DOCKER_EXTRA_VOLUMES) $3 $1 $4
endef

define docker_build
	docker build -t $1 $2 $3
endef

define docker_rm_f
	docker rm --force $1
endef

.PHONY: $(DOCKERFILE) dockerfile

$(DOCKERFILE): $(PROJECT_PATH)/Dockerfile
	@ $(call docker_build_dockerfile)

dockerfile: $(DOCKERFILE)
