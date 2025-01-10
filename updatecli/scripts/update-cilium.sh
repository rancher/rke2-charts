#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for cilium ${CILIUM_VERSION}" 
trap report-error EXIT INT

if [ -n "$CILIUM_VERSION" ]; then
	current_cilium_version=$(sed -nr 's/^\ version: ('[0-9]+.[0-9]+.[0-9]+')/\1/p' packages/rke2-cilium/generated-changes/patch/Chart.yaml.patch)
	if [ "v$current_cilium_version" != "$CILIUM_VERSION" ]; then
		echo "Updating Cilium chart to $CILIUM_VERSION"
		cilium_num_version=$(echo "$CILIUM_VERSION" | grep -Eo '[0-9]+.[0-9]+.[0-9]+')
		mkdir workdir
		sed -i "s/ appVersion: .*/ appVersion: $cilium_num_version/g" packages/rke2-cilium/generated-changes/patch/Chart.yaml.patch
		sed -i "s/ version: .*/ version: $cilium_num_version/g" packages/rke2-cilium/generated-changes/patch/Chart.yaml.patch
		yq -i ".url = \"https://helm.cilium.io/cilium-$cilium_num_version.tgz\" |
			.packageVersion = 00" packages/rke2-cilium/package.yaml
		mv packages/rke2-cilium/generated-changes/patch/values.yaml.patch workdir
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-cilium' make prepare
		cp packages/rke2-cilium/charts/values.yaml workdir
		cp updatecli/scripts/cilium-values.yaml.patch.template workdir
		#Extract values used to patch the file
		CILIUM_IMAGE_VERSION=$(yq ".image.tag" workdir/values.yaml)
		CILIUM_IMAGE_DIGEST=$(yq ".image.digest" workdir/values.yaml)
		CILIUM_CERTGEN_VERSION=$(yq ".certgen.image.tag" workdir/values.yaml)
		CILIUM_CERTGEN_DIGEST=$(yq ".certgen.image.digest" workdir/values.yaml)
		CILIUM_HUBBLE_RELAY_VERSION=$(yq ".hubble.relay.image.tag" workdir/values.yaml)
		CILIUM_HUBBLE_RELAY_DIGEST=$(yq ".hubble.relay.image.digest" workdir/values.yaml)
		CILIUM_HUBBLE_UI_BACKEND_VERSION=$(yq ".hubble.ui.backend.image.tag" workdir/values.yaml)
		CILIUM_HUBBLE_UI_BACKEND_DIGEST=$(yq ".hubble.ui.backend.image.digest" workdir/values.yaml)
		CILIUM_HUBBLE_UI_VERSION=$(yq ".hubble.ui.frontend.image.tag" workdir/values.yaml)
		CILIUM_HUBBLE_UI_DIGEST=$(yq ".hubble.ui.frontend.image.digest" workdir/values.yaml)
		CILIUM_ENVOY_VERSION=$(yq ".envoy.image.tag" workdir/values.yaml)
		CILIUM_ENVOY_DIGEST=$(yq ".envoy.image.digest" workdir/values.yaml)
		CILIUM_OPERATOR_VERSION=$(yq ".operator.image.tag" workdir/values.yaml)
		CILIUM_OPERATOR_DIGEST=$(yq ".operator.image.genericDigest" workdir/values.yaml)
		CILIUM_AZURE_OPERATOR_DIGEST=$(yq ".operator.image.azureDigest" workdir/values.yaml)
		CILIUM_AWS_OPERATOR_DIGEST=$(yq ".operator.image.awsDigest" workdir/values.yaml)
		CILIUM_ALIBA_OPERATOR_DIGEST=$(yq ".operator.image.alibabacloudDigest" workdir/values.yaml)
		CILIUM_CLUSTERMESH_VERSION=$(yq ".clustermesh.apiserver.image.tag" workdir/values.yaml)
		CILIUM_CLUSTERMESH_DIGEST=$(yq ".clustermesh.apiserver.image.digest" workdir/values.yaml)
		sed -ie "s/CILIUM_IMAGE_VERSION/$CILIUM_IMAGE_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_IMAGE_DIGEST/$CILIUM_IMAGE_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_CERTGEN_VERSION/$CILIUM_CERTGEN_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_CERTGEN_DIGEST/$CILIUM_CERTGEN_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_HUBBLE_RELAY_VERSION/$CILIUM_HUBBLE_RELAY_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_HUBBLE_RELAY_DIGEST/$CILIUM_HUBBLE_RELAY_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_HUBBLE_UI_BACKEND_VERSION/$CILIUM_HUBBLE_UI_BACKEND_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_HUBBLE_UI_BACKEND_DIGEST/$CILIUM_HUBBLE_UI_BACKEND_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_HUBBLE_UI_VERSION/$CILIUM_HUBBLE_UI_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_HUBBLE_UI_DIGEST/$CILIUM_HUBBLE_UI_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_ENVOY_VERSION/$CILIUM_ENVOY_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_ENVOY_DIGEST/$CILIUM_ENVOY_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_OPERATOR_VERSION/$CILIUM_OPERATOR_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_OPERATOR_DIGEST/$CILIUM_OPERATOR_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_AZURE_OPERATOR_DIGEST/$CILIUM_AZURE_OPERATOR_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_AWS_OPERATOR_DIGEST/$CILIUM_AWS_OPERATOR_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_ALIBA_OPERATOR_DIGEST/$CILIUM_ALIBA_OPERATOR_DIGEST/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_CLUSTERMESH_VERSION/$CILIUM_CLUSTERMESH_VERSION/g" workdir/cilium-values.yaml.patch.template
		sed -ie "s/CILIUM_CLUSTERMESH_DIGEST/$CILIUM_CLUSTERMESH_DIGEST/g" workdir/cilium-values.yaml.patch.template
		make clean
		cp workdir/cilium-values.yaml.patch.template packages/rke2-cilium/generated-changes/patch/values.yaml.patch
		rm -fr workdir
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-cilium' make prepare
		find packages/rke2-cilium/charts -name '*.orig' -delete 
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-cilium' make patch
		make clean
	fi
fi
