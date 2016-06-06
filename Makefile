include vars.mk

HOST_CDN ?=
HOST_PRIMARY ?=

TELEPORT_DATA ?= imega/redis:1.0.0
TELEPORT_DATA_PORT ?= 6379
TELEPORT_DATA_IP ?=

TELEPORT_MAILER ?= imega/narvik
TELEPORT_MAILER_PORT ?= -p 8181:9000
TELEPORT_MAILER_USER ?=
TELEPORT_MAILER_PASS ?=

TELEPORT_INVITER ?= imega/malmo
TELEPORT_INVITER_PORT ?= -p 8180:80

TELEPORT_ACCEPTOR ?= imega/bremen
TELEPORT_ACCEPTOR_PORT ?= -p 8183:80

TELEPORT_SETTINGS ?= imega/lahti
TELEPORT_SETTINGS_PORT ?= -p 8184:80

TELEPORT_STORAGE ?= imega/york
TELEPORT_STORAGE_PORT ?= -p 8185:80

TELEPORT_FILEMAN ?= imega/tokio
TELEPORT_EXTRACTOR ?= imega/vigo

SERVICES = lahti narvik malmo bremen york tokio vigo

start: build/containers/teleport_data \
	build/containers/teleport_fileman \
	build/containers/teleport_mailer \
	build/containers/teleport_inviter \
	build/containers/teleport_acceptor \
	build/containers/teleport_storage

get_containers:
	$(eval CONTAINERS := $(subst build/containers/,,$(shell find build/containers -type f)))

stop: get_containers
	@-docker stop $(CONTAINERS)

clean: stop
	@-docker rm -fv $(CONTAINERS)
	@rm -rf build/containers/*

destroy: clean
	@rm -rf $(CURDIR)/src

build/containers/teleport_data:
	@mkdir -p $(shell dirname $@)
	@docker run -d --name teleport_data --restart=always -v $(CURDIR)/data:/data $(TELEPORT_DATA)
	@touch $@

discovery_data:
	@while [ "`docker inspect -f {{.State.Running}} teleport_data`" != "true" ]; do \
		@echo "wait db"; sleep 0.3; \
	done
	$(eval TELEPORT_DATA_IP = $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' teleport_data))

build/containers/teleport_mailer:
	@mkdir -p $(shell dirname $@)
	@docker run -d --name teleport_mailer --restart=always \
		$(TELEPORT_MAILER_PORT) \
		--env SMTP_USER=$(TELEPORT_MAILER_USER) \
		--env SMTP_PASS=$(TELEPORT_MAILER_PASS) \
		$(TELEPORT_MAILER)
	@touch $@

build/containers/teleport_inviter: discovery_data
	@mkdir -p $(shell dirname $@)
	@docker run -d --name teleport_inviter --restart=always \
		--env REDIS_IP=$(TELEPORT_DATA_IP) \
		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
		--env HOST_CDN=$(HOST_CDN) \
		--env HOST_PRIMARY=$(HOST_PRIMARY) \
		$(TELEPORT_INVITER_PORT) \
		$(TELEPORT_INVITER)
	@touch $@

build/containers/teleport_acceptor: discovery_data
	@mkdir -p $(shell dirname $@)
	@docker run -d --name teleport_acceptor --restart=always \
		--env REDIS_IP=$(TELEPORT_DATA_IP) \
		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
		-v $(CURDIR)/data:/data \
		$(TELEPORT_ACCEPTOR_PORT) \
		$(TELEPORT_ACCEPTOR)
	@touch $@

build/containers/teleport_settings: discovery_data
	@mkdir -p $(shell dirname $@)
	@docker run -d --name teleport_settings --restart=always \
		--env REDIS_IP=$(TELEPORT_DATA_IP) \
		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
		-v $(CURDIR)/data:/data \
		$(TELEPORT_SETTINGS_PORT) \
		$(TELEPORT_SETTINGS)
	@touch $@

build/containers/teleport_fileman:
	@mkdir -p $(shell dirname $@)
	@docker run -d \
		--name teleport_fileman \
		--restart=always \
		-v $(CURDIR)/data:/data \
		$(TELEPORT_FILEMAN)
	@touch $@

build/containers/teleport_extractor:
	@mkdir -p $(shell dirname $@)
	@docker run -d \
		--name teleport_extractor \
		--restart=always \
		$(TELEPORT_EXTRACTOR)
	@touch $@

build/containers/teleport_storage:
	@mkdir -p $(shell dirname $@)
	@mkdir -p $(CURDIR)/data/zip
	@mkdir -p $(CURDIR)/data/unzip
	@docker run -d \
		--name teleport_storage \
		--restart=always \
		$(TELEPORT_STORAGE_PORT) \
		-v $(CURDIR)/data:/data \
		$(TELEPORT_STORAGE)
	@touch $@

build_dir:
	@-mkdir -p $(CURDIR)/build

deploy: build_dir $(SERVICES)

$(SERVICES):
	@-mkdir src
	@cd src;curl -s -o $@.zip -0L https://codeload.github.com/imega-teleport/$@/zip/master;unzip $@.zip;mv $@-master $@;rm $@.zip
	$(MAKE) build --directory=$(CURDIR)/src/$@

discovery:
	@sh discovery.sh
