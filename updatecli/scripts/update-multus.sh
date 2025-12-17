#!/bin/bash
set -eux

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for multus ${MULTUS_VERSION}"
trap report-error EXIT INT

new_package=false
if [ -n "$CNI_PLUGINS_VERSION" ]; then
	current_cni_plugins_version=$(yq '.cniplugins.image.tag' packages/rke2-multus/charts/values.yaml)
	if [ "$current_cni_plugins_version" != "$CNI_PLUGINS_VERSION" ]; then
		echo "Updating CNI plugin version to $CNI_PLUGINS_VERSION"
		export CNI_PLUGINS_VERSION
		yq -i ".cniplugins.image.tag = strenv(CNI_PLUGINS_VERSION)" packages/rke2-multus/charts/values.yaml
		package_version=$(yq '.packageVersion' packages/rke2-multus/package.yaml)
		new_version=$(printf "%02d" $(($package_version + 1)))
		export new_version
		yq -i ".packageVersion = strenv(new_version)" packages/rke2-multus/package.yaml
		new_package=true
	fi
fi
if [ -n "$MULTUS_VERSION" ]; then
	app_version=$(echo "$MULTUS_VERSION" | grep -Eo '^v*[0-9]+.[0-9]+.[0-9]+' | tr -d 'v')
	current_multus_version=$(yq '.image.tag' packages/rke2-multus/charts/values.yaml)
	current_app_version=$(echo "$current_multus_version" | grep -Eo '^v*[0-9]+.[0-9]+.[0-9]+' | tr -d 'v')
	if [ "$current_multus_version" != "$MULTUS_VERSION" ]; then
		echo "Updating Multus chart to $MULTUS_VERSION"
		if [ "$app_version" != "$current_app_version" ]; then
			export app_version MULTUS_VERSION
			yq -i ".version = \"v\" + strenv(app_version)" packages/rke2-multus/charts/Chart.yaml
			yq -i ".appVersion = strenv(app_version)" packages/rke2-multus/charts/Chart.yaml
			yq -i ".image.tag = strenv(MULTUS_VERSION)" packages/rke2-multus/charts/values.yaml
			yq -i ".thickPlugin.image.tag = strenv(MULTUS_VERSION)" packages/rke2-multus/charts/values.yaml
			yq -i ".dynamicNetworksController.image.tag = strenv(MULTUS_VERSION)" packages/rke2-multus/charts/values.yaml
			yq -i ".packageVersion = \"00\"" packages/rke2-multus/package.yaml
		else
			export MULTUS_VERSION
			yq -i ".image.tag = strenv(MULTUS_VERSION)" packages/rke2-multus/charts/values.yaml
			yq -i ".thickPlugin.image.tag = strenv(MULTUS_VERSION)" packages/rke2-multus/charts/values.yaml
			yq -i ".dynamicNetworksController.image.tag = strenv(MULTUS_VERSION)" packages/rke2-multus/charts/values.yaml
			if [ "$new_package" = false ]; then
				package_version=$(yq '.packageVersion' packages/rke2-multus/package.yaml)
				new_version=$(printf "%02d" $((10#$package_version + 1)))
				export new_version
				yq -i ".packageVersion = strenv(new_version)" packages/rke2-multus/package.yaml
			fi
		fi
	fi
fi
