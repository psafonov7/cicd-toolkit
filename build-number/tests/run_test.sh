#!/bin/bash

act -P ubuntu-latest=node:24-trixie -W build-number/tests/workflow_test.yml
act -P ubuntu-latest=node:24-trixie -W build-number/tests/workflow_test.yml -e <(echo '{"ref":"refs/tags/v1.2.3"}')