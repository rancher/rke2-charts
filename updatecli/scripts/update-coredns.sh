#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for coredns ${COREDNS_CHART_VERSION}" 
trap report-error EXIT INT

CHART_UPDATED=false
IMAGES_UPDATED=false

if [ -n "$COREDNS_VERSION" ]; then
	current_tag_coredns_version=$(sed -nr 's/^\+  tag: \"('v[0-9]+.[0-9]+.[0-9]+-build[0-9]+')\"/\1/p' packages/rke2-coredns/generated-changes/patch/values.yaml.patch)
	if [ "$current_tag_coredns_version" != "$COREDNS_VERSION" ]; then
		echo "Updating coredns image to $COREDNS_VERSION"
		sed -i "s/$current_tag_coredns_version/$COREDNS_VERSION/g" packages/rke2-coredns/generated-changes/patch/values.yaml.patch
		IMAGES_UPDATED=true
	fi
fi
if [ -n "$AUTOSCALER_VERSION" ]; then
	current_tag_autoscaler_version=$(sed -nr 's/^\+    tag: \"('v[0-9]+.[0-9]+.[0-9]+-build[0-9]+')\"/\1/p' packages/rke2-coredns/generated-changes/patch/values.yaml.patch)
	if [ "$current_tag_autoscaler_version" != "$AUTOSCALER_VERSION" ]; then
		echo "Updating autoscaler image to $AUTOSCALER_VERSION"
		sed -i "s/$current_tag_autoscaler_version/$AUTOSCALER_VERSION/g" packages/rke2-coredns/generated-changes/patch/values.yaml.patch
		IMAGES_UPDATED=true
	fi
fi
if [ -n "$NODECACHE_VERSION" ]; then
	current_tag_nodecache_version=$(sed -nr 's/^\+    tag: \"('[0-9]+.[0-9]+.[0-9]+-build[0-9]+')\"/\1/p' packages/rke2-coredns/generated-changes/patch/values.yaml.patch | tail -1)
	if [ "$current_tag_nodecache_version" != "$NODECACHE_VERSION" ]; then
		echo "Updating nodecache image to $NODECACHE_VERSION"
		sed -i "s/$current_tag_nodecache_version/$NODECACHE_VERSION/g" packages/rke2-coredns/generated-changes/patch/values.yaml.patch
		IMAGES_UPDATED=true
	fi
fi
if [ "$IMAGES_UPDATED" = true  ]; then
	package_version=$(yq '.packageVersion' packages/rke2-coredns/package.yaml)
	new_version=$(printf "%02d" $(($package_version + 1)))
	yq -i ".packageVersion = $new_version" packages/rke2-coredns/package.yaml
fi
if [ -n "$COREDNS_CHART_VERSION" ]; then
	# 1 - check if there is a new upstream chart
	current_coredns_url=$(yq '.url' packages/rke2-coredns/package.yaml)
	current_coredns_chart_version=$(awk -F'/coredns-|.tgz' '{print $2}' <<< $current_coredns_url)
	if [ "$current_coredns_chart_version" != "$COREDNS_CHART_VERSION" ]; then
		echo "Updating Coredns chart to $COREDNS_CHART_VERSION"
		# if there is a new chart, reset the package version to 00 even if the images are also updated
		yq -i ".url = \"https://github.com/coredns/helm/releases/download/coredns-${COREDNS_CHART_VERSION}/coredns-${COREDNS_CHART_VERSION}.tgz\" |
			.packageVersion = 00" packages/rke2-coredns/package.yaml
		mkdir workdir
		wget -P workdir/ https://github.com/coredns/helm/releases/download/coredns-${COREDNS_CHART_VERSION}/coredns-${COREDNS_CHART_VERSION}.tgz
		tar --directory=workdir -xf workdir/coredns-${COREDNS_CHART_VERSION}.tgz coredns/values.yaml
		mv workdir/coredns/values.yaml workdir/coredns/values_new.yaml
		rm workdir/coredns-${COREDNS_CHART_VERSION}.tgz
		wget -P workdir/ https://github.com/coredns/helm/releases/download/coredns-${current_coredns_chart_version}/coredns-${current_coredns_chart_version}.tgz
		tar --directory=workdir -xf workdir/coredns-${current_coredns_chart_version}.tgz coredns/values.yaml
		current_autoscaler_version=$(yq '.autoscaler.image.tag' workdir/coredns/values.yaml)
		new_autoscaler_version=$(yq '.autoscaler.image.tag' workdir/coredns/values_new.yaml)
		sed -i "s/$current_autoscaler_version/$new_autoscaler_version/g" packages/rke2-coredns/generated-changes/patch/values.yaml.patch
		rm -fr workdir
		# prepare patch
		GOCACHE="/home/runner/.cache/go-build" GOPATH="/home/runner/go" PACKAGE="rke2-coredns" make prepare
		find packages/rke2-coredns/charts -name '*.orig' -delete
		GOCACHE="/home/runner/.cache/go-build" GOPATH="/home/runner/go" PACKAGE="rke2-coredns" make patch
		# clean-up
		GOCACHE="/home/runner/.cache/go-build" GOPATH="/home/runner/go" PACKAGE="rke2-coredns" make clean
	fi
fi
