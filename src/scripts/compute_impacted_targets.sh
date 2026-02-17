#!/usr/bin/env bash

set -euo pipefail
shopt -s expand_aliases

if [[ -z ${MERGE_INSTANCE_BRANCH} ]]; then
	echo "Missing branch"
	exit 2
fi

if [[ (-z ${MERGE_INSTANCE_BRANCH_HEAD_SHA}) || (-z ${PR_BRANCH_HEAD_SHA}) ]]; then
	echo "Missing sha"
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

_bazel() {
	# trunk-ignore(shellcheck)
	${BAZEL_PATH} ${bazel_startup_options} "$@"
}

# trunk-ignore(shellcheck)
alias _java=$(_bazel info java-home)/bin/java

bazelDiff() {
	if [[ -n ${VERBOSE} ]]; then
		_java -jar bazel-diff.jar "$@" --verbose
	else
		_java -jar bazel-diff.jar "$@"
	fi
}

## Verbose logging for the Merge Instance and PR branch.
if [[ -n ${VERBOSE} ]]; then
	# Find the merge base of the two branches
	merge_base_sha=$(git merge-base "${MERGE_INSTANCE_BRANCH_HEAD_SHA}" "${PR_BRANCH_HEAD_SHA}")
	echo "Merge Base= ${merge_base_sha}"

	# Find the number of commits between the merge base and the merge instance's HEAD
	merge_instance_depth=$(git rev-list "${merge_base_sha}".."${MERGE_INSTANCE_BRANCH_HEAD_SHA}" | wc -l)
	echo "Merge Instance Depth= ${merge_instance_depth}"

	git checkout "${MERGE_INSTANCE_BRANCH}"
	git clean -dfx -f --exclude=".trunk" .
	git submodule update --recursive
	git log -n "${merge_instance_depth}" --oneline

	# Find the number of commits between the merge base and the PR's HEAD
	pr_depth=$(git rev-list "${merge_base_sha}".."${PR_BRANCH_HEAD_SHA}" | wc -l)
	echo "PR Depth= ${pr_depth}"

	git checkout "${PR_BRANCH_HEAD_SHA}"
	git clean -dfx -f --exclude=".trunk" .
	git submodule update --recursive
	git log -n "${pr_depth}" --oneline
fi

# Install the bazel-diff JAR. Avoid cloning the repo, as there will be conflicting WORKSPACES.
curl --retry 5 -Lo bazel-diff.jar https://github.com/Tinder/bazel-diff/releases/latest/download/bazel-diff_deploy.jar --fail || \
	curl --retry 5 -Lo bazel-diff.jar https://github.com/Tinder/bazel-diff/releases/latest/download/bazel-diff_deploy-7.jar
_java -jar bazel-diff.jar -V
_bazel version # Does not require running with startup options.

# Output Files
merge_instance_branch_out=./${MERGE_INSTANCE_BRANCH_HEAD_SHA}
merge_instance_with_pr_branch_out=./${PR_BRANCH_HEAD_SHA}_${MERGE_INSTANCE_BRANCH_HEAD_SHA}
impacted_targets_out=./impacted_targets_${PR_BRANCH_HEAD_SHA}

# Generate Hashes for the Merge Instance Branch
git switch "${MERGE_INSTANCE_BRANCH}"
git clean -dfx -f --exclude=".trunk" --exclude="bazel-diff.jar" .
git submodule update --recursive
bazelDiff generate-hashes --bazelPath="${BAZEL_PATH}" --workspacePath="${WORKSPACE_PATH}" "-so=${bazel_startup_options}" "${merge_instance_branch_out}"

# Generate Hashes for the Merge Instance Branch + PR Branch
git -c "user.name=Trunk Actions" -c "user.email=actions@trunk.io" merge --squash "${PR_BRANCH_HEAD_SHA}"
git clean -dfx -f --exclude=".trunk" --exclude="${MERGE_INSTANCE_BRANCH_HEAD_SHA}" --exclude="bazel-diff.jar" .
git submodule update --recursive
bazelDiff generate-hashes --bazelPath="${BAZEL_PATH}" --workspacePath="${WORKSPACE_PATH}" "-so=${bazel_startup_options}" "${merge_instance_with_pr_branch_out}"

# Compute impacted targets
bazelDiff get-impacted-targets --startingHashes="${merge_instance_branch_out}" --finalHashes="${merge_instance_with_pr_branch_out}" --output="${impacted_targets_out}"

num_impacted_targets=$(wc -l <"${impacted_targets_out}")
echo "Computed ${num_impacted_targets} targets for sha ${PR_BRANCH_HEAD_SHA}"

# Outputs
echo "impacted_targets_out=${impacted_targets_out}" >>"${GITHUB_OUTPUT}"
