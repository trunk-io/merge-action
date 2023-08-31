#!/usr/bin/env bash

startup_options="--block_for_lock --client_debug"
_bazel() {
	bazel ${startup_options} "$@"
}

_bazel
