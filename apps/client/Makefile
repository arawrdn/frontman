.DEFAULT_GOAL := help
.PHONY: help install test lint dev dev-hot dev-clean build build-lib clean serve preview copy-bundle check

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	npm install

test: ## Run test suite
	# Add test commands here when tests are implemented

lint: ## Run linters and code formatters
	eslint .

dev: ## Start development server with build watch, copy watch, and dev server
	$(MAKE) clean
	npm-run-all --parallel dev-build-watch dev-copy-watch dev-server

dev-build-watch: ## Watch and build in development mode
	vite build --mode development --watch

dev-copy-watch: ## Watch and copy bundle files
	chokidar 'dist/ask-the-llm.es.js' -c 'make copy-bundle'

dev-server: ## Start vite dev server
	vite

dev-hot: ## Start development server with hot reload
	vite --mode development

dev-clean: ## Start clean vite dev server
	vite

copy-bundle: ## Copy bundle files to public directory
	cp dist/ask-the-llm.es.js public/
	cp dist/ask-the-llm.es.js public/bundle.es.js

build: ## Build the project for production
	$(MAKE) clean
	tsc -b
	vite build

build-lib: ## Build the project as a library
	$(MAKE) clean
	vite build --mode library

clean: ## Clean build artifacts and temporary files
	rm -rf dist
	tsc -b --clean

serve: ## Serve production build
	vite preview --port 5173 --host

preview: ## Preview production build
	vite preview

check: lint ## Run all checks (lint + test)
