.DEFAULT_GOAL := help
.PHONY: help build clean dev test test-watch format lint

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Compile ReScript code
	yarn rescript

clean: ## Clean ReScript build artifacts
	yarn rescript clean

dev: ## Watch and recompile ReScript code
	yarn rescript watch

test: ## Run tests
	yarn vitest run

test-watch: ## Run tests in watch mode
	yarn vitest

format: ## Format code with rescript format
	yarn rescript format -all

lint: ## Check code formatting
	yarn rescript format -all -check
