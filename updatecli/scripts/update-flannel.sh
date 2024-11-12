#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for flannel ${FLANNEL_VERSION}"
trap report-error EXIT INT

if [ -n "$FLANNEL_VERSION" ]; then
	app_version=$(echo "$FLANNEL_VERSION" | grep -Eo 'v[0-9]+.[0-9]+.[0-9]+')
	current_flannel_version=$(sed -nr 's/^\+    tag: ('v[0-9]+.[0-9]+.[0-9]+')/\1/p' packages/rke2-flannel/generated-changes/patch/values.yaml.patch  | head -1)
	current_app_version=$(echo "$current_flannel_version" | grep -Eo 'v[0-9]+.[0-9]+.[0-9]+')
	if [ "$current_flannel_version" != "$FLANNEL_VERSION" ]; then
		echo "Updating Flannel chart to $FLANNEL_VERSION"
		if [ "$app_version" != "$current_app_version" ]; then
			sed -i "s/ version: .*/ version: $app_version/g" packages/rke2-flannel/generated-changes/patch/Chart.yaml.patch
			sed -i "s/-    tag: $current_app_version/-    tag: $app_version/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			sed -i "s/+    tag: $current_flannel_version/+    tag: $FLANNEL_VERSION/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			yq -i ".url = \"https://github.com/flannel-io/flannel/releases/download/$app_version/flannel.tgz\" |
				.packageVersion = 00" packages/rke2-flannel/package.yaml
		else
			sed -i "s/+    tag: $current_flannel_version/+    tag: $FLANNEL_VERSION/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			package_version=$(yq '.packageVersion' packages/rke2-flannel/package.yaml)
			new_version=$(printf "%02d" $(($package_version + 1)))
			yq -i ".packageVersion = $new_version" packages/rke2-flannel/package.yaml
		fi
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-flannel' make prepare
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-flannel' make patch
		make clean
	fi
fi
