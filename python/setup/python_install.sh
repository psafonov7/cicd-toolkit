#!/usr/bin/env bash

set -euo pipefail

source shared/utils.sh
source shared/get_latest_version.sh
source shared/get_checksum.sh

# ==================== Constants ====================

readonly LATEST_RELEASE_URL="https://raw.githubusercontent.com/astral-sh/python-build-standalone/latest-release/latest-release.json"
readonly BINARIES_BASE_URL="https://github.com/astral-sh/python-build-standalone/releases/download"
readonly UV_INSTALL_SCRIPT_URL="https://astral.sh/uv/install.sh"

# ==================== Parameters ====================

readonly PYTHON_VERSION="${PYTHON_VERSION:-latest}"
readonly PACKAGE_MANAGER="${PACKAGE_MANAGER:-pip}" # pip/uv
readonly INSTALL_PREFIX="${INSTALL_DIR:-/opt/python}"
readonly BIN_LINK_DIR="${BIN_LINK_DIR:-/usr/local/bin}"

# ==================== Arch check ====================

check_arch() {
    local arch
    arch="$(uname -m)"
    if [[ "$arch" != "x86_64" ]]; then
        error "Only x86_64 architecture is supported for binary installation. Detected: $arch"
    fi
}

# ==================== Download and install python ====================

setup_symlinks() {
    local version="$1"
    local bin_dir="$INSTALL_PREFIX/$version/bin"
    log "$(ls "$install_dir")"
    mkdir -p "$BIN_LINK_DIR"
    # Symlink python3, pip3, etc.
    ln -sf "$bin_dir/python3" "$BIN_LINK_DIR/python3"
    ln -sf "$bin_dir/pip3" "$BIN_LINK_DIR/pip3"
    ln -sf "$bin_dir/python3" "$BIN_LINK_DIR/python"
    ln -sf "$bin_dir/pip3" "$BIN_LINK_DIR/pip"
    log "Symlinks created in $BIN_LINK_DIR"

    # if [[ ":$PATH:" != *":$BIN_LINK_DIR:"* ]]; then
    #     export PATH="$BIN_LINK_DIR:$PATH"
    #     log "Added $BIN_LINK_DIR to PATH"
    # fi
}

install_with_pip() {
    export DEBIAN_FRONTEND=noninteractive
    local version="$1"
    local release_number

    apt-get update > /dev/null
    apt-get install -y jq

    release_number=$(curl -s "$LATEST_RELEASE_URL" | jq -r ".tag")

    local file_name="cpython-$version+$release_number-x86_64-unknown-linux-gnu-install_only.tar.gz"
    local url="$BINARIES_BASE_URL/$release_number/$file_name"
    local temp_dir
    temp_dir="$(mktemp -d)"

    log "Installing dependencies..."
    apt-get install -y \
       libssl-dev \
       libffi-dev \
       zlib1g-dev \
       libsqlite3-dev \
       libbz2-dev \
       liblzma-dev \
       libreadline-dev \
       > /dev/null 2>&1 || log "Some dev packages not found — may affect binary compatibility"

    log "Downloading Python ${version} from $url..."
    curl -fsSL "$url" -o "${temp_dir}/$file_name" || echo "Exit code: $?"

    log "Verifying checksum..."
    local checksums_url="$BINARIES_BASE_URL/$release_number/SHA256SUMS"
    local file_checksum=$(sha256sum "$temp_dir/$file_name" | cut -d ' ' -f 1)
    local control_checksum=$(get_checksum $file_name $checksums_url)
    if [[ "$file_checksum" = "$control_checksum" ]]; then
        log "Checksum is valid"
    else
        error "Checksum verification failed"
    fi

    local install_dir="$INSTALL_PREFIX/$version"
    log "Extracting and installing python to $install_dir..."
    tar -xzf "$temp_dir/$file_name" -C "$temp_dir"
    mkdir -p "$install_dir"

    cp -r "$temp_dir/python/." "$install_dir"
    setup_symlinks "$version"

    rm -rf "$temp_dir"
    log "Python $version installed to $install_dir"
}

install_with_uv() {
    local version="$1"
    log "Installing uv..."
    curl -LsSf "$UV_INSTALL_SCRIPT_URL" | sh
    log "uv installed successfully"

    log "Add <home>/.local/bin to PATH"
    echo "export PATH='$HOME/.local/bin:$PATH'" >> ~/.bashrc
    source ~/.bashrc

    log "Installing python $version"
    if [[ "$version" == "latest" ]]; then
        uv python install --default
    else
        uv python install "$version" --default
    fi
}


# ==================== MAIN ====================

main() {
    check_os_support
    check_arch

    log "Starting Python $PYTHON_VERSION binary installation..."
    log "Package manager: $PACKAGE_MANAGER"

    local version="$PYTHON_VERSION"

    if [[ "$version" == "latest" ]]; then
        version=$(get_latest_version "python/cpython")
    fi

    case "$PACKAGE_MANAGER" in
        pip)
            install_with_pip "$version"
            ;;
        uv)
            install_with_uv "$version"
            ;;
        *)
            error "Unsupported package manager: $PACKAGE_MANAGER. Use 'pip' or 'uv'"
            ;;
    esac

    if [[ "$version" != "latest" ]]; then
        if ! python3 --version 2>&1 | grep -q "$version"; then
            error "Python $version not found after installation. Current Python is $(python3 --version)"
        fi
    fi
    log "Python $(python3 --version) is ready"
    log "Python setup completed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
