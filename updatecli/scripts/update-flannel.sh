#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for flannel ${FLANNEL_VERSION}"
trap report-error EXIT INT

new_package=false
if [ -n "$CNI_PLUGINS_VERSION" ]; then
	current_cni_plugins_version=$(sed -nr 's/^\+    tag: ('v[0-9]+.[0-9]+.[0-9]+')/\1/p' packages/rke2-flannel/generated-changes/patch/values.yaml.patch  | tail -1)
	if [ "$current_cni_plugins_version" != "$CNI_PLUGINS_VERSION" ]; then
		echo "Updating CNI plugin version to $CNI_PLUGINS_VERSION"
		sed -i "s/$current_cni_plugins_version/$CNI_PLUGINS_VERSION/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
		package_version=$(yq '.packageVersion' packages/rke2-flannel/package.yaml)
		new_version=$(printf "%02d" $((10#$package_version + 1)))
		sed -i "s/packageVersion:.*/packageVersion: $new_version/g" packages/rke2-flannel/package.yaml
		new_package=true
	fi
fi
if [ -n "$FLANNEL_VERSION" ]; then
	app_version=$(echo "$FLANNEL_VERSION" | grep -Eo 'v[0-9]+.[0-9]+.[0-9]+')
	current_flannel_version=$(sed -nr 's/^\+    tag: ('v[0-9]+.[0-9]+.[0-9]+')/\1/p' packages/rke2-flannel/generated-changes/patch/values.yaml.patch  | head -1)
	current_app_version=$(echo "$current_flannel_version" | grep -Eo 'v[0-9]+.[0-9]+.[0-9]+')
	if [ "$current_flannel_version" != "$FLANNEL_VERSION" ]; then
		echo "Updating Flannel chart to $FLANNEL_VERSION"
		if [ "$app_version" != "$current_app_version" ]; then
			mkdir workdir
			wget -P workdir/ https://github.com/flannel-io/flannel/releases/download/$app_version/flannel.tgz
			tar --directory=workdir -xf workdir/flannel.tgz flannel/values.yaml
			mv workdir/flannel/values.yaml workdir/flannel/values_new.yaml
			rm workdir/flannel.tgz
			wget -P workdir/ https://github.com/flannel-io/flannel/releases/download/$current_app_version/flannel.tgz
			tar --directory=workdir -xf workdir/flannel.tgz flannel/values.yaml
			current_flannel_plugins_version=$(yq '.flannel.image_cni.tag' workdir/flannel/values.yaml)
			new_flannel_plugins_version=$(yq '.flannel.image_cni.tag' workdir/flannel/values_new.yaml)
			current_netpol_version=$(yq '.netpol.image.tag' workdir/flannel/values.yaml)
			new_netpol_version=$(yq '.netpol.image.tag' workdir/flannel/values_new.yaml)
			sed -i "s/ version: .*/ version: $app_version/g" packages/rke2-flannel/generated-changes/patch/Chart.yaml.patch
			sed -i ":a;N;\$!ba;s/-    repository: ghcr.io\\/flannel-io\\/flannel\\n-    tag: $current_app_version/-    repository: ghcr.io\\/flannel-io\\/flannel\\
-    tag: $app_version/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			sed -i "s/+    tag: $current_flannel_version/+    tag: $FLANNEL_VERSION/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			sed -i "s/-    tag: $current_flannel_plugins_version/-    tag: $new_flannel_plugins_version/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			sed -i ":a;N;\$!ba;s/-    repository: registry.k8s.io\/networking\/kube-network-policies\\n-    tag: $current_netpol_version/-    repository: registry.k8s.io\/networking\/kube-network-policies\\
-    tag: $new_netpol_version/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			yq -i ".url = \"https://github.com/flannel-io/flannel/releases/download/$app_version/flannel.tgz\" |
				.packageVersion = 00" packages/rke2-flannel/package.yaml
			rm -fr workdir
		else
			sed -i "s/+    tag: $current_flannel_version/+    tag: $FLANNEL_VERSION/g" packages/rke2-flannel/generated-changes/patch/values.yaml.patch
			if [ "$new_package" = false ]; then
				package_version=$(yq '.packageVersion' packages/rke2-flannel/package.yaml)
				new_version=$(printf "%02d" $((10#$package_version + 1)))
				sed -i "s/packageVersion:.*/packageVersion: $new_version/g" packages/rke2-flannel/package.yaml
			fi
		fi
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-flannel' make prepare
		find packages/rke2-flannel/charts -name '*.orig' -delete
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-flannel' make patch
		make clean
	fi
fi
