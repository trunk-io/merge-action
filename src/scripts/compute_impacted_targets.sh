#!/usr/bin/env bash

set -euo pipefail

if [[ -z ${MERGE_INSTANCE_BRANCH} ]]; then
	echo "Missing branch"
	exit 2
fi

if [[ -n ${PR_BRANCH-} ]]; then
	echo "PR_BRANCH is deprecated and ignored; only PR_BRANCH_HEAD_SHA is used." >&2
fi

if [[ (-z ${MERGE_INSTANCE_BRANCH_HEAD_SHA}) || (-z ${PR_BRANCH_HEAD_SHA}) ]]; then
	echo "Missing sha"
	exit 2
fi

if [[ -z ${WORKSPACE_PATH} ]]; then
	echo "Missing workspace path"
	exit 2
fi
WORKSPACE_PATH=$(cd "${WORKSPACE_PATH}" && pwd)

if [[ -z ${BAZEL_PATH-} ]]; then
	BAZEL_PATH=bazel
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
	# Run from workspace so Bazel finds MODULE.bazel / .bazelversion.
	# trunk-ignore(shellcheck)
	(cd "${WORKSPACE_PATH}" && ${BAZEL_PATH} ${bazel_startup_options} "$@")
}

# Use Bazel's JDK for the JAR when available; otherwise assume java is on PATH.
# trunk-ignore(shellcheck/SC2310): Intentional — we want _bazel failure to be non-fatal here.
_java_home=$(_bazel info java-home 2>/dev/null) || true
if [[ -n ${_java_home} && -x "${_java_home}/bin/java" ]]; then
	_java="${_java_home}/bin/java"
else
	_java=java
fi

bazelDiff() {
	if [[ -n ${VERBOSE} ]]; then
		"${_java}" -jar bazel-diff.jar "$@" --verbose
	else
		"${_java}" -jar bazel-diff.jar "$@"
	fi
}

# Suppress detached-HEAD advice from git checkout.
git -c advice.detachedHead=false checkout "${MERGE_INSTANCE_BRANCH_HEAD_SHA}" --quiet 2>/dev/null || true

## Verbose logging for the Merge Instance and PR branch.
if [[ -n ${VERBOSE} ]]; then
	# Find the merge base of the two branches
	merge_base_sha=$(git merge-base "${MERGE_INSTANCE_BRANCH_HEAD_SHA}" "${PR_BRANCH_HEAD_SHA}")
	echo "Merge Base= ${merge_base_sha}"

	merge_instance_depth=$(git rev-list "${merge_base_sha}".."${MERGE_INSTANCE_BRANCH_HEAD_SHA}" | wc -l)
	echo "Merge Instance Depth= ${merge_instance_depth}"

	git -c advice.detachedHead=false checkout "${MERGE_INSTANCE_BRANCH}" --quiet
	git clean -dfx -f --exclude=".trunk" . >/dev/null
	git submodule update --recursive --quiet
	git log -n "${merge_instance_depth}" --oneline

	pr_depth=$(git rev-list "${merge_base_sha}".."${PR_BRANCH_HEAD_SHA}" | wc -l)
	echo "PR Depth= ${pr_depth}"

	git -c advice.detachedHead=false checkout "${PR_BRANCH_HEAD_SHA}" --quiet
	git clean -dfx -f --exclude=".trunk" . >/dev/null
	git submodule update --recursive --quiet
	git log -n "${pr_depth}" --oneline
fi

# Install the bazel-diff JAR. Avoid cloning the repo, as there will be conflicting WORKSPACES.
curl --retry 5 -Lo bazel-diff.jar https://github.com/Tinder/bazel-diff/releases/latest/download/bazel-diff_deploy.jar
"${_java}" -jar bazel-diff.jar -V
_bazel version # Does not require running with startup options.

# Output Files
merge_instance_branch_out=./${MERGE_INSTANCE_BRANCH_HEAD_SHA}
merge_instance_with_pr_branch_out=./${PR_BRANCH_HEAD_SHA}_${MERGE_INSTANCE_BRANCH_HEAD_SHA}
impacted_targets_out=./impacted_targets_${PR_BRANCH_HEAD_SHA}

# Generate Hashes for the Merge Instance Branch (merge branch at merge SHA).
# Use the exact SHA so we compare the requested merge state, not the branch ref.
git -c advice.detachedHead=false checkout "${MERGE_INSTANCE_BRANCH_HEAD_SHA}" --quiet
git clean -dfx -f --exclude=".trunk" --exclude="bazel-diff.jar" . >/dev/null
git submodule update --recursive --quiet
if [[ -d ${WORKSPACE_PATH} ]]; then
	bazelDiff generate-hashes --bazelPath="${BAZEL_PATH}" --workspacePath="${WORKSPACE_PATH}" "-so=${bazel_startup_options}" "${merge_instance_branch_out}"
else
	echo "Workspace ${WORKSPACE_PATH} does not exist at merge instance SHA (${MERGE_INSTANCE_BRANCH_HEAD_SHA}); using empty hashes."
	echo '{}' >"${merge_instance_branch_out}"
fi

# Generate Hashes for the Merge Instance Branch + PR Branch (PR branch at PR SHA).
git -c "user.name=Trunk Actions" -c "user.email=actions@trunk.io" merge --squash "${PR_BRANCH_HEAD_SHA}"
git clean -dfx -f --exclude=".trunk" --exclude="${MERGE_INSTANCE_BRANCH_HEAD_SHA}" --exclude="bazel-diff.jar" . >/dev/null
git submodule update --recursive --quiet
if [[ -d ${WORKSPACE_PATH} ]]; then
	bazelDiff generate-hashes --bazelPath="${BAZEL_PATH}" --workspacePath="${WORKSPACE_PATH}" "-so=${bazel_startup_options}" "${merge_instance_with_pr_branch_out}"
else
	echo "Workspace ${WORKSPACE_PATH} does not exist at PR SHA (${PR_BRANCH_HEAD_SHA}); using empty hashes."
	echo '{}' >"${merge_instance_with_pr_branch_out}"
fi

# If workspace is missing on BOTH sides, there is nothing to diff.
# Hash files containing only "{}" mean the workspace was missing at that commit.
merge_empty=$(cat "${merge_instance_branch_out}")
pr_empty=$(cat "${merge_instance_with_pr_branch_out}")
if [[ ${merge_empty} == "{}" && ${pr_empty} == "{}" ]]; then
	echo "ERROR: Bazel workspace '${WORKSPACE_PATH}' was not found at either the merge instance SHA (${MERGE_INSTANCE_BRANCH_HEAD_SHA}) or the PR SHA (${PR_BRANCH_HEAD_SHA})."
	echo "Ensure the workspace path is correct and exists on both the target branch and the PR branch."
	exit 2
fi

# Compute impacted targets
bazelDiff get-impacted-targets --startingHashes="${merge_instance_branch_out}" --finalHashes="${merge_instance_with_pr_branch_out}" --output="${impacted_targets_out}"

num_impacted_targets=$(wc -l <"${impacted_targets_out}")
echo "Computed ${num_impacted_targets} targets for sha ${PR_BRANCH_HEAD_SHA}"

# Outputs
echo "impacted_targets_out=${impacted_targets_out}" >>"${GITHUB_OUTPUT}"
