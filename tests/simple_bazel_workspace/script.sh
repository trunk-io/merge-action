#!/usr/bin/env bash

shopt -s expand_aliases

startup_options="--block_for_lock --client_debug"
_bazel() {
	bazel ${startup_options} "$@"
}

alias _java=$(_bazel info java-home)/bin/java

# _bazel
_java
