#!/bin/bash
set -eu
if [ -n "$WHEREABOUTS_VERSION" ]; then
	app_version=$(echo "$WHEREABOUTS_VERSION" | grep -Eo '^v*[0-9]+.[0-9]+.[0-9]+' | tr -d 'v')
	current_whereabouts_version=$(yq '.image.tag' packages/rke2-whereabouts/charts/values.yaml)
	current_app_version=$(echo "$current_whereabouts_version" | grep -Eo '^v*[0-9]+.[0-9]+.[0-9]+' | tr -d 'v')
	if [ "$current_whereabouts_version" != "$WHEREABOUTS_VERSION" ]; then
		echo "Updating Whereabouts chart to $WHEREABOUTS_VERSION"
		if [ "$app_version" != "$current_app_version" ]; then
			sed -i "s/version: .*/version: $app_version/g" packages/rke2-whereabouts/charts/Chart.yaml
			sed -i "s/appVersion: .*/appVersion: $app_version/g" packages/rke2-whereabouts/charts/Chart.yaml
			sed -i "s/  tag: $current_whereabouts_version/  tag: $WHEREABOUTS_VERSION/g" packages/rke2-whereabouts/charts/values.yaml
			yq -i ".packageVersion = 00" packages/rke2-whereabouts/package.yaml
			multus_package_version=$(yq '.packageVersion' packages/rke2-multus/package.yaml)
			multus_new_version=$(printf "%02d" $(($multus_package_version + 1)))
			yq -i ".packageVersion = $multus_new_version" packages/rke2-multus/package.yaml
		else
			sed -i "s/  tag: $current_whereabouts_version/  tag: $WHEREABOUTS_VERSION/g" packages/rke2-whereabouts/charts/values.yaml
			package_version=$(yq '.packageVersion' packages/rke2-whereabouts/package.yaml)
			new_version=$(printf "%02d" $(($package_version + 1)))
			yq -i ".packageVersion = $new_version" packages/rke2-whereabouts/package.yaml
			multus_package_version=$(yq '.packageVersion' packages/rke2-multus/package.yaml)
			multus_new_version=$(printf "%02d" $(($multus_package_version + 1)))
			yq -i ".packageVersion = $multus_new_version" packages/rke2-multus/package.yaml
		fi
	fi
fi
