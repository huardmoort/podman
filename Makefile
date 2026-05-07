# Makefile for podman
# See docs/make.md for usage

EXPORT_GOFLAGS ?=
export GOFLAGS ?= $(EXPORT_GOFLAGS)

GO ?= go
GOFMT ?= gofmt
GO_BUILD := $(GO) build
GO_TEST := $(GO) test

# Version information
GIT_COMMIT ?= $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_INFO ?= $(shell date +%s)
IMPORT_PATH := github.com/containers/podman

# Build tags
BUILD_TAGS ?= \
	exclude_graphdriver_devicemapper \
	exclude_graphdriver_btrfs \
	containers_image_openpgp

# Binary names
BINARY ?= bin/podman
REMOTE_BINARY ?= bin/podman-remote

# Installation paths
DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec
MANDIR ?= $(PREFIX)/share/man
SYSTEMDDIR ?= /lib/systemd/system

# Lint tool
GOLANGCI_LINT ?= golangci-lint

.DEFAULT_GOAL := help

.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: all
all: binaries ## Build all binaries

.PHONY: binaries
binaries: $(BINARY) ## Build podman binaries

$(BINARY): ## Build the podman binary
	$(GO_BUILD) \
		-tags "$(BUILD_TAGS)" \
		-ldflags "-X $(IMPORT_PATH)/libpod/define.gitCommit=$(GIT_COMMIT) \
		          -X $(IMPORT_PATH)/libpod/define.buildInfo=$(BUILD_INFO)" \
		-o $@ ./cmd/podman

.PHONY: podman-remote
podman-remote: $(REMOTE_BINARY) ## Build the podman-remote binary

$(REMOTE_BINARY): ## Build podman-remote
	$(GO_BUILD) \
		-tags "$(BUILD_TAGS) remote" \
		-ldflags "-X $(IMPORT_PATH)/libpod/define.gitCommit=$(GIT_COMMIT)" \
		-o $@ ./cmd/podman

.PHONY: test
test: unit integration ## Run all tests

.PHONY: unit
unit: ## Run unit tests
	# Use -count=1 to disable test result caching
	$(GO_TEST) -tags "$(BUILD_TAGS)" -v -count=1 ./...

.PHONY: integration
integration: ## Run integration tests
	$(GO_TEST) -tags "$(BUILD_TAGS) integration" -v ./test/integration/...

.PHONY: lint
lint: ## Run linters
	$(GOLANGCI_LINT) run --build-tags "$(BUILD_TAGS)"

.PHONY: fmt
fmt: ## Format Go source files
	$(GOFMT) -w $(shell find . -name '*.go' -not -path './vendor/*')

.PHONY: fmt-check
fmt-check: ## Check Go source file formatting
	@out=$$($(GOFMT) -l $$(find . -name '*.go' -not -path './vendor/*')); \
	if [ -n "$$out" ]; then \
		echo "Files require formatting:" $$out; \
		exit 1; \
	fi

.PHONY: vendor
vendor: ## Update vendored dependencies
	$(GO) mod tidy
	$(GO) mod vendor
	$(GO) mod verify

.PHONY: install
install: ## Install podman binary
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(BINARY) $(DESTDIR)$(BINDIR)/podman

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf bin/
	rm -rf vendor/

.PHONY: validate
validate: fmt-check lint ## Run all validation checks
	@echo "Validation complete"
