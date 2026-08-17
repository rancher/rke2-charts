#!/usr/bin/env bash
set -eu

PACKAGE="rke2-traefik"
PACKAGE_FILE="packages/${PACKAGE}/package.yaml"
NEW_VERSION="${TRAEFIK_CHART_VERSION:-}"

if [[ -z "${NEW_VERSION}" ]]; then
    echo "TRAEFIK_CHART_VERSION is not set" >&2
    exit 1
fi

CURRENT_URL=$(sed -n 's/^url: //p' "${PACKAGE_FILE}")
CURRENT_VERSION=${CURRENT_URL##*/traefik-}
CURRENT_VERSION=${CURRENT_VERSION%.tgz}
USER=$(whoami)
if [[ "${CURRENT_VERSION}" == "${NEW_VERSION}" ]]; then
    echo "Traefik chart is already at ${NEW_VERSION}, nothing to do"
    exit 0
fi

echo "Updating Traefik chart from ${CURRENT_VERSION} to ${NEW_VERSION}"
sed -i \
    -e "s|^url: .*|url: https://traefik.github.io/charts/traefik/traefik-${NEW_VERSION}.tgz|" \
    -e 's/^packageVersion: .*/packageVersion: 00/' \
    "${PACKAGE_FILE}"

GOCACHE="/home/$USER/.cache/go-build" GOPATH="/home/$USER/go" PACKAGE="${PACKAGE}" make prepare
find "packages/${PACKAGE}/charts" -name '*.orig' -delete
GOCACHE="/home/$USER/.cache/go-build" GOPATH="/home/$USER/go" PACKAGE="${PACKAGE}" make patch
GOCACHE="/home/$USER/.cache/go-build" GOPATH="/home/$USER/go" PACKAGE="${PACKAGE}" make clean