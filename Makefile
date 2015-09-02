SHELL = ./script/make_report_time.sh
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
PROJECT := $(notdir $(PROJECT_PATH))
BENCH = bench.txt

RUN = docker run --rm -v $(PROJECT_PATH)/test/reports:/home/ruby/backend/test/reports -v $(PROJECT_PATH)/spec/reports:/home/ruby/backend/spec/reports
# docker does not allow '@' in container names (used by Jenkins)
NAME = $(subst @,,$(PROJECT))-build

.PHONY: test

all: clean build test show_bench

test:
	$(RUN) --name $(NAME) $(PROJECT)

pull:
	- docker pull quay.io/3scale/docker:dev-backend-2.2.2

bash:
	$(RUN) -t -i -v $(PROJECT_PATH):/home/ruby/backend -u ruby $(PROJECT) bash

build: pull
	docker build -t $(PROJECT) .

clean:
	- rm -f $(BENCH)
	- docker rm --force $(NAME)

show_bench:
	cat $(BENCH)
