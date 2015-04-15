#!/usr/bin/env make -f

SHELL := /usr/bin/env bash

TAG ?= latest
REGISTRY ?= mojotech
ENV ?= dev
HOST ?= localhost

CLOJURE_IMAGES := \
	provisioner \
	marketplace \
	publications \
	user \
	vendor

IMAGES := \
	web \
	api \
	beaker \
	tests \
	riemann \
	datomic \
	$(CLOJURE_IMAGES)

.PHONY: \
	$(IMAGES) \
	push-all \
	push-% \
	save-all \
	save-% \
	load-all \
	load-% \
	stop-all \
	stop-% \
	remove-all \
	remove-% \
	clean-all \
	clean-% \
	prepare-all \
	prepare-% \
	wait-api \
	wait-web \
	wait-provisioner \
	wait-marketplace \
	wait-publications \
	start-api \
	start-web \
	start-provisioner \
	start-marketplace \
	start-publications \
	start-riemann \
	start-tests-user \
	start-tests-vendor \
	start-tests-integration \
	start-tests-marketplace \
	start-beaker \
	test-% \
	test-integration \
	deploy-% \
	bootstrap-ci \
	bootstrap-local \
	provision-local

all: $(IMAGES)

$(filter-out $(CLOJURE_IMAGES) web api,$(IMAGES)):
	docker build --force-rm -t $(REGISTRY)/bunsen-$@:$(TAG) $@

$(CLOJURE_IMAGES): install
	lein modules :dirs $@ do clean, uberjar
	docker build --force-rm -t $(REGISTRY)/bunsen-$@:$(TAG) $@

web:
	docker build --force-rm -t $(REGISTRY)/bunsen-web:$(TAG) front_end

api:
	docker build --force-rm -t $(REGISTRY)/bunsen-api:$(TAG) app

install:
	lein modules install

push-all: $(IMAGES:%=push-%)
push-%:
	docker push $(REGISTRY)/bunsen-$*:$(TAG)

pull-all: $(IMAGES:%=pull-%)
pull-%:
	docker pull $(REGISTRY)/bunsen-$*:$(TAG)

save-all: $(IMAGES:%=save-%)
save-%:
	mkdir -p $(TARGET)
	docker save $(REGISTRY)/bunsen-$* > $(TARGET)bunsen-$*.tar

load-all: $(IMAGES:%=load-%)
load-%:
	if [[ -e $(SOURCE)bunsen-$*.tar ]]; then docker load -i $(SOURCE)bunsen-$*.tar; fi

stop-all: $(IMAGES:%=stop-%)
stop-%:
	docker ps | awk 'NR>1 && $$2 == "$(REGISTRY)/bunsen-$*:$(TAG)"{print $$1}' | xargs -n1 docker stop

remove-all: $(IMAGES:%=remove-%)
remove-%: stop-%
	docker ps -a | awk 'NR>1 && $$2 == "$(REGISTRY)/bunsen-$*:$(TAG)"{print $$1}' | xargs -n1 docker rm

clean-all: $(IMAGES:%=clean-%)
clean-%: remove-%
	docker images | awk 'NR>1 && $$1 == "$(REGISTRY)/bunsen-$*" && $$2 == "$(TAG)"{print $$1}' | xargs -n1 docker rmi

#
#
#

prepare-all: $(IMAGES:%=prepare-%)

prepare-%: install
	lein modules :dirs $* deps

prepare-api:
	make -C app

prepare-web:
	make -C front_end

prepare-riemann:
	make -C riemann

prepare-tests:
	make -C tests

# nothing to do here
prepare-datomic:
	true

#
#
#

test test-all: test-vendor test-marketplace test-user test-integration

test-%: ENV := test
test-%: HOST := 10.10.10.10
test-%: PORT := 3000
test-%: wait-all
	source config/$(ENV).env && HOST=$(HOST) PORT=$(PORT) lein modules :dirs $* with-profiles -dev test

test-integration: ENV := test
test-integration: HOST := 10.10.10.10
test-integration: wait-all start-tests
	sleep 5
	docker logs -f bunsen-tests
	exit $$(docker wait bunsen-tests)

test-marketplace: PORT := 8444

wait-all: wait-web wait-api wait-provisioner wait-marketplace wait-publications

wait-web: start-web
	wget -qO- --retry-connrefused --tries=20 "$(HOST):8081"

wait-api: start-api
	wget -qO- --retry-connrefused --tries=20 "$(HOST):3000/api/status"

wait-provisioner: start-provisioner
	wget -qO- --retry-connrefused --tries=20 "$(HOST):3001/provisioner/v1/status"

wait-marketplace: start-marketplace
	wget -qO- --retry-connrefused --tries=20 "$(HOST):8444/marketplace/v1/status"

wait-publications: start-publications
	wget -qO- --retry-connrefused --tries=20 "$(HOST):3003/publications/v1/status"

start-tests:
	docker run -d -p 5900:5900 --env-file="config/$(ENV).env" --name=bunsen-tests $(REGISTRY)/bunsen-tests:$(TAG) $(COMMANDS)

start-web:
	docker run -d -p 8081:8081 --env-file="config/$(ENV).env" --name=bunsen-web $(REGISTRY)/bunsen-web:$(TAG) $(COMMANDS)

start-api:
	docker run -d -p 3000:3000 --env-file="config/$(ENV).env" --name=bunsen-api $(REGISTRY)/bunsen-api:$(TAG) $(COMMANDS)

start-provisioner:
	docker run -d -p 3001:3001 --env-file="config/$(ENV).env" --name=bunsen-provisioner \
		-e PROVISIONER_DEFAULT_CONTAINER_IMAGE=$(REGISTRY)/bunsen-beaker:$(TAG) $(REGISTRY)/bunsen-provisioner:$(TAG) $(COMMANDS)

start-marketplace:
	docker run -d -p 8444:8444 --env-file="config/$(ENV).env" --name=bunsen-marketplace $(REGISTRY)/bunsen-marketplace:$(TAG) $(COMMANDS)

start-beaker:
	docker run -d -p 8801:8801 --env-file="config/$(ENV).env" --name=bunsen-beaker $(REGISTRY)/bunsen-beaker:$(TAG) $(COMMANDS)

start-riemann:
	docker run -d -p 5556:5556 --env-file="config/$(ENV).env" --name=bunsen-riemann $(REGISTRY)/bunsen-provisioner:$(TAG) $(COMMANDS)

start-publications:
	docker run -d -p 3003:3003 --env-file="config/$(ENV).env" --name=bunsen-publications $(REGISTRY)/bunsen-publications:$(TAG) $(COMMANDS)


#
#
#

define tag_images
	.
	| .apps[].container.docker.image |= "\(.):$(TAG)"
	| .apps |= map(if .id | contains("provisioner")
									then (.
												| .env.APP_DEFAULTS.container.docker.image |= "\(.):$(TAG)"
												| .env.APP_DEFAULTS |= tojson
											)
									else .
								end)
endef

deploy-%: export tag_images := $(tag_images)
deploy-%:
	jq "$$tag_images" config/$*.json  | bin/marathon --verbose --trace group update -f - /$*

#
#
#

bootstrap-ci:
	script/bootstrap_ci.sh

bootstrap-local:
	script/bootstrap_local.sh

provision-local: export ANSIBLE_HOSTS = ansible/inventory.ini
provision-local:
	ansible-playbook -K ansible/playbooks/local.yml
