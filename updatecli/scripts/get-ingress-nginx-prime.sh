#!/bin/bash
# Emit the highest ingress-nginx "-primeN" tag available for the nginx base
# version currently pinned in the rke2-ingress-nginx chart values patch.
#
# The base version (e.g. v1.15.1) is derived from the patch file itself, so this
# only ever advances the prime (CVE rebuild) suffix and never silently jumps the
# nginx minor/patch line - that remains a deliberate, human change.
set -eu

PATCH_FILE="packages/rke2-ingress-nginx/generated-changes/patch/values.yaml.patch"
INGRESS_NGINX_REPO="https://github.com/rancher/ingress-nginx.git"

current=$(sed -nr 's/^\+ *primeTag: "?([^"]+)"?.*/\1/p' "${PATCH_FILE}" | head -1)
if [ -z "${current}" ]; then
    echo "failed to read primeTag from ${PATCH_FILE}" >&2
    exit 1
fi

base=${current%-prime*}

latest=$(git ls-remote --tags --refs "${INGRESS_NGINX_REPO}" "${base}-prime*" \
    | sed 's#.*refs/tags/##' \
    | awk -F'-prime' '{print $2, $0}' \
    | sort -n \
    | tail -1 \
    | awk '{print $2}')

# If nothing is found, fall back to the current tag so updatecli is a no-op.
if [ -z "${latest}" ]; then
    echo "${current}"
else
    echo "${latest}"
fi
