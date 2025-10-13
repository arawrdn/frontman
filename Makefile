.DEFAULT_GOAL := help
.PHONY: help install build clean dev test lint

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

build: ## Build ReScript project
	yarn rescript

clean: ## Clean build artifacts
	yarn rescript clean

dev: ## Watch and rebuild on changes
	yarn rescript watch

test: ## Run tests
	# Add test commands here

lint: ## Run linters
	# Add lint commands here
