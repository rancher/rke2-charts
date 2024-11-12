#!/usr/bin/env bash

TARGET_REPOSITORY="rancher/rke2"
BODY="Url of the failed run: ${UPDATECLI_GITHUB_WORKFLOW_URL}"

report-error() {
    exit_code=$?
    trap - EXIT INT

    if [[ $exit_code != 0 ]]; then
        #check if issue already exists
        issues=$(gh issue list -R ${TARGET_REPOSITORY} \
                    --search "is:open ${ISSUE_TITLE}" \
                    --app rke2-issues-updatecli --json number --jq ".[].number" | wc -l)

        if [[ $issues = 0 ]]; then
            echo "Creating issue for: $title"
            gh issue create -R ${TARGET_REPOSITORY} \
                --title "${ISSUE_TITLE}" \
                --body "${BODY}"
        else
            echo "Issue already exists for: ${ISSUE_TITLE}"
        fi
    fi

    exit $exit_code
}

export -f report-error 
