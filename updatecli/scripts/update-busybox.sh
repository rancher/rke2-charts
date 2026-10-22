#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for busybox ${BUSYBOX_VERSION}"
trap report-error EXIT INT

if [ -n "$BUSYBOX_VERSION" ]; then
	for package in rke2-multus rke2-multus-1.34-1.36; do
		values="packages/$package/charts/values.yaml"
		current_version=$(yq '.dhcpDaemonSet.image.tag' "$values")
		if [ "$current_version" != "$BUSYBOX_VERSION" ]; then
			echo "Updating busybox image to $BUSYBOX_VERSION in $package"
			sed -i "s/    tag: \"$current_version\"/    tag: \"$BUSYBOX_VERSION\"/g" "$values"
			package_version=$(yq '.packageVersion' "packages/$package/package.yaml")
			new_version=$(printf "%02d" $((10#$package_version + 1)))
			sed -i "s/packageVersion:.*/packageVersion: $new_version/g" "packages/$package/package.yaml"
		fi
	done
fi
