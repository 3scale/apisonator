PORT:=3001
DOCKER_RUN:=docker run
DOCKER_RUN_RM:=$(DOCKER_RUN) --rm
DOCKER_ENV_RACK=--env RACK_ENV=$(ENVIRONMENT)
DOCKER_ENV=--env-file .env $(DOCKER_ENV_RACK)

.PHONY: listener worker cron bash

listener:
	$(DOCKER_RUN_RM) $(DOCKER_ENV) -p $(PORT):$(PORT) $(LOCAL_IMAGE) \
	  3scale_backend start -p $(PORT) -x /dev/stdout

worker:
	$(DOCKER_RUN_RM) $(DOCKER_ENV) $(LOCAL_IMAGE) \
	  3scale_backend_worker run

cron:
	$(DOCKER_RUN_RM) $(DOCKER_ENV) $(LOCAL_IMAGE) \
	  backend-cron

bash: ## Start bash in the build IMAGE_NAME.
	$(DOCKER_RUN) $(DOCKER_ENV) -it $(LOCAL_IMAGE) \
	  /bin/bash

.PHONY: test test-integration

test: ## Test built LOCAL_IMAGE (NAME:VERSION).
	$(DOCKER_RUN_RM) $(DOCKER_ENV_RACK) --env CONFIG_INTERNAL_API_USER=foo -t $(LOCAL_IMAGE) \
	  rackup -D
	$(DOCKER_RUN_RM) $(DOCKER_ENV_RACK) --env CONFIG_INTERNAL_API_USER=foo -t $(LOCAL_IMAGE) \
	  rackup -s puma -D
	$(DOCKER_RUN_RM) -t $(LOCAL_IMAGE) \
	  3scale_backend --version
	$(DOCKER_RUN_RM) $(DOCKER_ENV_RACK) -t $(LOCAL_IMAGE) \
	  3scale_backend_worker --version
	$(DOCKER_RUN_RM) $(DOCKER_ENV_RACK) --env ONCE=1 -t $(LOCAL_IMAGE) \
	  backend-cron | grep -q "task crashed (RuntimeError)" # redis is not running

test-integration: export LOCAL_IMAGE := $(LOCAL_IMAGE)
test-integration: $(DOCKER_COMPOSE)
ifndef BACKEND_ENDPOINT
test-integration: build
	$(DOCKER_COMPOSE) run --rm test
else
	$(DOCKER_COMPOSE) run --rm -e BACKEND_ENDPOINT=$(BACKEND_ENDPOINT) --no-deps test
endif
