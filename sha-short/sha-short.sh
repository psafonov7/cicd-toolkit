#!/usr/bin/env bash
set -euo pipefail

SHA_FULL_LENGTH=40

SHA="${SHA:?}"
LENGTH="${LENGTH:-7}"

if [[ ${#SHA} -ne $SHA_FULL_LENGTH ]]; then
    echo "SHA length is invalid"
    exit 1
fi

echo "${SHA::LENGTH}"
