#!/bin/bash
set -eu

source $(dirname $0)/create-issue.sh

ISSUE_TITLE="Updatecli failed for calico ${CALICO_VERSION}" 
trap report-error EXIT INT

if [ -n "$CALICO_VERSION" ]; then
	current_calico_version=$(yq '.version' packages/rke2-calico/templates/crd-template/Chart.yaml)
	if [ "$current_calico_version" != "$CALICO_VERSION" ]; then
		case "$CALICO_VERSION" in
			v3.31.4) CALICO_TIGERA_SHA256="cbf4048b43384d06a029ce117616afc5d2311bc3df65eacfe5465c59c1a1bb52" ;;
			*) echo "No pinned SHA256 for CALICO_VERSION=$CALICO_VERSION" >&2; exit 1 ;;
		esac
		echo "Updating Calico chart to $CALICO_VERSION"
		mkdir workdir
		wget -P workdir/ https://github.com/projectcalico/calico/releases/download/$CALICO_VERSION/tigera-operator-$CALICO_VERSION.tgz
		echo "$CALICO_TIGERA_SHA256  workdir/tigera-operator-$CALICO_VERSION.tgz" | sha256sum -c -
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
		find packages/rke2-calico/charts -name '*.orig' -delete
		find packages/rke2-calico/charts-crd -name '*.orig' -delete
		GOCACHE='/home/runner/.cache/go-build' GOPATH='/home/runner/go' PACKAGE='rke2-calico' make patch
		make clean
	fi
fi
