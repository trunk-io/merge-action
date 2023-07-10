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

# Outputs
if [[ -v GITHUB_OUTPUT && -f ${GITHUB_OUTPUT} ]]; then
  echo "merge_instance_branch=${merge_instance_branch}" >>"${GITHUB_OUTPUT}"
else
  echo "::set-output name=merge_instance_branch::${merge_instance_branch}"
fi
