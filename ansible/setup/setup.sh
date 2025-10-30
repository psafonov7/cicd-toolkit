#!/usr/bin/env bash
set -euo pipefail

readonly VERSION="${VERSION:-latest}"
readonly INSTALL_TYPE="${INSTALL_TYPE:-pip}" # pip/apt

echo "Installing Ansible..."

if [[ $INSTALL_TYPE == "apt" ]]; then
    apt update
    apt install -y ansible
fi

if [[ $INSTALL_TYPE == "pip" ]]; then
    python3 -m pip install --user --upgrade pip ansible
    export PATH="$PATH:$(python3 -m site --user-base)/bin"
    echo "$(python3 -m site --user-base)/bin" >> "$GITHUB_PATH"
fi

ansible --version
