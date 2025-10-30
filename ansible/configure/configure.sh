#!/usr/bin/env bash
set -euo pipefail

readonly PRIVATE_KEY="${PRIVATE_KEY:?PRIVATE_KEY is required}"
readonly PLAYBOOKS_PATH="${PLAYBOOKS_DIR:-ansible}"

mkdir ~/.ssh
touch ~/.ssh/id_ed25519
echo "$PRIVATE_KEY" | base64 -d > ~/.ssh/id_ed25519
chmod "0400" ~/.ssh/id_ed25519

eval $(ssh-agent -s)
ssh-add ~/.ssh/id_ed25519

ansible-galaxy install -r $PLAYBOOKS_PATH/requirements.yaml
