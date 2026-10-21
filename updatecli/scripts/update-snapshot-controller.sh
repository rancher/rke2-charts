#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for snapshot-controller ${SNAPSHOT_CONTROLLER_IMAGE_VERSION}"
trap report-error EXIT INT

IMAGES_UPDATED=false

if [ -n "$SNAPSHOT_CONTROLLER_IMAGE_VERSION" ]; then
	current_image_version=$(sed -nr 's/^\+    tag: "(v[0-9]+\.[0-9]+\.[0-9]+-build[0-9]+)"/\1/p' packages/rke2-snapshot-controller/generated-changes/patch/values.yaml.patch)
	if [ "$current_image_version" != "$SNAPSHOT_CONTROLLER_IMAGE_VERSION" ]; then
		echo "Updating snapshot-controller image to $SNAPSHOT_CONTROLLER_IMAGE_VERSION"
		sed -i "s/$current_image_version/$SNAPSHOT_CONTROLLER_IMAGE_VERSION/g" packages/rke2-snapshot-controller/generated-changes/patch/values.yaml.patch
		IMAGES_UPDATED=true
	fi
fi
if [ "$IMAGES_UPDATED" = true ]; then
	package_version=$(yq '.packageVersion' packages/rke2-snapshot-controller/package.yaml)
	new_version=$(printf "%02d" $((10#$package_version + 1)))
	sed -i "s/packageVersion:.*/packageVersion: $new_version/g" packages/rke2-snapshot-controller/package.yaml
fi
