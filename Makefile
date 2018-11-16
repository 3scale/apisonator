MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
SHELL = $(PROJECT_PATH)/script/make_report_time.sh
BENCH = $(PROJECT_PATH)/bench.txt
IMAGE_REPO = quay.io/3scale
CI_IMAGE = $(IMAGE_REPO)/apisonator-ci

.PHONY: default
default: | clean test show_bench

.PHONY: test
test: export BUILD_CI?=0
test: export DEV_TOOLS?=""
test: export IMAGE_NAME?=apisonator-test
test: export CONTAINER_NAME?=apisonator-test
test: DOCKER_OPTS?=
test:
	make -C $(PROJECT_PATH) -f $(MKFILE_PATH) dev-build
	docker run --rm -t -h $(CONTAINER_NAME) -v \
		$(PROJECT_PATH):$$(docker run --rm $(IMAGE_NAME) /bin/bash -c 'cd && pwd')/apisonator:z \
		-u $$(docker run --rm $(IMAGE_NAME) /bin/bash -c 'id -u'):$$(docker run --rm $(IMAGE_NAME) /bin/bash -c 'id -g') \
	$(DOCKER_OPTS) --name $(CONTAINER_NAME) $(IMAGE_NAME)

.PHONY: clean
clean:
	-@ rm -f $(BENCH)

.PHONY: show_bench
show_bench:
	@ cat $(BENCH)

.PHONY: dev-clean
dev-clean: CONTAINER_NAME=apisonator-dev
dev-clean:
	-docker kill $(CONTAINER_NAME)
	-docker rm $(CONTAINER_NAME)

.PHONY: dev-service-clean
dev-service-clean: CONTAINER_NAME=apisonator-dev-service
dev-service-clean:
	-docker kill $(CONTAINER_NAME)
	-docker rm $(CONTAINER_NAME)

.PHONY: dev-clean-image
dev-clean-image: IMAGE_NAME?=apisonator-dev
dev-clean-image: dev-clean dev-service-clean
	docker rmi $(IMAGE_NAME)

.PHONY: dev
dev: export IMAGE_NAME?=apisonator-dev
dev: export PORT?= 3000
dev: export CONTAINER_NAME?=apisonator-dev
dev: export COMMAND?=/bin/bash
dev:
	@docker history -q $(IMAGE_NAME) 2> /dev/null >&2 || $(MAKE) -C $(PROJECT_PATH) -f $(MKFILE_PATH) dev-build
	@if docker ps --filter name=$(CONTAINER_NAME) --format "{{.Names}}" | grep -q '^$(CONTAINER_NAME)$$' 2> /dev/null >&2; then \
		echo "$(CONTAINER_NAME) container already started" >&2; false ; \
	fi
	@if docker ps -a --filter name=$(CONTAINER_NAME) --format "{{.Names}}" | grep -q '^$(CONTAINER_NAME)$$' 2> /dev/null >&2; then \
		docker start -ai $(CONTAINER_NAME) ; \
	else \
		docker run -ti -h $(CONTAINER_NAME) --expose=3000 -p $(PORT):3000 -v \
		$(PROJECT_PATH):$$(docker run --rm $(IMAGE_NAME) /bin/bash -c 'cd && pwd')/apisonator:z \
		-u $$(docker run --rm $(IMAGE_NAME) /bin/bash -c 'id -u'):$$(docker run --rm $(IMAGE_NAME) /bin/bash -c 'id -g') \
		--name $(CONTAINER_NAME) $(IMAGE_NAME) $(COMMAND) ; \
	fi

.PHONY: dev-service
dev-service: export CONTAINER_NAME?=apisonator-dev-service
dev-service: export COMMAND=script/test_external
dev-service:
	$(MAKE) -C $(PROJECT_PATH) -f $(MKFILE_PATH) dev

.PHONY: dev-build
dev-build: export BUILD_CI?=0
dev-build: export DEV_TOOLS?="vim"
dev-build: export IMAGE_NAME?=apisonator-dev
dev-build: $(PROJECT_PATH)/Dockerfile
	docker history -q $(CI_IMAGE) || \
		(test "x${BUILD_CI}" != "x1" && docker pull $(CI_IMAGE)) || \
		$(MAKE) -C $(PROJECT_PATH) -f $(MKFILE_PATH) ci-build
	docker build -t $(IMAGE_NAME) --build-arg DEV_TOOLS=$(DEV_TOOLS) --build-arg \
		APP_HOME="$$(docker run --rm $(CI_IMAGE) /bin/bash -c 'cd && pwd')/apisonator" \
		$(PROJECT_PATH)

.PHONY: ci-build
ci-build: export APISONATOR_REL?=v$(shell docker run --rm -w /tmp/apisonator -v $(PROJECT_PATH):/tmp/apisonator:z \
	$(CI_IMAGE) ruby -r/tmp/apisonator/lib/3scale/backend/version -e "puts ThreeScale::Backend::VERSION")
ci-build: $(PROJECT_PATH)/Dockerfile.ci
	docker build -t apisonator-ci-layered:$(APISONATOR_REL) -f Dockerfile.ci $(PROJECT_PATH)
	docker tag apisonator-ci-layered:$(APISONATOR_REL) apisonator-ci-layered:latest
	$(MAKE) -C $(PROJECT_PATH) -f $(MKFILE_PATH) ci-flatten

.PHONY: ci-flatten
ci-flatten: APISONATOR_REL?=v$(shell docker run --rm -w /tmp/apisonator -v $(PROJECT_PATH):/tmp/apisonator:z \
	$(CI_IMAGE) ruby -r/tmp/apisonator/lib/3scale/backend/version -e "puts ThreeScale::Backend::VERSION")
ci-flatten: CI_USER?=$(shell docker run --rm apisonator-ci-layered:$(APISONATOR_REL) whoami)
ci-flatten: CI_PATH?=$(shell docker run --rm apisonator-ci-layered:$(APISONATOR_REL) /bin/bash -c "echo \$${PATH}")
ci-flatten:
	-docker rm dummy-export-apisonator-ci-$(APISONATOR_REL)
	docker run --name dummy-export-apisonator-ci-$(APISONATOR_REL) \
		apisonator-ci-layered:$(APISONATOR_REL) echo
	(docker export dummy-export-apisonator-ci-$(APISONATOR_REL) | \
		docker import -c "USER $(CI_USER)" -c "ENV PATH $(CI_PATH)" - \
		$(CI_IMAGE):$(APISONATOR_REL)) || \
		(echo Failed to flatten image && \
		docker rm dummy-export-apisonator-ci-$(APISONATOR_REL) && false)
	-docker rm dummy-export-apisonator-ci-$(APISONATOR_REL)
	docker tag $(CI_IMAGE):$(APISONATOR_REL) $(CI_IMAGE):latest
