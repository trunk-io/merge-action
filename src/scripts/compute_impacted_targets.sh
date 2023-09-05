#!/usr/bin/env bash

set -euo pipefail
shopt -s expand_aliases

if [[ (-z ${MERGE_INSTANCE_BRANCH}) || (-z ${PR_BRANCH}) ]]; then
	echo "Missing branch"
	exit 2
fi

if [[ -z ${WORKSPACE_PATH} ]]; then
	echo "Missing workspace path"
	exit 2
fi

ifVerbose() {
	if [[ -n ${VERBOSE} ]]; then
		"$@"
	fi
}

logIfVerbose() {
	# trunk-ignore(shellcheck/SC2312): Always query date with each echo statement.
	ifVerbose echo "$(date -u)" "$@"
}

# If specified, parse the Bazel startup options when generating hashes.
bazel_startup_options=""
if [[ -n ${BAZEL_STARTUP_OPTIONS} ]]; then
	bazel_startup_options=$(echo "${BAZEL_STARTUP_OPTIONS}" | tr ',' ' ')
fi
logIfVerbose "Bazel startup options" "${bazel_startup_options}"

# TODO: Grab latest.
# TODO: Grab version based off arch.
curl --retry 5 -Lo bazel-differ https://github.com/ewhauser/bazel-differ/releases/download/v0.0.7/bazel-differ-linux-arm64
chmod +x ./bazel-differ

bazelDiffer() {
	if [[ -n ${VERBOSE} ]]; then
		bazel-differ "$@" --verbose
	else
		bazel-differ "$@"
	fi
}

# NOTE: We cannot assume that the checked out Git repo (e.g. via actions-checkout)
# was a shallow vs a complete clone. The `--depth` options deepens the commit history
# in both clone modes: https://git-scm.com/docs/fetch-options#Documentation/fetch-options.txt---depthltdepthgt
fetchRemoteGitHistory() {
	logIfVerbose "Fetching" "$@" "..."
	git fetch --quiet --depth=2147483647 origin "$@"
	logIfVerbose "...done!"
}

fetchRemoteGitHistory "${MERGE_INSTANCE_BRANCH}"
fetchRemoteGitHistory "${PR_BRANCH}"

git switch "${MERGE_INSTANCE_BRANCH}"
merge_instance_branch_head_sha=$(git rev-parse "${MERGE_INSTANCE_BRANCH}")
ifVerbose echo "Merge Instance Branch Head= ${merge_instance_branch_head_sha}"

git switch "${PR_BRANCH}"
pr_branch_head_sha=$(git rev-parse "${PR_BRANCH}")
ifVerbose echo "PR Branch Head= ${pr_branch_head_sha}"

## Verbose logging for the Merge Instance and PR branch.
if [[ -n ${VERBOSE} ]]; then
	# Find the merge base of the two branches
	merge_base_sha=$(git merge-base "${merge_instance_branch_head_sha}" "${pr_branch_head_sha}")
	echo "Merge Base= ${merge_base_sha}"

	# Find the number of commits between the merge base and the merge instance's HEAD
	merge_instance_depth=$(git rev-list "${merge_base_sha}".."${merge_instance_branch_head_sha}" | wc -l)
	echo "Merge Instance Depth= ${merge_instance_depth}"

	git switch "${MERGE_INSTANCE_BRANCH}"
	git log -n "${merge_instance_depth}" --oneline

	# Find the number of commits between the merge base and the PR's HEAD
	pr_depth=$(git rev-list "${merge_base_sha}".."${pr_branch_head_sha}" | wc -l)
	echo "PR Depth= ${pr_depth}"

	git switch "${PR_BRANCH}"
	git log -n "${pr_depth}" --oneline
fi

# Output Files
merge_instance_branch_out=./${merge_instance_branch_head_sha}
merge_instance_with_pr_branch_out=./${pr_branch_head_sha}_${merge_instance_branch_head_sha}
impacted_targets_out=./impacted_targets_${pr_branch_head_sha}

# Generate Hashes for the Merge Instance Branch
git switch "${MERGE_INSTANCE_BRANCH}"
bazelDiffer generate-hashes --workspacePath="${WORKSPACE_PATH}" "--bazelStartupOptions=${bazel_startup_options}" --finalHashes="${merge_instance_branch_out}"

# Generate Hashes for the Merge Instance Branch + PR Branch
git -c "user.name=Trunk Actions" -c "user.email=actions@trunk.io" merge --squash "${PR_BRANCH}"
bazelDiffer generate-hashes --workspacePath="${WORKSPACE_PATH}" "--bazelStartupOptions=${bazel_startup_options}" --finalHashes="${merge_instance_with_pr_branch_out}"

# Compute impacted targets
bazelDiffer diff --startingHashes="${merge_instance_branch_out}" --finalHashes="${merge_instance_with_pr_branch_out}" --output="${impacted_targets_out}"

num_impacted_targets=$(wc -l <"${impacted_targets_out}")
echo "Computed ${num_impacted_targets} targets for sha ${pr_branch_head_sha}"

# Outputs
echo "git_commit=${pr_branch_head_sha}" >>"${GITHUB_OUTPUT}"
echo "impacted_targets_out=${impacted_targets_out}" >>"${GITHUB_OUTPUT}"
