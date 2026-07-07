#!/usr/bin/env bash

act -P ubuntu-latest=golang:1.26 -W go/tests/workflow_test.yml
