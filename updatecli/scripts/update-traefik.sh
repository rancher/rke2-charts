#!/usr/bin/env bash
set -eu

CHART_VERSION="${TRAEFIK_CHART_VERSION:-}"
IMAGE_VERSION="${TRAEFIK_IMAGE_VERSION:-}"

if [[ -z "${CHART_VERSION}" && -z "${IMAGE_VERSION}" ]]; then
    echo "Neither TRAEFIK_CHART_VERSION nor TRAEFIK_IMAGE_VERSION is set" >&2
    exit 1
fi

# Bump the Traefik image tag in every traefik package.
if [[ -n "${IMAGE_VERSION}" ]]; then
    for package in rke2-traefik rke2-traefik-1.34-1.36; do
        patch_file="packages/${package}/generated-changes/patch/values.yaml.patch"
        current_image_version=$(sed -nr 's/^\+  tag: (v[0-9]+\.[0-9]+\.[0-9]+-build[0-9]+).*/\1/p' "${patch_file}")
        if [[ -z "${current_image_version}" ]]; then
            echo "Could not determine current Traefik image tag in ${patch_file}" >&2
            continue
        fi
        if [[ "${current_image_version}" != "${IMAGE_VERSION}" ]]; then
            echo "Updating Traefik image from ${current_image_version} to ${IMAGE_VERSION} in ${package}"
            sed -i "s/${current_image_version}/${IMAGE_VERSION}/g" "${patch_file}"
            package_version=$(yq '.packageVersion' "packages/${package}/package.yaml")
            new_version=$(printf "%02d" $((10#${package_version} + 1)))
            sed -i "s/^packageVersion:.*/packageVersion: ${new_version}/" "packages/${package}/package.yaml"
        fi
    done
fi

# Bump the Traefik chart (only the latest-tracking package).
if [[ -n "${CHART_VERSION}" ]]; then
    PACKAGE="rke2-traefik"
    PACKAGE_FILE="packages/${PACKAGE}/package.yaml"
    CURRENT_URL=$(sed -n 's/^url: //p' "${PACKAGE_FILE}")
    CURRENT_VERSION=${CURRENT_URL##*/traefik-}
    CURRENT_VERSION=${CURRENT_VERSION%.tgz}
    USER=$(whoami)
    if [[ "${CURRENT_VERSION}" == "${CHART_VERSION}" ]]; then
        echo "Traefik chart is already at ${CHART_VERSION}, nothing to do"
    else
        echo "Updating Traefik chart from ${CURRENT_VERSION} to ${CHART_VERSION}"
        # A new chart resets the package version to 00, even if the image was also updated above.
        sed -i \
            -e "s|^url: .*|url: https://traefik.github.io/charts/traefik/traefik-${CHART_VERSION}.tgz|" \
            -e 's/^packageVersion: .*/packageVersion: 00/' \
            "${PACKAGE_FILE}"

        GOCACHE="/home/$USER/.cache/go-build" GOPATH="/home/$USER/go" PACKAGE="${PACKAGE}" make prepare
        find "packages/${PACKAGE}/charts" -name '*.orig' -delete
        GOCACHE="/home/$USER/.cache/go-build" GOPATH="/home/$USER/go" PACKAGE="${PACKAGE}" make patch
        GOCACHE="/home/$USER/.cache/go-build" GOPATH="/home/$USER/go" PACKAGE="${PACKAGE}" make clean
    fi
fi