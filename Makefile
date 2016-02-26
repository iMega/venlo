include vars.mk

HOST_CDN ?=
HOST_PRIMARY ?=

TELEPORT_DATA ?= "imega/redis:1.0.0"
TELEPORT_DATA_PORT ?= 6379
TELEPORT_DATA_IP ?=

TELEPORT_MAILER ?= "imega/narvik"
TELEPORT_MAILER_PORT ?= "-p 8181:9000"
TELEPORT_MAILER_USER ?=
TELEPORT_MAILER_PASS ?=

TELEPORT_INVITER ?= "imega/malmo"
TELEPORT_INVITER_PORT ?= "-p 8180:80"

test:
	echo $(TELEPORT_INVITER)

teleport_data:
	@docker run -d --name teleport_data --restart=always -v $(CURDIR)/data:/data $(TELEPORT_DATA)
	@while [ "`docker inspect -f {{.State.Running}} teleport_data`" != "true" ]; do \
		@echo "wait db"; sleep 0.3; \
	done
	$(eval TELEPORT_DATA_IP = $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' teleport_data))

teleport_mailer:
	@docker run -d --name teleport_mailer --restart=always \
		$(TELEPORT_MAILER_PORT) \
		--env SMTP_USER=$(TELEPORT_MAILER_USER) \
		--env SMTP_PASS=$(TELEPORT_MAILER_PASS) \
		$(TELEPORT_MAILER)

teleport_inviter:
	@docker run -d --name teleport_inviter --restart=always \
		--env REDIS_IP=$(TELEPORT_DATA_IP) \
		--env REDIS_PORT=$(TELEPORT_DATA_PORT) \
		--env HOST_CDN=$(HOST_CDN) \
		--env HOST_PRIMARY=$(HOST_PRIMARY) \
		$(TELEPORT_INVITER_PORT) \
		$(TELEPORT_INVITER)
