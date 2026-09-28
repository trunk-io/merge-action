#!/usr/bin/env bash
# Uploads impacted targets with the trunk CLI, logged in by trunk-io/login (`auth: github-actions`):
# the run's own GitHub credential instead of a Trunk API token.

set -euo pipefail

: "${TARGET_BRANCH:?TARGET_BRANCH is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${PR_SHA:?PR_SHA is required}"
: "${IMPACTS_ALL_DETECTED:?IMPACTS_ALL_DETECTED is required}"

args=(mergequeue upload-impacted-targets --target-branch "${TARGET_BRANCH}" --pr "${PR_NUMBER}" --sha "${PR_SHA}")

if [[ ${IMPACTS_ALL_DETECTED} == "true" ]]; then
	args+=(--all)
else
	# A missing file is a failed computation, never "impacts nothing": that answer satisfies the
	# queue's readiness gate.
	if [[ -z ${IMPACTED_TARGETS_FILE-} || ! -f ${IMPACTED_TARGETS_FILE} ]]; then
		echo "::error::No impacted targets file was computed (IMPACTED_TARGETS_FILE='${IMPACTED_TARGETS_FILE-}')"
		exit 1
	fi
	if grep -q '[^[:space:]]' "${IMPACTED_TARGETS_FILE}"; then
		args+=(--targets-file "${IMPACTED_TARGETS_FILE}")
	else
		# The computation ran and found nothing, which the v1 upload sent as an empty list.
		args+=(--none)
	fi
fi

exec trunk "${args[@]}"
