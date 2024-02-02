#!/bin/bash
if [ -n "$FLANNEL_VERSION" ]; then
	current_flannel_version=$(yq '.flannel.image.tag' packages/rke2-canal/charts/values.yaml)
	if [ "$current_flannel_version" != "$FLANNEL_VERSION" ]; then
		echo "Updating flannel image to $FLANNEL_VERSION"
		yq -i ".flannel.image.tag = \"$FLANNEL_VERSION\"" packages/rke2-canal/charts/values.yaml
		package_version=$(yq '.packageVersion' packages/rke2-canal/package.yaml)
		new_version=$(printf "%02d" $(($package_version + 1)))
		yq -i ".packageVersion = $new_version" packages/rke2-canal/package.yaml
	fi
fi
if [ -n "$CALICO_VERSION" ]; then
	current_calico_version=$(yq '.calico.cniImage.tag' packages/rke2-canal/charts/values.yaml)
	if [ "$current_calico_version" != "$CALICO_VERSION" ]; then
		echo "Updating flannel image to $CALICO_VERSION"
		yq -i ".calico.cniImage.tag = \"$CALICO_VERSION\" |
			.calico.flexvolImage.tag = \"$CALICO_VERSION\" |
			.calico.kubeControllerImage.tag = \"$CALICO_VERSION\"" packages/rke2-canal/charts/values.yaml
		app_version=$(echo "$CALICO_VERSION" | grep -Eo 'v[0-9]+.[0-9]+.[0-9+]')
		yq -i ".version = \"$CALICO_VERSION\" |
			.appVersion = \"$app_version\"" packages/rke2-canal/charts/Chart.yaml
		yq -i ".packageVersion = 00" packages/rke2-canal/package.yaml
	fi
fi
