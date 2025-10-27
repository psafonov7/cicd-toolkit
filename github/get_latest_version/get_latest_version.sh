#!/usr/bin/env bash

set -euo pipefail

source shared/get_latest_version.sh

readonly REPO="${REPO:?Environment variable REPO is required}"

version=$(get_latest_version "$REPO")
echo "$version"
