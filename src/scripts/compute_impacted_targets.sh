#!/usr/bin/env bash

set -euo pipefail

ifVerbose() {
	if [[ -n ${VERBOSE} ]]; then
		"$@"
	fi
}

logIfVerbose() {
	ifVerbose echo "$@"
}

# NOTE: We cannot assume that the checked out Git repo (e.g. via actions-checkout)
# was a shallow vs a complete clone. The `--depth` options deepens the commit history
# in both clone modes: https://git-scm.com/docs/fetch-options#Documentation/fetch-options.txt---depthltdepthgt
fetchRemoteGitHistory() {
	git fetch --quiet --depth=2147483647 origin "$@"
}

if [[ (-z ${MERGE_INSTANCE_BRANCH}) || (-z ${PR_BRANCH}) ]]; then
	echo "Missing branch"
	exit 2
fi

if [[ -z ${WORKSPACE_PATH} ]]; then
	echo "Missing workspace path"
	exit 2
fi

logIfVerbose "Fetching all remotes..."
git fetch --all --quiet
logIfVerbose "...done!"

# Install the bazel-diff JAR. Avoid cloning the repo, as there will be conflicting WORKSPACES.
curl --retry 5 -Lo bazel-diff.jar https://github.com/Tinder/bazel-diff/releases/latest/download/bazel-diff_deploy.jar

fetchRemoteGitHistory "${MERGE_INSTANCE_BRANCH}"
fetchRemoteGitHistory "${PR_BRANCH}"

merge_instance_branch_head_sha=$(git rev-parse "${MERGE_INSTANCE_BRANCH}")
logIfVerbose "Merge Instance Branch Head= ${merge_instance_branch_head_sha}"

pr_branch_head_sha=$(git rev-parse "${PR_BRANCH}")
logIfVerbose "PR Branch Head= ${pr_branch_head_sha}"

# Find the merge base of the two branches
merge_base_sha=$(git merge-base "${merge_instance_branch_head_sha}" "${pr_branch_head_sha}")
logIfVerbose "Merge Base= ${merge_base_sha}"

# Find the number of commits between the merge base and the merge instance's HEAD
merge_instance_depth=$(git rev-list "${merge_base_sha}".."${merge_instance_branch_head_sha}" | wc -l)
logIfVerbose "Merge Instance Depth= ${merge_instance_depth}"

git switch "${MERGE_INSTANCE_BRANCH}"
ifVerbose git log -n "${merge_instance_depth}" --oneline

# Find the number of commits between the merge base and the PR's HEAD
pr_depth=$(git rev-list "${merge_base_sha}".."${pr_branch_head_sha}" | wc -l)
logIfVerbose "PR Depth= ${pr_depth}"

git switch "${PR_BRANCH}"
ifVerbose git log -n "${pr_depth}" --oneline

# Output Files
merge_instance_branch_out=./${merge_instance_branch_head_sha}
merge_instance_with_pr_branch_out=./${pr_branch_head_sha}_${merge_instance_branch_head_sha}
impacted_targets_out=./impacted_targets_${pr_branch_head_sha}

# Generate Hashes for the Merge Instance Branch
git switch "${MERGE_INSTANCE_BRANCH}"
java -jar bazel-diff.jar generate-hashes --workspacePath="${WORKSPACE_PATH}" "${merge_instance_branch_out}"

# Generate Hashes for the Merge Instance Branch + PR Branch
git -c "user.name=Trunk Actions" -c "user.email=actions@trunk.io" merge --squash "${PR_BRANCH}"
java -jar bazel-diff.jar generate-hashes --workspacePath="${WORKSPACE_PATH}" "${merge_instance_with_pr_branch_out}"

# Compute impacted targets
java -jar bazel-diff.jar get-impacted-targets --startingHashes="${merge_instance_branch_out}" --finalHashes="${merge_instance_with_pr_branch_out}"
num_impacted_targets=$(wc -l <"${impacted_targets_out}")
echo "Computed ${num_impacted_targets} targets for sha ${pr_branch_head_sha}"

# Outputs
echo "git_commit=${pr_branch_head_sha}" >>"${GITHUB_OUTPUT}"
echo "impacted_targets_out=${impacted_targets_out}" >>"${GITHUB_OUTPUT}"
