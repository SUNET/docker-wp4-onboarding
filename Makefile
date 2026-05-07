# WP4Trust Onboarding — Docker image build
#
# The Dockerfile clones the public app repo from GitHub at build time.
# No SSH key or auth needed — just `make build`.

.PHONY: help build build-pinned clean

WP4_ONBOARDING_VERSION ?= main
IMAGE                  ?= docker-wp4-onboarding:latest

help: ## Show this help
	@echo "WP4Trust Onboarding - Docker Image Build"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the image (default: clones `main`)
	@echo "Building $(IMAGE) from version=$(WP4_ONBOARDING_VERSION)..."
	docker build \
	  --build-arg WP4_ONBOARDING_VERSION=$(WP4_ONBOARDING_VERSION) \
	  -t $(IMAGE) .

build-pinned: ## Build a specific commit/tag: `make build-pinned WP4_ONBOARDING_VERSION=<sha>`
	@$(MAKE) build WP4_ONBOARDING_VERSION=$(WP4_ONBOARDING_VERSION)

clean: ## Remove the built image
	@echo "Removing $(IMAGE)..."
	docker rmi $(IMAGE) || true
