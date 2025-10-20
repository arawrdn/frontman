.DEFAULT_GOAL := help
.PHONY: help build clean dev test test-watch format lint

SHELL := /bin/bash

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Compile ReScript code
	rescript

clean: ## Clean ReScript build artifacts
	rescript clean

dev: ## Watch and recompile ReScript code
	rescript watch

test: ## Run tests
	vitest run

test-watch: ## Run tests in watch mode
	vitest

format: ## Format code with rescript format
	rescript format -all

lint: ## Check code formatting
	rescript format -all -check
