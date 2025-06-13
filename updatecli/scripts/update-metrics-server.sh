#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for metrics-server ${METRICS_SERVER_CHART_VERSION}"
trap report-error EXIT INT

CHART_UPDATED=false
IMAGES_UPDATED=false

if [ -n "$METRICS_SERVER_IMAGE_VERSION" ]; then
	current_image_version=$(sed -nr 's/^\+  tag: ('v[0-9]+.[0-9]+.[0-9]+-build[0-9]+')/\1/p' packages/rke2-metrics-server/generated-changes/patch/values.yaml.patch)
	if [ "$current_image_version" != "$METRICS_SERVER_IMAGE_VERSION" ]; then
		echo "Updating metrics-server image to $METRICS_SERVER_IMAGE_VERSION"
		sed -i "s/$current_image_version/$METRICS_SERVER_IMAGE_VERSION/g" packages/rke2-metrics-server/generated-changes/patch/values.yaml.patch
		IMAGES_UPDATED=true
	fi
fi
if [ -n "$ADDON_RESIZER_IMAGE_VERSION" ]; then
	current_image_version=$(sed -nr 's/^\+    tag: ('[0-9]+.[0-9]+.[0-9]+-build[0-9]+')/\1/p' packages/rke2-metrics-server/generated-changes/patch/values.yaml.patch)
	if [ "$current_image_version" != "$ADDON_RESIZER_IMAGE_VERSION" ]; then
		echo "Updating addon-resizer image to $ADDON_RESIZER_IMAGE_VERSION"
		sed -i "s/$current_image_version/$ADDON_RESIZER_IMAGE_VERSION/g" packages/rke2-metrics-server/generated-changes/patch/values.yaml.patch
		IMAGES_UPDATED=true
	fi
fi
if [ "$IMAGES_UPDATED" = true  ]; then
	package_version=$(yq '.packageVersion' packages/rke2-metrics-server/package.yaml)
	new_version=$(printf "%02d" $(($package_version + 1)))
	yq -i ".packageVersion = $new_version" packages/rke2-metrics-server/package.yaml
fi
if [ -n "$METRICS_SERVER_CHART_VERSION" ]; then
	# 1 - check if there is a new upstream chart
	current_url=$(yq '.url' packages/rke2-metrics-server/package.yaml)
	current_chart_version=$(awk -F'/metrics-server-helm-chart-|/metrics-server-|.tgz' '{print $2}' <<< $current_url)
	if [ "$current_chart_version" != "$METRICS_SERVER_CHART_VERSION" ]; then
		echo "Updating Kubernetes Metrics Server chart to $METRICS_SERVER_CHART_VERSION"
		# if there is a new chart, reset the package version to 00 even if the images are also updated
		yq -i ".url = \"https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-${METRICS_SERVER_CHART_VERSION}/metrics-server-${METRICS_SERVER_CHART_VERSION}.tgz\" |
			.packageVersion = 00" packages/rke2-metrics-server/package.yaml
		mkdir workdir
		wget -P workdir/ https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-${METRICS_SERVER_CHART_VERSION}/metrics-server-${METRICS_SERVER_CHART_VERSION}.tgz
		tar --directory=workdir -xf workdir/metrics-server-${METRICS_SERVER_CHART_VERSION}.tgz metrics-server/values.yaml
		mv workdir/metrics-server/values.yaml workdir/metrics-server/values_new.yaml
		rm workdir/metrics-server-${METRICS_SERVER_CHART_VERSION}.tgz
		wget -P workdir/ https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-${current_chart_version}/metrics-server-${current_chart_version}.tgz
		tar --directory=workdir -xf workdir/metrics-server-${current_chart_version}.tgz metrics-server/values.yaml
		rm -fr workdir
		# prepare patch
		GOCACHE="/home/runner/.cache/go-build" GOPATH="/home/runner/go" PACKAGE="rke2-metrics-server" make prepare
		find packages/rke2-metrics-server/charts -name '*.orig' -delete
		GOCACHE="/home/runner/.cache/go-build" GOPATH="/home/runner/go" PACKAGE="rke2-metrics-server" make patch
		# clean-up
		GOCACHE="/home/runner/.cache/go-build" GOPATH="/home/runner/go" PACKAGE="rke2-metrics-server" make clean
	fi
fi
