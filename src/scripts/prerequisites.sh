#!/usr/bin/env bash

set -euo pipefail

merge_instance_branch="${TARGET_BRANCH}"
if [[ -z ${merge_instance_branch} ]]; then
	merge_instance_branch="${DEFAULT_BRANCH}"
fi

if [[ -z ${merge_instance_branch} ]]; then
	echo "Could not identify merge instance branch"
	exit 2
fi

# trunk-ignore(shellcheck/SC2153): Passed in as env variable
workspace_path="${WORKSPACE_PATH}"
if [[ -z ${workspace_path} ]]; then
	workspace_path=$(pwd)
fi

requires_default_bazel_installation="false"
if [[ ${BAZEL_PATH} == "bazel" ]]; then
	if ! command -v bazel; then
		echo "requires bazel installation"
		requires_default_bazel_installation="true"
	else
		echo "does not require bazel installation"
		# DO NOT LAND
	fi
fi

# Outputs
# trunk-ignore(shellcheck/SC2129)
echo "merge_instance_branch=${merge_instance_branch}" >>"${GITHUB_OUTPUT}"
echo "workspace_path=${workspace_path}" >>"${GITHUB_OUTPUT}"
echo "requires_default_bazel_installation=${requires_default_bazel_installation}" >>"${GITHUB_OUTPUT}"
