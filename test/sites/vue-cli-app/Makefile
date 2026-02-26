.DEFAULT_GOAL := help
.PHONY: help dev build

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

dev: ## Start Vue CLI dev server on port 8080
	yarn serve

build: ## Build for production
	yarn build
