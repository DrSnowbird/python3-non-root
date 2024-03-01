# -------------------------------------------------------------------------------------------------------
# login first (Registry: e.g., hub.docker.io, registry.localhost:5000, etc.)
# a.)  docker login
# or
# b.) docker login -p FpXM6Qy9vVL5kPeoefzxwA-oaYb-Wpej2iXTwV7UHYs -e unused -u unused docker-registry-default.openkbs.org
# e.g. (using Openshift)
#    oc process -f ./files/deployments/template.yml -v API_NAME=$(REGISTRY_IMAGE) > template.active
#
# to run:
# make <verb> [ APP_VERSION=<...> DOCKER_NAME=<...> REGISTRY_HOST=<...> ]
# example:
#   make build
#   make up
#   make down
# -------------------------------------------------------------------------------------------------------

SHELL := /bin/bash

BASE_IMAGE := $(BASE_IMAGE)

## -- To Check syntax:
#  cat -e -t -v Makefile

# The name of the container (default is current directory name)
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
DOCKER_NAME := $(shell echo $(current_dir)|tr '[:upper:]' '[:lower:]'|tr "/: " "_" )

ORGANIZATION=$(shell echo $${ORGANIZATION:-openkbs})
APP_VERSION=$(shell echo $${APP_VERSION:-latest})
imageTag=$(ORGANIZATION)/$(DOCKER_NAME)

## Docker Registry (Private Server)
REGISTRY_HOST=
#REGISTRY_HOST=$(shell echo $${REGISTRY_HOST:-localhost:5000})
REGISTRY_IMAGE=$(REGISTRY_HOST)/$(ORGANIZATION)/$(DOCKER_NAME)

#VERSION?="$(APP_VERSION)-$$(date +%Y%m%d)"
VERSION?="$(APP_VERSION)"

## -- Uncomment this to use local Registry Host --
DOCKER_IMAGE := $(ORGANIZATION)/$(DOCKER_NAME)

BUILD_VERSIONS=3.12 3.9

## -- To Check syntax:
#  cat -e -t -v Makefile

# -- example --
#VOLUME_MAP := "-v $${PWD}/data:/home/developer/data -v $${PWD}/workspace:/home/developer/workspace"
VOLUME_MAP := 

## -- Network: -- ##
DOCKER_NETWORK=$(shell echo $${DOCKER_NETWORK:-dev_network})

# -- Local SAVE of image --
IMAGE_EXPORT_PATH := "$${PWD}/archive"

# { no, on-failure, unless-stopped, always }
RESTART_OPTION := always

#SHA := $(shell git describe --match=NeVeRmAtCh --always --abbrev=40 --dirty=*)

TIME_START := $(shell date +%s)

.PHONY: clean rmi build push pull up down run stop exec

debug:
	@echo "makefile_path="$(mkfile_path)
	@echo "current_dir="$(current_dir)
	@echo "DOCKER_NNAME="$(DOCKER_NAME) 
	@echo "DOCKER_IMAGE:VERSION="$(DOCKER_IMAGE):$(VERSION) 

default: build

#build-time:
#	docker build \
#	--build-arg BASE_IMAGE="$(BASE_IMAGE)" \
#	--build-arg CIRCLE_SHA1="$(SHA)" \
#	--build-arg version=$(VERSION) \
#	--build-arg VCS_REF=`git rev-parse --short HEAD` \
#	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
#	-t $(DOCKER_IMAGE):$(VERSION) .

build-rm:
	docker build --force-rm --no-cache \
		-t $(DOCKER_IMAGE):$(VERSION) .
	docker images | grep $(DOCKER_IMAGE)
	@echo ">>> Total Dockder images Build using time in seconds: $$(($$(date +%s)-$(TIME_START))) seconds"

build:
	for ver in $(BUILD_VERSIONS); do \
		echo ">>> Python version: $$ver"; \
		docker build -t $(DOCKER_IMAGE):$$ver --build-arg PYTHON_VERSION=$$ver .  ; \
	done
	@echo ">>> Total Dockder images Build using time in seconds: $$(($$(date +%s)-$(TIME_START))) seconds"

push:
	docker commit -m "$comment" ${containerID} ${imageTag}:$(VERSION)
	docker push $(DOCKER_IMAGE):$(VERSION)

	docker tag $(imageTag):$(VERSION) $(REGISTRY_IMAGE):$(VERSION)
	#docker tag $(imageTag):latest $(REGISTRY_IMAGE):latest
	docker push $(REGISTRY_IMAGE):$(VERSION)
	#docker push $(REGISTRY_IMAGE):latest
	@if [ ! "$(IMAGE_EXPORT_PATH)" = "" ]; then \
		mkdir -p $(IMAGE_EXPORT_PATH); \
		docker save $(REGISTRY_IMAGE):$(VERSION) | gzip > $(IMAGE_EXPORT_PATH)/$(DOCKER_NAME)_$(VERSION).tar.gz; \
	fi
	
pull:
	@if [ "$(REGISTRY_HOST)" = "" ]; then \
		docker pull $(DOCKER_IMAGE):$(VERSION) ; \
	else \
		docker pull $(REGISTRY_IMAGE):$(VERSION) ; \
	fi

network:
	echo -e ">>> ==================== network: ======================"
	docker network create --driver bridge ${DOCKER_NETWORK}
	docker network ls

## -- deployment mode (daemon service): -- ##
up:
	bin/auto-config-all.sh
	#if [ "$(USER_ID)" != "" ] && [ "$(USER_ID)" != "" ]; then \
	#	sudo chown -R $(USER_ID):$(GROUP_ID) data workspace ; \
	#	docker-compose up --remove-orphans -u $(USER_ID):$(GROUP_ID) -d ; \
	#else \
	#	docker-compose up --remove-orphans -d ; \
	#fi
	docker-compose up --remove-orphans -d
	docker ps | grep $(DOCKER_IMAGE)
	@echo ">>> Total Dockder images Build using time in seconds: $$(($$(date +%s)-$(TIME_START))) seconds"

down:
	./stop.sh
	docker-compose down
	#docker ps | grep $(DOCKER_IMAGE)
	@echo ">>> Total Dockder images Build using time in seconds: $$(($$(date +%s)-$(TIME_START))) seconds"

down-rm:
	docker-compose down -v --rmi all --remove-orphans
	#docker ps | grep $(DOCKER_IMAGE)
	@echo ">>> Total Dockder images Build using time in seconds: $$(($$(date +%s)-$(TIME_START))) seconds"

## -- dev/debug -- ##
run:
	@if [ ! -s .env ]; then \
		bin/auto-config-all.sh; \
	fi
	./run.sh
	docker ps | grep $(DOCKER_IMAGE)
	#docker run --name=$(DOCKER_NAME) --restart=$(RESTART_OPTION) $(VOLUME_MAP) $(DOCKER_IMAGE):$(VERSION)

stop:
	docker stop --name=$(DOCKER_NAME)

status:
	docker ps | grep $(DOCKER_NAME)

rmi:
	docker rmi $$(docker images -f dangling=true -q)

exec:
	docker-compose exec $(DOCKER_NAME) /bin/bash
