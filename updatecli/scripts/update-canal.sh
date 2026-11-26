#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for canal ${CALICO_VERSION} / ${FLANNEL_VERSION}" 
trap report-error EXIT INT

bump_package=false
reset_package=false

if [ -n "$FLANNEL_VERSION" ]; then
	current_flannel_version=$(yq '.flannel.image.tag' packages/rke2-canal/charts/values.yaml)
	if [ "$current_flannel_version" != "$FLANNEL_VERSION" ]; then
		echo "Updating flannel image to $FLANNEL_VERSION"
		yq -i ".flannel.image.tag = \"$FLANNEL_VERSION\"" packages/rke2-canal/charts/values.yaml
		bump_package=true
	fi
fi
if [ -n "$CNI_PLUGINS_VERSION" ]; then
	current_cni_plugins_version=$(yq '.calico.cniPlugins.tag' packages/rke2-canal/charts/values.yaml)
	if [ "$current_cni_plugins_version" != "$CNI_PLUGINS_VERSION" ]; then
		echo "Updating cni plugins image to $CNI_PLUGINS_VERSION"
		yq -i ".calico.cniPlugins.tag = \"$CNI_PLUGINS_VERSION\"" packages/rke2-canal/charts/values.yaml
		bump_package=true
	fi
fi
if [ -n "$CALICO_VERSION" ]; then
	current_calico_version=$(yq '.calico.cniImage.tag' packages/rke2-canal/charts/values.yaml)
	if [ "$current_calico_version" != "$CALICO_VERSION" ]; then
		echo "Updating flannel image to $CALICO_VERSION"
		yq -i ".calico.cniImage.tag = \"$CALICO_VERSION\" |
			.calico.flexvolImage.tag = \"$CALICO_VERSION\" |
			.calico.nodeImage.tag = \"$CALICO_VERSION\" |
			.calico.kubeControllerImage.tag = \"$CALICO_VERSION\"" packages/rke2-canal/charts/values.yaml
		app_version=$(echo "$CALICO_VERSION" | grep -Eo 'v[0-9]+.[0-9]+.[0-9]+')
		current_app_version=$(yq '.appVersion' packages/rke2-canal/charts/Chart.yaml)
		yq -i ".version = \"$CALICO_VERSION\" |
			.appVersion = \"$app_version\"" packages/rke2-canal/charts/Chart.yaml
		if [ "$current_app_version" != "$app_version" ]; then
			reset_package=true
		else
			bump_package=true
		fi
	fi
fi

# packageVersion is appended to the chart patch version, so only reset it on a new calico x.y.z
if [ "$reset_package" = true ]; then
	sed -i "s/packageVersion:.*/packageVersion: 01/g" packages/rke2-canal/package.yaml
elif [ "$bump_package" = true ]; then
	package_version=$(yq '.packageVersion' packages/rke2-canal/package.yaml)
	new_version=$(printf "%02d" $((10#$package_version + 1)))
	sed -i "s/packageVersion:.*/packageVersion: $new_version/g" packages/rke2-canal/package.yaml
fi
