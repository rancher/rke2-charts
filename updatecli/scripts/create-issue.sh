#!/usr/bin/env bash

ISSUE_BODY="Failed workflow run: ${UPDATECLI_GITHUB_WORKFLOW_URL}"

GITHUB_APP="rancher-issues-manager"
GITHUB_REPOSITORY="rancher/rke2"

report-error() {
    exit_code=$?
    trap - EXIT INT

    if [[ $exit_code != 0 ]]; then
        issue=$(
            gh issue list \
                --app ${GITHUB_APP} \
                --repo ${GITHUB_REPOSITORY} \
                --state "open" \
                --search "${ISSUE_TITLE}" \
                --json number --jq ".[].number" | sort -run | head -1
        )
        if [[ -z "$issue" ]]; then
            echo "Creating issue for: '${ISSUE_TITLE}'"
            gh issue create \
                --repo ${GITHUB_REPOSITORY} \
                --title "${ISSUE_TITLE}" \
                --body "${ISSUE_BODY}"
        else
            echo "Issue ${issue} already exists for: '${ISSUE_TITLE}'"
            gh issue comment \
                ${issue} \
                --repo ${GITHUB_REPOSITORY} \
                --body "${ISSUE_BODY}"
        fi
    fi

    exit $exit_code
}

export -f report-error
