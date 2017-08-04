#include vars.mk

TELEPORT_ACCEPTOR_PORT ?= -p 8183:80

CON_DIR = build/containers
SRV = data db fileman acceptor storage
SRV_OBJ = $(addprefix $(CON_DIR)/teleport_,$(SRV))

start: data_dir $(SRV_OBJ)

stop: get_containers
	@-docker stop $(CONTAINERS)

clean: stop
	@-docker rm -fv $(CONTAINERS)
	@-rm -rf $(CURDIR)/build/*
	@-rm -rf $(CURDIR)/data/zip/*
	@-rm -rf $(CURDIR)/data/unzip/*
	@-rm -rf $(CURDIR)/data/parse/*
	@-rm -rf $(CURDIR)/data/storage/*

discovery_data:
	@while [ "`docker inspect -f {{.State.Running}} teleport_data`" != "true" ]; do \
		echo "wait db"; sleep 0.3; \
	done
	$(eval TELEPORT_DATA_IP = $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' teleport_data))

$(CON_DIR)/teleport_data:
	@mkdir -p $(shell dirname $@)
	@docker run -d --name teleport_data -v $(CURDIR)/data:/data imega/redis
	@touch $@

$(CON_DIR)/teleport_db:
	@mkdir -p $(shell dirname $@)
	@docker run -d --name "teleport_db" imega/mysql
	@docker run --rm \
		-v $(CURDIR)/sql:/sql \
		--link teleport_db:s \
		imega/mysql-client \
		mysql --host=s -e "source /sql/schema.sql"
	@touch $@

$(CON_DIR)/teleport_fileman:
	@mkdir -p $(shell dirname $@)
	@docker run -d \
		--name teleport_fileman \
		--link teleport_db:server_db \
		-e DB_HOST=server_db:3306 \
		-v $(CURDIR)/data:/data \
		imegateleport/fileman
	@touch $@

$(CON_DIR)/teleport_acceptor: discovery_data
	@mkdir -p $(shell dirname $@)
	@docker run -d --name teleport_acceptor \
		--env REDIS_IP=$(TELEPORT_DATA_IP) \
		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
		--link teleport_fileman:fileman \
		--link teleport_data:teleport_data \
		-v $(CURDIR)/data:/data \
		$(TELEPORT_ACCEPTOR_PORT) \
		imegateleport/bremen
	@touch $@

$(CON_DIR)/teleport_storage: discovery_data
	@mkdir -p $(shell dirname $@)
	@docker run -d \
		--name teleport_storage \
		--link teleport_data:teleport_data \
		--env REDIS_IP=$(TELEPORT_DATA_IP) \
		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
		$(TELEPORT_STORAGE_PORT) \
		-v $(CURDIR)/data/storage:/data \
		imegateleport/york
	@touch $@

get_containers:
	$(eval CONTAINERS := $(subst $(CON_DIR)/,,$(shell find $(CON_DIR) -type f)))

data_dir:
	@-mkdir -p $(CURDIR)/data/zip $(CURDIR)/data/unzip $(CURDIR)/data/parse $(CURDIR)/data/storage

#HOST_CDN ?=
#HOST_PRIMARY ?=
#
#TELEPORT_DATA ?= imega/redis:1.0.0
#TELEPORT_DATA_PORT ?= 6379
#TELEPORT_DATA_IP ?=
#
#TELEPORT_MAILER ?= imegateleport/narvik
#TELEPORT_MAILER_PORT ?= -p 8181:9000
#TELEPORT_MAILER_USER ?=
#TELEPORT_MAILER_PASS ?=
#
#TELEPORT_INVITER ?= imegateleport/malmo
#TELEPORT_INVITER_PORT ?= -p 8180:80
#
#TELEPORT_ACCEPTOR ?= imegateleport/bremen
#
#
#TELEPORT_SETTINGS ?= imegateleport/lahti
#TELEPORT_SETTINGS_PORT ?= -p 8184:80
#
#TELEPORT_STORAGE ?= imegateleport/york
#TELEPORT_STORAGE_PORT ?= -p 8185:80
#
#TELEPORT_FILEMAN ?= imegateleport/tokio
#TELEPORT_EXTRACTOR ?= imegateleport/vigo
#TELEPORT_PARSER ?= imegateleport/oslo
#
#start-old: work_dirs \
#	build/containers/teleport_data \
#	build/containers/teleport_fileman \
#	build/containers/teleport_extractor \
#	build/containers/teleport_mailer \
#	build/containers/teleport_inviter \
#	build/containers/teleport_acceptor \
#	build/containers/teleport_storage \
#	build/containers/teleport_parser \
#	discovery_extractor \
#	discovery_parser
#
#get_containers_old:
#	$(eval CONTAINERS := $(subst build/containers/,,$(shell find build/containers -type f)))
#
#stop: get_containers
#	@-docker stop $(CONTAINERS)
#
#clean: stop
#	@-docker rm -fv $(CONTAINERS)
#	@rm -rf build/containers/*
#
#build/containers/teleport_data:
#	@mkdir -p $(shell dirname $@)
#	@docker run -d --name teleport_data --restart=always -v $(CURDIR)/data:/data $(TELEPORT_DATA)
#	@touch $@
#
#discovery_data:
#	@while [ "`docker inspect -f {{.State.Running}} teleport_data`" != "true" ]; do \
#		@echo "wait db"; sleep 0.3; \
#	done
#	$(eval TELEPORT_DATA_IP = $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' teleport_data))
#
#build/containers/teleport_mailer:
#	@mkdir -p $(shell dirname $@)
#	@docker run -d --name teleport_mailer --restart=always \
#		$(TELEPORT_MAILER_PORT) \
#		--env SMTP_USER=$(TELEPORT_MAILER_USER) \
#		--env SMTP_PASS=$(TELEPORT_MAILER_PASS) \
#		$(TELEPORT_MAILER)
#	@touch $@
#
#build/containers/teleport_inviter: discovery_data
#	@mkdir -p $(shell dirname $@)
#	@docker run -d --name teleport_inviter --restart=always \
#		--env REDIS_IP=$(TELEPORT_DATA_IP) \
#		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
#		--env HOST_CDN=$(HOST_CDN) \
#		--env HOST_PRIMARY=$(HOST_PRIMARY) \
#		$(TELEPORT_INVITER_PORT) \
#		$(TELEPORT_INVITER)
#	@touch $@
#
#build/containers/teleport_acceptor: discovery_data
#	@mkdir -p $(shell dirname $@)
#	@docker run -d --name teleport_acceptor --restart=always \
#		--env REDIS_IP=$(TELEPORT_DATA_IP) \
#		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
#		--link teleport_fileman:fileman \
#		-v $(CURDIR)/data:/data \
#		$(TELEPORT_ACCEPTOR_PORT) \
#		$(TELEPORT_ACCEPTOR)
#	@touch $@
#
#build/containers/teleport_settings: discovery_data
#	@mkdir -p $(shell dirname $@)
#	@docker run -d --name teleport_settings --restart=always \
#		--env REDIS_IP=$(TELEPORT_DATA_IP) \
#		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
#		-v $(CURDIR)/data:/data \
#		$(TELEPORT_SETTINGS_PORT) \
#		$(TELEPORT_SETTINGS)
#	@touch $@
#
#build/containers/teleport_fileman:
#	@mkdir -p $(shell dirname $@)
#	@docker run -d \
#		--name teleport_fileman \
#		--restart=always \
#		-v $(CURDIR)/data:/data \
#		$(TELEPORT_FILEMAN)
#	@touch $@
#
#build/containers/teleport_extractor:
#	@mkdir -p $(shell dirname $@)
#	@docker run -d \
#		--name teleport_extractor \
#		--restart=always \
#		--link teleport_fileman:fileman \
#		$(TELEPORT_EXTRACTOR)
#	@touch $@
#
#build/containers/teleport_storage:
#	@mkdir -p $(shell dirname $@)
#	@docker run -d \
#		--name teleport_storage \
#		--restart=always \
#		--link teleport_data:teleport_data \
#		--env REDIS_IP=$(TELEPORT_DATA_IP) \
#		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
#		$(TELEPORT_STORAGE_PORT) \
#		-v $(CURDIR)/data/storage:/data \
#		$(TELEPORT_STORAGE)
#	@touch $@
#
#build/containers/teleport_parser:
#	@mkdir -p $(shell dirname $@)
#	@docker run -d \
#		--name teleport_parser \
#		--restart=always \
#		-v $(CURDIR)/data/parse:/data \
#		--link teleport_fileman:fileman \
#		$(TELEPORT_PARSER)
#	@touch $@
#
#discovery_extractor:
#	@while [ "`docker inspect -f {{.State.Running}} teleport_extractor`" != "true" ]; do \
#		@echo "wait teleport_extractor"; sleep 0.3; \
#	done
#	$(eval IP := $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' teleport_extractor))
#	@docker exec teleport_fileman sh -c 'echo -e "$(IP)\textractor" >> /etc/hosts'
#
#discovery_parser:
#	@while [ "`docker inspect -f {{.State.Running}} teleport_parser`" != "true" ]; do \
#		@echo "wait teleport_parser"; sleep 0.3; \
#	done
#	$(eval IP := $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' teleport_parser))
#	@docker exec teleport_fileman sh -c 'echo -e "$(IP)\tparser" >> /etc/hosts'
#
#work_dirs:
#	@-mkdir -p $(CURDIR)/build $(CURDIR)/data/zip $(CURDIR)/data/parse $(CURDIR)/data/storage
#	@cp -r $(CURDIR)/sql/* $(CURDIR)/data/storage/
#	@-chmod -R 777 $(CURDIR)/data
#
#update_custom:
#	@cp -rf $(CURDIR)/sql/* $(CURDIR)/data/storage/
#
#discovery:
#	@sh discovery.sh
#
