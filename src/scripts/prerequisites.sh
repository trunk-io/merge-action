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

arch=""
if (uname -a | grep arm64); then
	arch="arm64"
elif (uname -a | grep x86_64); then
	arch="x86_64"
else
	echo "Could not determine architecture"
	exit 2
fi

# Outputs
# trunk-ignore(shellcheck/SC2129)
echo "merge_instance_branch=${merge_instance_branch}" >>"${GITHUB_OUTPUT}"
echo "workspace_path=${workspace_path}" >>"${GITHUB_OUTPUT}"
echo "arch=${arch}" >>"${GITHUB_OUTPUT}"
