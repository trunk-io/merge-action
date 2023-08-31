#!/usr/bin/env bash

shopt -s expand_aliases

startup_options="--block_for_lock --client_debug"
alias _bazel=bazel ${bazel_startup_options}

_bazel
