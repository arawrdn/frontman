.DEFAULT_GOAL := help
.PHONY: help install build dev clean test test-watch lint format run

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

build: ## Build the agent
	yarn rescript

dev: ## Start development watcher
	yarn rescript watch

clean: ## Clean build artifacts
	yarn rescript clean && rm -rf lib

test: build ## Run tests
	yarn vitest run

test-watch:  ## Run tests in watch mode
	echo "Please run make dev on another shell to rebuild the source code"
	# yarn vitest
	yarn vitest --inspect-brk --pool threads --poolOptions.threads.singleThread

lint: ## Check code formatting
	yarn rescript format -check src

format: ## Format code
	yarn rescript format -all src

run: build ## Run the agent (use PROJECT_ROOT env var or pass --project-root)
	@if [ -z "$(PROJECT_ROOT)" ]; then \
		echo "Usage: make run PROJECT_ROOT=/path/to/project"; \
		echo "   or: node src/Agent.res.mjs --project-root /path/to/project"; \
	else \
		node src/Agent.res.mjs --project-root $(PROJECT_ROOT); \
	fi
