#!/bin/bash
# Bump the ingress-nginx prime image tag in the rke2-ingress-nginx chart.
# Updates both primeTag occurrences in the values.yaml patch (controller and
# admission-webhook kube-webhook-certgen) and increments the chart packageVersion.
set -eu

source "$(dirname "$0")/create-issue.sh"

ISSUE_TITLE="Updatecli failed for ingress-nginx ${INGRESS_NGINX_PRIME_TAG}"
trap report-error EXIT INT

PATCH_FILE="packages/rke2-ingress-nginx/generated-changes/patch/values.yaml.patch"
PACKAGE_FILE="packages/rke2-ingress-nginx/package.yaml"
NEW_TAG="${INGRESS_NGINX_PRIME_TAG:-}"
UPDATED=false

if [ -z "${NEW_TAG}" ]; then
    echo "INGRESS_NGINX_PRIME_TAG is not set" >&2
    exit 1
fi

current=$(sed -nr 's/^\+ *primeTag: "?([^"]+)"?.*/\1/p' "${PATCH_FILE}" | head -1)

if [ "${current}" != "${NEW_TAG}" ]; then
    echo "Updating ingress-nginx prime tag from ${current} to ${NEW_TAG}"
    sed -i "s|${current}|${NEW_TAG}|g" "${PATCH_FILE}"
    UPDATED=true
fi

if [ "${UPDATED}" = true ]; then
    package_version=$(yq '.packageVersion' "${PACKAGE_FILE}")
    new_version=$(printf "%02d" $((10#${package_version} + 1)))
    echo "Bumping packageVersion from ${package_version} to ${new_version}"
    sed -i "s|packageVersion:.*|packageVersion: ${new_version}|g" "${PACKAGE_FILE}"
else
    echo "ingress-nginx prime tag already at ${NEW_TAG}, nothing to do"
fi
