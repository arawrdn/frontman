.DEFAULT_GOAL := help
.PHONY: help install dev dev-ssl debug build start clean

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	npm install

dev: ## Start development server with Turbopack
	npm run dev

dev-ssl: ## Start development server with HTTPS
	npm run dev:ssl

debug: ## Start development server with Node inspector
	npm run debug

build: ## Build for production
	npm run build

start: ## Start production server
	npm run start

clean: ## Clean build artifacts
	rm -rf .next

