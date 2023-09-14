#!/usr/bin/env bash

set -euo pipefail

# API Token
if [[ -z ${API_TOKEN+x} ]]; then
	echo "Missing API Token"
	exit 2
fi

# POST Body Parameters
if [[ (-z ${REPOSITORY}) || (-z ${TARGET_BRANCH}) ]]; then
	echo "Missing Repo params"
	exit 2
fi

REPO_OWNER=$(echo "${REPOSITORY}" | cut -d "/" -f 1)
REPO_NAME=$(echo "${REPOSITORY}" | cut -d "/" -f 2)

if [[ (-z ${PR_NUMBER}) || (-z ${PR_SHA}) ]]; then
	echo "Missing PR params"
	exit 2
fi

# API URL
if [[ -z ${API_URL+x} ]]; then
	API_URL="https://api.trunk.io:443/v1/setImpactedTargets"
fi

REPO_BODY=$(
	jq --null-input \
		--arg host "github.com" \
		--arg owner "${REPO_OWNER}" \
		--arg name "${REPO_NAME}" \
		'{ "host": $host, "owner": $owner, "name": $name }'
)

PR_BODY=$(
	jq --null-input \
		--arg number "${PR_NUMBER}" \
		--arg sha "${PR_SHA}" \
		'{ "number": $number, "sha": $sha }'
)

num_impacted_targets=""
POST_BODY="./post_body_tmp"
if [[ ${IMPACTS_ALL_DETECTED} == 'true' ]]; then
	jq --null-input \
		--argjson repo "${REPO_BODY}" \
		--argjson pr "${PR_BODY}" \
		--arg impactedTargets "ALL" \
		--arg targetBranch "${TARGET_BRANCH}" \
		'{ "repo": $repo, "pr": $pr, "targetBranch": $targetBranch, "impactedTargets": $impactedTargets }' \
		>"${POST_BODY}"

	num_impacted_targets="'ALL'"
else
	# Reformat the impacted targets into JSON array and pipe into a new file.
	IMPACTED_TARGETS_JSON_TMP="./impacted_targets_json_tmp"
	touch "${IMPACTED_TARGETS_JSON_TMP}"
	mapfile -t impacted_targets_array <"${IMPACTED_TARGETS_FILE}"
	IMPACTED_TARGETS=$(printf '%s\n' "${impacted_targets_array[@]}" | jq -R . | jq -s .)
	if [[ -z ${IMPACTED_TARGETS} ]]; then
		echo "[]" >"${IMPACTED_TARGETS_JSON_TMP}"
	else
		echo "${IMPACTED_TARGETS}" >"${IMPACTED_TARGETS_JSON_TMP}"
	fi

	jq --null-input \
		--argjson repo "${REPO_BODY}" \
		--argjson pr "${PR_BODY}" \
		--slurpfile impactedTargets "${IMPACTED_TARGETS_JSON_TMP}" \
		--arg targetBranch "${TARGET_BRANCH}" \
		'{ "repo": $repo, "pr": $pr, "targetBranch": $targetBranch, "impactedTargets": $impactedTargets | .[0] | map(select(length > 0)) }' \
		>"${POST_BODY}"

	num_impacted_targets=$(wc -l <"${IMPACTED_TARGETS_FILE}")
fi

HTTP_STATUS_CODE=$(
	curl -s -o /dev/null -w '%{http_code}' -X POST \
		-H "Content-Type: application/json" -H "x-api-token:${API_TOKEN}" \
		-d "@${POST_BODY}" \
		"${API_URL}"
)

EXIT_CODE=0
COMMENT_TEXT=""
if [[ ${HTTP_STATUS_CODE} == 200 ]]; then
	COMMENT_TEXT="✨ Uploaded ${num_impacted_targets} impacted targets for ${PR_NUMBER} @ ${PR_SHA}"
else
	EXIT_CODE=1
	COMMENT_TEXT="❌ Unable to upload impacted targets. Encountered ${HTTP_STATUS_CODE} @ ${PR_SHA}. Please contact us at slack.trunk.io."

	# Dependabot doesn't have access to GitHub action Secrets.
	# On authn failure, prompt the user to update their token.
	# https://docs.github.com/en/code-security/dependabot/working-with-dependabot/automating-dependabot-with-github-actions#accessing-secrets
	if [[ ${HTTP_STATUS_CODE} -eq 401 ]]; then
		if [[ ${ACTOR} == 'dependabot[bot]' ]]; then
			COMMENT_TEXT="❌ Unable to upload impacted targets. Did you update your Dependabot secrets with your repo's token? See https://docs.github.com/en/code-security/dependabot/working-with-dependabot/automating-dependabot-with-github-actions#accessing-secrets for more details."
		elif [[ ${ACTOR} == *"[bot]" ]]; then
			COMMENT_TEXT="❌ Unable to upload impacted targets. Please verify that this bot has access to your repo's token."
		fi
	fi
fi

echo "${COMMENT_TEXT}"
exit "${EXIT_CODE}"
