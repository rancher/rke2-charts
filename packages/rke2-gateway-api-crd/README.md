# rke2-gateway-api-crd

This package ships Gateway API CRDs as a dedicated Helm chart.

## Layout

- Stable CRD source files live in [charts/crdfiles](charts/crdfiles)
- Experimental-only CRD source files live in [charts/experimentalcrds](charts/experimentalcrds)
- Stable CRDs are rendered by [charts/templates/stablecrds.yaml](charts/templates/stablecrds.yaml)
- Experimental CRDs are conditionally rendered by [charts/templates/experimentalcrds.yaml](charts/templates/experimentalcrds.yaml)
- The safe-upgrade guardrail lives in [charts/templates/safe-upgrades.yaml](charts/templates/safe-upgrades.yaml)

## Why this chart is structured this way

### Why not render the upstream YAML bundles directly?

The upstream Gateway API release files are:

- `standard-install.yaml`
- `experimental-install.yaml`

We do not keep those full files as directly-rendered chart inputs for two reasons:

1. `experimental-install.yaml` includes both stable and experimental resources.
   - We only want the experimental-only CRDs to be gated by `gatewayAPIExperimental`.
   - Because of that, we split out just the experimental-only CRDs.

2. Rendering the full upstream bundles directly makes the Helm release metadata much larger.
   - In practice, this pushed the Helm release Secret close to or beyond the Kubernetes 1 MiB Secret limit.
   - Splitting the CRDs into individual vendored files keeps the chart manageable and avoids carrying unnecessary duplicated content.

## Why not use the Helm `crds/` directory?

We intentionally do **not** keep these CRDs under the chart `crds/` directory.

Helm treats `crds/` specially:

- CRDs are installed before normal templates
- They are not managed like normal templated resources
- They are generally not deleted on uninstall
- Removed CRDs tend to remain in the cluster
- CRD lifecycle changes are harder to manage across upgrades

That behavior is not a good fit for Gateway API CRDs because:

- new CRDs may appear in later Gateway API releases
- existing CRDs can change schema
- some CRDs can move from experimental to stable
- old CRDs may need to be removed cleanly

By rendering them through normal templates instead, Helm manages them as ordinary release resources.

## Update workflow for a new Gateway API release

When updating this package to a new upstream Gateway API version:

1. Download the new standard bundle from upstream, for example:
   - `https://github.com/kubernetes-sigs/gateway-api/releases/download/<VERSION>/standard-install.yaml`
2. Replace the stable CRD files in [charts/crdfiles](charts/crdfiles)
   - Keep only the stable CRDs there
3. Download the new experimental bundle from upstream, for example:
   - `https://github.com/kubernetes-sigs/gateway-api/releases/download/<VERSION>/experimental-install.yaml`
4. Update [charts/experimentalcrds](charts/experimentalcrds)
   - Keep only the experimental-only CRDs there
   - Do not duplicate stable CRDs in this directory
5. Update [charts/templates/safe-upgrades.yaml](charts/templates/safe-upgrades.yaml)
   - Refresh the `ValidatingAdmissionPolicy` and `ValidatingAdmissionPolicyBinding` from the upstream standard bundle if they changed
   - Update bundle-version annotations as needed
6. Update chart metadata if needed:
   - [charts/Chart.yaml](charts/Chart.yaml)
   - [package.yaml](package.yaml)
7. Validate renders:
   - `helm template test packages/rke2-gateway-api-crd/charts`
   - `helm template test packages/rke2-gateway-api-crd/charts --set gatewayAPIExperimental=true`
8. Package/test the chart as needed.

## Notes on experimental CRDs

`gatewayAPIExperimental` defaults to `false` in [charts/values.yaml](charts/values.yaml).

When set to `true`, the chart renders the files in [charts/experimentalcrds](charts/experimentalcrds) in addition to the stable CRDs.

## Notes on the safe-upgrades policy

The resources in [charts/templates/safe-upgrades.yaml](charts/templates/safe-upgrades.yaml) are sourced from the upstream Gateway API standard bundle.

Within this chart's intended workflow, we already separate stable and experimental CRDs, so this chart itself should not normally try to install experimental CRDs on top of standard CRDs.

The policy is still useful as a cluster-level guardrail, mainly for cases where Gateway API CRDs are installed or modified by something else, for example:

- another Helm chart or component trying to install Gateway API CRDs
- an older manifest being applied manually
- a pre-existing cluster state that already contains different Gateway API CRDs

It exists to prevent unsafe CRD transitions, especially:

- installing experimental CRDs on top of standard CRDs
- installing CRDs older than the supported minimum
