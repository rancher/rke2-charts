## Source Branch

`main-source` contains package definitions, upstream patches, and maintenance
automation. `main` contains the published Helm repository: historical chart
archives, extracted charts, and `index.yaml`. Do not merge these branches or
commit generated repository output to `main-source`.

See the README.md under `packages/` for more information.

The following directory structure is expected:
```text
packages/
  <package>/
```


### RKE2 Integration

RKE2 injects at runtime a number of cluster configuration values into values.yaml; the most important of which is `global.systemDefaultRegistry`.
If set this **must** be used as a registry prefix for all images used by the chart.

The authoritative list of variables can be found within the
[setChartValues function of bootstrap.go](https://github.com/rancher/rke2/blob/master/pkg/bootstrap/bootstrap.go);
at the time this document was last updated it includes:
* `global.clusterCIDR` - the CIDR range used for pod IP addresses.
* `global.clusterDNS` - the cluster DNS (coredns) service address.
* `global.clusterDomain` - the cluster DNS suffix.
* `global.rke2DataDir` - the RKE2 data-dir; effectively must be the same on all nodes.
* `global.serviceCIDR` - the CIDR range used for in-cluster service IP addresses.
* `global.systemDefaultRegistry` - the default registry that all images should be loaded from.

For an example of a chart that uses systemdefaultregistry you can look at:
* https://github.com/rancher/rke2-charts/blob/de5dd4c9f4ded7c08b4417922f691139d2417e9f/packages/rke2-canal/charts/templates/_helpers.tpl#L1-L7
* https://github.com/rancher/rke2-charts/blob/de5dd4c9f4ded7c08b4417922f691139d2417e9f/packages/rke2-canal/charts/templates/daemonset.yaml#L53

### Configuration

[`configuration.yaml`](configuration.yaml) identifies the authoritative
published repository for validation and the Helm repository hostname.

#### Validate

[`scripts/validate-charts`](scripts/validate-charts) compares native chart output
with the published `main` checkout. It rejects changed contents for an already
published chart version, stages only new chart identities, updates the index
with the upstream builder, and verifies historical index entries remain intact.

PRs targeting `main-source` generate charts and validate them against a
separate `main` checkout without write credentials. Pushes to `main-source`
repeat validation against a fresh `main` checkout, then commit and push only
new chart output and `index.yaml`. Publishing commits include a
`Source-Commit` trailer; runs are serialized, reject older source revisions,
and use non-force pushes. A rerun without new charts is a no-op.

To validate and stage locally against an existing clean main checkout instead
of cloning the configured repository:

```shell
LIVE_DIR=/absolute/path/to/main-checkout make validate
```

To stage a publication locally without committing or pushing:

`make validate` runs native chart generation and stages validated additions in
the checkout named by `LIVE_DIR`; it does not commit or push.

### Making Changes

As a developer making changes to a particular package, you will usually follow the following steps:

#### If this is the first time you are adding a package:

```shell
PACKAGE=<packageName>
mkdir -p packages/${PACKAGE}
touch packages/${PACKAGE}/package.yaml
```

See `packages/README.md` to configure the `packages/${PACKAGE}/package.yaml` file based on the Package that you are planning to add.

To make changes, see the steps listed below.

#### If the package already exists

If you are working with a single Package, set `export PACKAGE=<packageName>` to inform the scripts that you only want to make changes to a particular package.

This will prevent the scripts from running commands on every package in this repository.

You'll also want to update the `packageVersion` in `packages/${PACKAGE}/package.yaml`.

See the section below for how to update this field.

Once you have made those changes, the Workflow will be:
```shell
make prepare # Instantiates the chart in the workingDir specified in the package.yaml
# Make your changes here to the workingDir directly here
make patch # Saves changes to generated-changes/
make clean # Cleans up your workingDir, leaving behind only the generated-changes/
```

Once your directory is clean, you are ready to submit a PR.

#### Versioning Packages

If this upstream Chart version has never been released, reset `packageVersion`
to `01`. Every package must specify an integer package version of at least 1,
including packages marked `doNotRelease`.

If this `major.minor.patch` (e.g. `0.0.1`) version of the Chart has been released before:
- Increment `packageVersion`, and verify that the resulting chart version has
  not already been published with different contents.

### Makefile

#### Basic Commands

`make pull-scripts`: Pulls in the version of the `charts-build-scripts` indicated in scripts.

`make prepare`: Pulls in your charts from upstream and creates a basic `generated-changes/` directory with your dependencies from upstream

`make patch`: Updates your `generated-changes/` to reflect the difference between upstream and the current working directory of your branch (note: this command should only be run after `make prepare`).

`make clean`: Cleans up all the working directories of charts to get your repository ready for a PR

#### Advanced Commands

`make strip`: Runs the Perl description stripper on prepared `rke2-calico-crd-*` packages, removing descriptions that match the whitespace-tolerant regular expressions in `scripts/strip-descriptions.json` without reformatting surviving lines. Matching applies to `description` mapping values regardless of their indentation. Run `make patch` afterward to save the changes.

`bash scripts/test-strip-descriptions.sh`: Checks whitespace- and indentation-independent matching, preservation of unrelated YAML, multiple YAML documents, and idempotence.

`make charts`: Runs the native upstream chart generator. It writes
chart-name-based archives, extracted charts, and an index into the current
checkout; use a clean disposable checkout for generated output.

`make validate`: Runs `make charts`, compares output against `main`, and stages
only new versions into a clean `LIVE_DIR` checkout. Without `LIVE_DIR`, it
clones the configured validation branch. It does not commit or push.
