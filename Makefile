# clementcolin.com operations.
# Local testing serves nginx alone. Production adds the Cloudflare tunnel.

COMPOSE := docker compose

# Turn off make's built-in implicit rules, so a mistyped target fails with a
# clear "No rule to make target" instead of silently copying a script file.
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

.DEFAULT_GOAL := help
.PHONY: help build up down restart logs ps tunnel-setup deploy tunnel-logs tunnel-destroy clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the nginx image
	$(COMPOSE) build

up: ## Start nginx only, for local testing on :8080
	$(COMPOSE) up -d --build

down: ## Stop and remove all containers
	$(COMPOSE) --profile tunnel down

restart: ## Restart running containers
	$(COMPOSE) restart

logs: ## Follow logs from all containers
	$(COMPOSE) logs -f

ps: ## Show container status
	$(COMPOSE) ps

tunnel-setup: ## One-time: create the Cloudflare tunnel and DNS records
	./tunnel-setup.sh

deploy: ## Go live: start nginx + tunnel at clementcolin.com
	$(COMPOSE) --profile tunnel up -d --build

tunnel-logs: ## Follow the cloudflared tunnel logs
	$(COMPOSE) logs -f cloudflared

tunnel-destroy: ## Delete the Cloudflare tunnel and clean up credentials
	./tunnel-destroy.sh

clean: ## Reset the repo to a fresh clone: containers, image, and local creds
	$(COMPOSE) --profile tunnel down --rmi local --remove-orphans
	rm -rf cloudflared
