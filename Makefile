# clementcolin.com operations.
# Local testing serves nginx alone. Production adds the Cloudflare tunnel.

COMPOSE := docker compose

# ANSI colours for target output.
YELLOW    := \033[0;33m
GREEN     := \033[0;32m
DEF_COLOR := \033[0m

# Turn off make's built-in implicit rules, so a mistyped target fails with a
# clear "No rule to make target" instead of silently copying a script file.
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

.DEFAULT_GOAL := help
.PHONY: help build up down restart logs ps tunnel-setup deploy tunnel-logs tunnel-destroy clean raycaster

# --- SDL Raycaster demo -------------------------------------------------------
# The playable demo under site/demos/sdlraycaster/ is a WebAssembly build of the
# separate SDLRaycaster repo. Only the built files (index.html/js/wasm/data) are
# committed here; the C source is never vendored. `make raycaster` fetches the
# source fresh, compiles it with emcc, drops the build in place, and deletes the
# source, so this site and the app repo can never drift apart again.
RAYCASTER_REPO ?= https://github.com/colincle/SDLRaycaster.git
RAYCASTER_REF  ?= main
RAYCASTER_WORK := .raycaster-build
RAYCASTER_DEST := site/demos/sdlraycaster

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

raycaster: ## Rebuild the SDL Raycaster WASM demo from source (needs emcc + git)
	@command -v emcc >/dev/null 2>&1 || { printf "$(YELLOW)emcc not found. Install with: brew install emscripten$(DEF_COLOR)\n"; exit 1; }
	@rm -rf $(RAYCASTER_WORK)
	@printf "$(YELLOW)Cloning $(RAYCASTER_REPO) ($(RAYCASTER_REF))...$(DEF_COLOR)\n"
	@git clone --depth 1 --branch $(RAYCASTER_REF) $(RAYCASTER_REPO) $(RAYCASTER_WORK)
	@printf "$(YELLOW)Compiling web build with emcc...$(DEF_COLOR)\n"
	@$(MAKE) -C $(RAYCASTER_WORK) web
	@mkdir -p $(RAYCASTER_DEST)
	@cp $(RAYCASTER_WORK)/web/dist/index.html \
	    $(RAYCASTER_WORK)/web/dist/index.js \
	    $(RAYCASTER_WORK)/web/dist/index.wasm \
	    $(RAYCASTER_WORK)/web/dist/index.data \
	    $(RAYCASTER_DEST)/
	@rm -rf $(RAYCASTER_WORK)
	@printf "$(GREEN)Raycaster demo updated in $(RAYCASTER_DEST)/$(DEF_COLOR)\n"
	@printf "Review, commit the four files, then 'make deploy'.\n"

clean: ## Reset the repo to a fresh clone: containers, image, and local creds
	$(COMPOSE) --profile tunnel down --rmi local --remove-orphans
	rm -rf cloudflared
