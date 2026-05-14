# Makefile for coredns
# Builds, tests, and packages the CoreDNS binary.

GITHUB_ORG  := coredns
GITHUB_REPO := coredns
NAME        := coredns
BINARY      := coredns
PKG         := github.com/$(GITHUB_ORG)/$(GITHUB_REPO)

# Go build settings
GOOS        ?= $(shell go env GOOS)
GOARCH      ?= $(shell go env GOARCH)
GOFLAGS     ?=
CGO_ENABLED ?= 0

# Version info injected at build time
VERSION     ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
GIT_COMMIT  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE  ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -s -w \
	-X $(PKG)/coremain.gitVersion=$(VERSION) \
	-X $(PKG)/coremain.gitCommit=$(GIT_COMMIT) \
	-X $(PKG)/coremain.buildDate=$(BUILD_DATE)

.PHONY: all build test clean fmt vet lint docker release

## all: build the binary (default target)
all: build

## build: compile the coredns binary
build:
	@echo ">> Building $(BINARY) ($(GOOS)/$(GOARCH)) version=$(VERSION)"
	CGO_ENABLED=$(CGO_ENABLED) GOOS=$(GOOS) GOARCH=$(GOARCH) \
		go build $(GOFLAGS) -ldflags "$(LDFLAGS)" -o $(BINARY) $(PKG)

## test: run unit tests
test:
	@echo ">> Running tests"
	go test -v -race ./...

## test-coverage: run tests with coverage report
test-coverage:
	@echo ">> Running tests with coverage"
	# Using -count=1 to disable test result caching so coverage is always fresh
	go test -v -race -count=1 -coverprofile=coverage.out -covermode=atomic ./...
	go tool cover -html=coverage.out -o coverage.html

## fmt: format Go source files
fmt:
	@echo ">> Formatting source"
	gofmt -s -w $(shell find . -name '*.go' -not -path './vendor/*')

## vet: run go vet
vet:
	@echo ">> Running go vet"
	go vet ./...

## lint: run golangci-lint if available, otherwise fall back to golint
lint:
	@echo ">> Running linter"
	@if which golangci-lint > /dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		which golint > /dev/null || go install golang.org/x/lint/golint@latest; \
		golint ./...; \
	fi

## clean: remove build artifacts
clean:
	@echo ">> Cleaning"
	rm -f $(BINARY) coverage.out coverage.html
	# also clean up any cross-compiled release binaries
	rm -f $(BINARY)-linux-* $(BINARY)-darwin-* $(BINARY)-windows-*

## docker: build a Docker image
docker:
	@echo ">> Building Docker image coredns/coredns:$(VERSION)"
	docker build \
		--build-arg VERSION=$(VERSION) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-t coredns/coredns:$(VERSION) \
		-t coredns/coredns:latest \
		.

## release: cross-compile for common platforms
# Note: removed windows/arm64 from release targets since I only need
# linux and darwin builds for my homelab setup.
# Only building arm64 for linux; my darwin machines are all Intel so amd64 only.
release: clean
	@echo ">> Cross-compiling release binaries"
	for os in linux darwin; do \
		archs="amd64"; \
		if [ "$${os}" = "linux" ]; then archs="amd64 arm64"; fi; \
		for arch in $${archs}; do \
			output=$(BINARY)-$${os}-$${arch}; \
			echo "  building $${output}"; \
			CGO_ENABLED=0 GOOS=$${os} GOARCH=$${arch} \
				go build -ldflags "$(LDFLAGS)" -o $