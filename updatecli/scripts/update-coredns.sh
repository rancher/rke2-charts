#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for coredns ${COREDNS_CHART_VERSION}" 
trap report-error EXIT INT

CHART_UPDATED=false
IMAGES_UPDATED=false

if [ -n "$COREDNS_CHART_VERSION" ]; then
	# 1 - check if there is a new upstream chart
	current_coredns_url=$(yq '.url' packages/rke2-coredns/package.yaml)
	current_coredns_chart_version=$(awk -F'/coredns-|.tgz' '{print $2}' <<< $current_coredns_url)
	if [ "$current_coredns_chart_version" != "$COREDNS_CHART_VERSION" ]; then
		echo "Updating Coredns chart to $COREDNS_CHART_VERSION"
		# if there is a new chart, reset the package version to 00 even if the images are also updated
		yq -i ".url = \"https://github.com/coredns/helm/releases/download/coredns-${COREDNS_CHART_VERSION}/coredns-${COREDNS_CHART_VERSION}.tgz\" |
			.packageVersion = 00" packages/rke2-coredns/package.yaml
		CHART_UPDATED=true
	fi
	GOCACHE='/home/azureuser/.cache/go-build' GOPATH='/home/azureuser/go' PACKAGE='rke2-coredns' make prepare

	# 2 - check if the images have been updated
	if [ -n "$COREDNS_VERSION" ]; then
		current_coredns_version=$(yq '.image.tag' packages/rke2-coredns/charts/values.yaml)
		if [ "$current_coredns_version" != "$COREDNS_VERSION" ]; then
			echo "Updating coredns image to $COREDNS_VERSION"
			yq -i ".image.tag = \"$COREDNS_VERSION\"" packages/rke2-coredns/charts/values.yaml
			IMAGES_UPDATED=true
		fi
	fi
	if [ -n "$AUTOSCALER_VERSION" ]; then
		current_autoscaler_version=$(yq '.autoscaler.image.tag' packages/rke2-coredns/charts/values.yaml)
		if [ "$current_autoscaler_version" != "$AUTOSCALER_VERSION" ]; then
			echo "Updating autoscaler image to $AUTOSCALER_VERSION"
			yq -i ".autoscaler.image.tag = \"$AUTOSCALER_VERSION\"" packages/rke2-coredns/charts/values.yaml
			IMAGES_UPDATED=true
		fi
	fi
	if [ -n "$NODECACHE_VERSION" ]; then
		current_nodecache_version=$(yq '.nodelocal.image.tag' packages/rke2-coredns/charts/values.yaml)
		if [ "$current_nodecache_version" != "$NODECACHE_VERSION" ]; then
			echo "Updating nodecache image to $NODECACHE_VERSION"
			yq -i ".nodelocal.image.tag = \"$NODECACHE_VERSION\" |
				  .nodelocal.initimage.tag = \"$NODECACHE_VERSION\"" packages/rke2-coredns/charts/values.yaml
			IMAGES_UPDATED=true
		fi
	fi

	# 3 - update the package version accordingly
	if [ "$CHART_UPDATED" = false ] && [ "$IMAGES_UPDATED" = true  ]; then
		package_version=$(yq '.packageVersion' packages/rke2-coredns/package.yaml)
		new_version=$(printf "%02d" $(($package_version + 1)))
		yq -i ".packageVersion = $new_version" packages/rke2-coredns/package.yaml
	fi
	# prepare patch
	find packages/rke2-coredns/charts -name '*.orig' -delete
	GOCACHE='/home/azureuser/.cache/go-build' GOPATH='/home/azureuser/go' PACKAGE='rke2-coredns' make patch
	# clean-up
	make clean
fi
