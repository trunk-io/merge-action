#!/usr/bin/env bash

set -euo pipefail

# NOTE: We cannot assume that the checked out Git repo (e.g. via actions-checkout)
# was a shallow vs a complete clone. The `--depth` options deepens the commit history
# in both clone modes: https://git-scm.com/docs/fetch-options#Documentation/fetch-options.txt---depthltdepthgt
fetchRemoteGitHistory() {
	git fetch --quiet --depth=2147483647 origin "$@"
}

# trunk-ignore(shellcheck)
pr_branch="${PR_BRANCH}"
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
		requires_default_bazel_installation="true"
	fi
fi

changes_count=0
impacts_all_detected="false"
if [[ -n ${IMPACTS_FILTERS_CHANGES+x} ]]; then
	changes_count=$(echo "${IMPACTS_FILTERS_CHANGES}" | jq length)
	if [[ ${changes_count} -gt 0 ]]; then
		impacts_all_detected="true"
		requires_default_bazel_installation="false"
	fi
fi

fetchRemoteGitHistory "${merge_instance_branch}"
fetchRemoteGitHistory "${pr_branch}"

git switch "${merge_instance_branch}"
merge_instance_branch_head_sha=$(git rev-parse "${merge_instance_branch}")

git switch "${pr_branch}"
pr_branch_head_sha=$(git rev-parse "${pr_branch}")

echo "Identified changes: " "${impacts_all_detected}"

# Outputs
# trunk-ignore(shellcheck/SC2129)
echo "merge_instance_branch=${merge_instance_branch}" >>"${GITHUB_OUTPUT}"
echo "merge_instance_branch_head_sha=${merge_instance_branch_head_sha}" >>"${GITHUB_OUTPUT}"
echo "pr_branch=${pr_branch}" >>"${GITHUB_OUTPUT}"
echo "pr_branch_head_sha=${pr_branch_head_sha}" >>"${GITHUB_OUTPUT}"
echo "impacts_all_detected=${impacts_all_detected}" >>"${GITHUB_OUTPUT}"
echo "workspace_path=${workspace_path}" >>"${GITHUB_OUTPUT}"
echo "requires_default_bazel_installation=${requires_default_bazel_installation}" >>"${GITHUB_OUTPUT}"
