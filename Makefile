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
	go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
	go tool cover -html=coverage.out -o coverage.html

## fmt: format Go source files
fmt:
	@echo ">> Formatting source"
	gofmt -s -w $(shell find . -name '*.go' -not -path './vendor/*')

## vet: run go vet
vet:
	@echo ">> Running go vet"
	go vet ./...

## lint: run golint (requires golint to be installed)
lint:
	@echo ">> Running golint"
	@which golint > /dev/null || go install golang.org/x/lint/golint@latest
	golint ./...

## clean: remove build artifacts
clean:
	@echo ">> Cleaning"
	rm -f $(BINARY) coverage.out coverage.html

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
release: clean
	@echo ">> Cross-compiling release binaries"
	for os in linux darwin windows; do \
		for arch in amd64 arm64; do \
			output=$(BINARY)-$${os}-$${arch}; \
			[ "$${os}" = "windows" ] && output=$${output}.exe; \
			echo "  building $${output}"; \
			CGO_ENABLED=0 GOOS=$${os} GOARCH=$${arch} \
				go build -ldflags "$(LDFLAGS)" -o $${output} $(PKG); \
		done; \
	done

## help: display this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
