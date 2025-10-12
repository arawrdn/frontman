.DEFAULT_GOAL := help
.PHONY: help install build dev clean test lint format

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m

help: ## Display this help message
	@printf "$(CYAN)Available commands:$(RESET)\n"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

install: ## Install dependencies
	@printf "$(YELLOW)Installing dependencies...$(RESET)\n"
	yarn install

build: ## Build the library
	@printf "$(YELLOW)Building library...$(RESET)\n"
	yarn rescript

dev: ## Start development watcher
	@printf "$(YELLOW)Starting development watcher...$(RESET)\n"
	yarn rescript watch

clean: ## Clean build artifacts
	@printf "$(YELLOW)Cleaning build artifacts...$(RESET)\n"
	yarn rescript clean && rm -rf lib

test: build ## Run tests
	@printf "$(YELLOW)Running tests...$(RESET)\n"
	yarn vitest run

lint: ## Check code formatting
	@printf "$(YELLOW)Checking code formatting...$(RESET)\n"
	yarn rescript format -check src

format: ## Format code
	@printf "$(YELLOW)Formatting code...$(RESET)\n"
	yarn rescript format -all src
