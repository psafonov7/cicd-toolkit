#!/usr/bin/env bash

act -P ubuntu-latest=node:24-trixie -W sha-short/tests/workflow_test.yml
