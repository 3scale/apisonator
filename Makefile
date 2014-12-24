MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
PROJECT := $(notdir $(PROJECT_PATH))

RUN = docker run --rm
NAME = $(PROJECT)-build

.PHONY: test

all: clean build test

test:
	$(RUN) --name $(NAME) $(PROJECT)
pull:
	- docker pull quay.io/3scale/ruby:2.1

bash:
	$(RUN) -t -i $(PROJECT) bash

build: pull
	docker build -t $(PROJECT) .

clean:
	- docker rm --force $(NAME)
