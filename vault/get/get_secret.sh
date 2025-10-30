#!/usr/bin/env bash
set -euo pipefail

readonly SECRET_KEY="${SECRET_KEY:?SECRET_KEY is required}"
readonly SECRET_PATH="${SECRET_PATH:?SECRET_PATH is required}"
readonly VAULT_URL="${VAULT_URL:?VAULT_URL is required}"
readonly VAULT_TOKEN="${VAULT_TOKEN:?VAULT_TOKEN is required}"

if ! command -v jq >/dev/null 2>&1; then
    apt-get update > /dev/null 2>&1
    apt-get install -y jq > /dev/null 2>&1
fi

value=$(curl -s \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -X GET \
    $VAULT_URL/v1/$SECRET_PATH | \
    jq -r --arg key "$SECRET_KEY" '.data.data[$key]')

echo "$value"
