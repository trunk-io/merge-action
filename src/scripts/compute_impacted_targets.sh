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
curl -Lo bazel-diff.jar https://github.com/Tinder/bazel-diff/releases/latest/download/bazel-diff_deploy.jar

git switch "${MERGE_INSTANCE_BRANCH}"
git fetch --unshallow --quiet
merge_instance_branch_head_sha=$(git rev-parse "${MERGE_INSTANCE_BRANCH}")
logIfVerbose "Merge Instance Branch Head= ${merge_instance_branch_head_sha}"

git switch "${PR_BRANCH}"
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
pr_branch_out=./${pr_branch_head_sha}
merge_instance_with_pr_branch_out=./${pr_branch_head_sha}_${merge_instance_branch_head_sha}
impacted_targets_out=./impacted_targets_${pr_branch_head_sha}

# Generate Hashes for the PR Branch
git switch "${PR_BRANCH}"
java -jar bazel-diff.jar generate-hashes --workspacePath="${WORKSPACE_PATH}" "${pr_branch_out}"

# Generate Hashes for the Merge Instance Branch + PR Branch
git switch "${MERGE_INSTANCE_BRANCH}"
git -c "user.name=Trunk Actions" -c "user.email=actions@trunk.io" merge --squash "${PR_BRANCH}"
java -jar bazel-diff.jar generate-hashes --workspacePath="${WORKSPACE_PATH}" "${merge_instance_with_pr_branch_out}"

# Compute impacted targets
java -jar bazel-diff.jar get-impacted-targets --startingHashes="${pr_branch_out}" --finalHashes="${merge_instance_with_pr_branch_out}" --output="${impacted_targets_out}"

num_impacted_targets=$(wc -l <"${impacted_targets_out}")
echo "Computed ${num_impacted_targets} targets for sha ${pr_branch_head_sha}"

# Outputs
echo "git_commit=${pr_branch_head_sha}" >>"${GITHUB_OUTPUT}"
echo "impacted_targets_out=${impacted_targets_out}" >>"${GITHUB_OUTPUT}"
