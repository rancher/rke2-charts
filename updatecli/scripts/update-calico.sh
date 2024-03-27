#!/bin/bash
if [ -n "$CALICO_VERSION" ]; then
	current_calico_version=$(yq '.version' packages/rke2-calico/templates/crd-template/Chart.yaml)
	if [ "$current_calico_version" != "$CALICO_VERSION" ]; then
		echo "Updating Calico chart to $CALICO_VERSION"
		mkdir workdir
		wget -P workdir/ https://github.com/projectcalico/calico/releases/download/$CALICO_VERSION/tigera-operator-$CALICO_VERSION.tgz
		tar --directory=workdir -xf workdir/tigera-operator-$CALICO_VERSION.tgz tigera-operator/values.yaml
		current_tigera_operator_version=$(yq '.tigeraOperator.version' workdir/tigera-operator/values.yaml)
		rm -fr workdir
		sed -i "s/ version: .*/ version: $CALICO_VERSION/g" packages/rke2-calico/generated-changes/patch/Chart.yaml.patch
		sed -i "s/   version: .*/   version: $current_tigera_operator_version/g" packages/rke2-calico/generated-changes/patch/values.yaml.patch
		sed -i "s/   tag: .*/   tag: $CALICO_VERSION/g" packages/rke2-calico/generated-changes/patch/values.yaml.patch
		yq -i ".version = \"$CALICO_VERSION\"" packages/rke2-calico/templates/crd-template/Chart.yaml
		yq -i ".url = \"https://github.com/projectcalico/calico/releases/download/$CALICO_VERSION/tigera-operator-$CALICO_VERSION.tgz\" |
			.packageVersion = 00" packages/rke2-calico/package.yaml
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-calico' make prepare
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-calico' make patch
		make clean
	fi
fi
