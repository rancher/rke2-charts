#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for flannel ${FLANNEL_VERSION}"
trap report-error EXIT INT

package=packages/rke2-flannel
values=$package/charts/values.yaml

# make patch regenerates the patch against the new upstream chart, which would revert any upstream change besides the image tags
check_upstream_chart() {
	local dir=$(mktemp -d) version
	for version in "$1" "$2"; do
		mkdir "$dir/$version"
		curl -sfL "https://github.com/flannel-io/flannel/releases/download/$version/flannel.tgz" | tar -xz -C "$dir/$version"
		yq -i 'del(.version, .appVersion)' "$dir/$version/flannel/Chart.yaml"
		yq -i 'del(.flannel.image.tag, .flannel.flannel_cni.image.tag, .netpol.image.tag)' "$dir/$version/flannel/values.yaml"
	done
	if ! diff -ru "$dir/$1/flannel" "$dir/$2/flannel"; then
		echo "upstream flannel chart $2 has changes besides image tags, update rke2-flannel manually"
		return 1
	fi
	rm -rf "$dir"
}

export GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-flannel'
make prepare
find $package/charts -name '*.orig' -delete

updated=false
new_chart=false
if [ -n "$CNI_PLUGINS_VERSION" ] && [ "$(yq '.flannel.flannel_cni.image.tag' $values)" != "$CNI_PLUGINS_VERSION" ]; then
	echo "Updating CNI plugin version to $CNI_PLUGINS_VERSION"
	yq -i -c '.flannel.flannel_cni.image.tag = strenv(CNI_PLUGINS_VERSION)' $values
	updated=true
fi
if [ -n "$FLANNEL_VERSION" ] && [ "$(yq '.flannel.image.tag' $values)" != "$FLANNEL_VERSION" ]; then
	echo "Updating Flannel image to $FLANNEL_VERSION"
	yq -i -c '.flannel.image.tag = strenv(FLANNEL_VERSION)' $values
	updated=true
	export APP_VERSION=$(echo "$FLANNEL_VERSION" | grep -Eo 'v[0-9]+.[0-9]+.[0-9]+')
	current_app_version=$(yq '.appVersion' $package/charts/Chart.yaml)
	if [ "$current_app_version" != "$APP_VERSION" ]; then
		echo "Updating Flannel chart to $APP_VERSION"
		check_upstream_chart "$current_app_version" "$APP_VERSION"
		yq -i '.version = strenv(APP_VERSION) | .appVersion = strenv(APP_VERSION)' $package/charts/Chart.yaml
		yq -i '.url = "https://github.com/flannel-io/flannel/releases/download/" + strenv(APP_VERSION) + "/flannel.tgz"' $package/package.yaml
		new_chart=true
	fi
fi

# yq retags leading-zero values (08/09), so use sed for packageVersion
if [ "$new_chart" = true ]; then
	sed -i "s/packageVersion:.*/packageVersion: 01/g" $package/package.yaml
elif [ "$updated" = true ]; then
	package_version=$(yq '.packageVersion' $package/package.yaml)
	new_version=$(printf "%02d" $((10#$package_version + 1)))
	sed -i "s/packageVersion:.*/packageVersion: $new_version/g" $package/package.yaml
fi
if [ "$updated" = true ]; then
	make patch
fi
make clean
