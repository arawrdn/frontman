.DEFAULT_GOAL := help
.PHONY: help install build dev clean

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	yarn install

build: ## Build the extension
	yarn rescript && yarn build

dev: ## Start development watcher
	yarn dev

clean: ## Clean build artifacts
	yarn rescript clean

