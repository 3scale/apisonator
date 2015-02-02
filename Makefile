SHELL = ./script/make_report_time.sh
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
PROJECT := $(notdir $(PROJECT_PATH))
BENCH = bench.txt

RUN = docker run --rm -v $(PROJECT_PATH)/test/reports:/opt/backend/test/reports -v $(PROJECT_PATH)/spec/reports:/opt/backend/spec/reports
NAME = $(PROJECT)-build

.PHONY: test

all: clean build test show_bench
test:
	$(RUN) --name $(NAME) $(PROJECT)
pull:
	- docker pull quay.io/3scale/docker:dev-2.1.5

bash:
	$(RUN) -t -i $(PROJECT) bash

build: pull
	docker build -t $(PROJECT) .

clean:
	- rm -f $(BENCH)
	- docker rm --force $(NAME)

show_bench:
	cat $(BENCH)
