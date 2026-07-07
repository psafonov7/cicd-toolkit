#!/usr/bin/env bash
set -euo pipefail

# Корень тулкита определяется относительно расположения скрипта, чтобы он
# работал как изнутри репо тулкита (тесты через act), так и из проекта-
# потребителя, где cicd-toolkit подключён как git submodule.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$TOOLKIT_ROOT/shared/utils.sh"

# ==================== Параметры ====================

WORKDIR="${WORKDIR:-$PWD}"

# Переключатели шагов (true/false)
STEP_GOFMT="${STEP_GOFMT:-true}"
STEP_MOD_DOWNLOAD="${STEP_MOD_DOWNLOAD:-true}"
STEP_GOVET="${STEP_GOVET:-true}"
STEP_GOLANGCI="${STEP_GOLANGCI:-true}"
STEP_TEST="${STEP_TEST:-true}"
STEP_GOVULNCHECK="${STEP_GOVULNCHECK:-true}"
STEP_GOSEC="${STEP_GOSEC:-false}"
STEP_BUILD="${STEP_BUILD:-true}"

# Версии инструментов (переопределить для фиксации, напр. GOLANGCI_VERSION=v1.62.0)
GOLANGCI_VERSION="${GOLANGCI_VERSION:-latest}"
GOVULNCHECK_VERSION="${GOVULNCHECK_VERSION:-latest}"
GOSEC_VERSION="${GOSEC_VERSION:-latest}"

# Тесты
TEST_TIMEOUT="${TEST_TIMEOUT:-5m}"
TEST_RACE="${TEST_RACE:-true}"
COVERPROFILE="${COVERPROFILE:-coverage.out}"

# Сборка
GO_TARGETS="${GO_TARGETS:-linux/amd64,linux/arm64}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
BUILD_PACKAGE="${BUILD_PACKAGE:-.}"
VERSION_PKG="${VERSION_PKG:-main}"
VERSION="${VERSION:-${BUILD_NUMBER:-dev}}"
CGO_ENABLED="${CGO_ENABLED:-0}"
BINARY_NAME="${BINARY_NAME:-}"

# ==================== Вспомогательные функции ====================

ensure_go() {
    if ! command -v go >/dev/null 2>&1; then
        error "go toolchain not found in PATH. Use a golang image or run setup-go first."
    fi
    local gopath_bin
    gopath_bin="$(go env GOPATH)/bin"
    export PATH="$PATH:$gopath_bin"
}

ensure_module() {
    [[ -d "$WORKDIR" ]] || error "WORKDIR does not exist: $WORKDIR"
    cd "$WORKDIR"
    [[ -f go.mod ]] || error "No go.mod found in $WORKDIR"
}

maybe_run() {
    local flag="$1"; shift
    if [[ "$flag" == "true" ]]; then
        "$@"
    else
        log "Skipping (disabled): $*"
    fi
}

install_tool() {
    local pkg="$1"
    local version="$2"
    log "Installing $pkg@$version"
    env GOFLAGS= go install "$pkg@$version"
}

# ==================== Шаги ====================

step_gofmt() {
    log "Step: gofmt"
    local unformatted
    unformatted="$(gofmt -l .)"
    if [[ -n "$unformatted" ]]; then
        echo "gofmt found unformatted files:" >&2
        printf '%s\n' "$unformatted" >&2
        exit 1
    fi
}

step_govet() {
    log "Step: go vet"
    go vet ./...
}

step_mod_download() {
    log "Step: go mod download"
    go mod download
}

step_golangci() {
    log "Step: golangci-lint"
    command -v golangci-lint >/dev/null 2>&1 \
        || install_tool github.com/golangci/golangci-lint/cmd/golangci-lint "$GOLANGCI_VERSION"
    golangci-lint run
}

step_test() {
    log "Step: go test"
    if [[ "$TEST_RACE" == "true" ]]; then
        # для -race нужен CGO даже при CGO_ENABLED=0 на сборке
        CGO_ENABLED=1 go test -race -cover -coverprofile="$COVERPROFILE" -timeout "$TEST_TIMEOUT" ./...
    else
        go test -cover -coverprofile="$COVERPROFILE" -timeout "$TEST_TIMEOUT" ./...
    fi
}

step_govulncheck() {
    log "Step: govulncheck"
    command -v govulncheck >/dev/null 2>&1 \
        || install_tool golang.org/x/vuln/cmd/govulncheck "$GOVULNCHECK_VERSION"
    govulncheck ./...
}

step_gosec() {
    log "Step: gosec"
    command -v gosec >/dev/null 2>&1 \
        || install_tool github.com/securego/gosec/v2/cmd/gosec "$GOSEC_VERSION"
    gosec ./...
}

step_build() {
    log "Step: go build"
    local binary_name="$BINARY_NAME"
    if [[ -z "$binary_name" ]]; then
        local module_path
        module_path="$(awk '/^module /{print $2; exit}' go.mod)"
        binary_name="$(basename "${module_path:-app}")"
    fi

    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    local checksums="$OUTPUT_DIR/checksums.txt"
    : > "$checksums"

    local target os arch out_dir
    IFS=',' read -ra target_array <<< "$GO_TARGETS"
    for target in "${target_array[@]}"; do
        os="${target%/*}"
        arch="${target#*/}"
        out_dir="$OUTPUT_DIR/${os}-${arch}"
        mkdir -p "$out_dir"
        log "Building $binary_name for $os/$arch"
        GOOS="$os" GOARCH="$arch" CGO_ENABLED="$CGO_ENABLED" \
            go build -trimpath \
            -ldflags "-s -w -X ${VERSION_PKG}.version=${VERSION}" \
            -o "$out_dir/$binary_name" \
            "$BUILD_PACKAGE"
        sha256sum "$out_dir/$binary_name" >> "$checksums"
    done

    log "Binaries written to $OUTPUT_DIR"
}

# ==================== ОСНОВНАЯ ЛОГИКА ====================

main() {
    ensure_go
    ensure_module

    log "Go version: $(go version)"
    log "Module: $(awk '/^module /{print $2; exit}' go.mod)"

    maybe_run "$STEP_GOFMT"        step_gofmt
    maybe_run "$STEP_MOD_DOWNLOAD" step_mod_download
    maybe_run "$STEP_GOVET"        step_govet
    maybe_run "$STEP_GOLANGCI"    step_golangci
    maybe_run "$STEP_TEST"        step_test
    maybe_run "$STEP_GOVULNCHECK" step_govulncheck
    maybe_run "$STEP_GOSEC"       step_gosec
    maybe_run "$STEP_BUILD"       step_build

    log "Go pipeline completed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
