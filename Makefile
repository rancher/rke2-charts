pull-scripts:
	./scripts/pull-scripts

TARGETS := prepare patch clean clean-cache list index

# The builder removes sparse-clone .git directories immediately after checkout.
# Wait for Git's automatic maintenance to finish before that cleanup.
define configure-git-maintenance
	count=$${GIT_CONFIG_COUNT:-0}; \
	case "$$count" in *[!0-9]*) echo "error: GIT_CONFIG_COUNT must be a non-negative integer" >&2; exit 1 ;; esac; \
	while [ "$${count#0}" != "$$count" ] && [ "$$count" != 0 ]; do count=$${count#0}; done; \
	export "GIT_CONFIG_KEY_$$count=maintenance.autoDetach" "GIT_CONFIG_VALUE_$$count=false"; \
	export GIT_CONFIG_COUNT=$$((count + 1));
endef

prepare patch: check-package-versions

check-package-versions:
	bash ./scripts/check-package-versions

$(TARGETS):
	@$(configure-git-maintenance) \
	./bin/charts-build-scripts $@

$(TARGETS) charts: pull-scripts

# CHARTS_BASE_REF limits native generation to packages changed since this source commit.
# CI sets it to the PR base or last published source commit; leave unset to build all packages.
# TODO: Remove obsolete legacy chart packages from main-source once their source definitions are no longer needed.
charts:
	@$(configure-git-maintenance) \
	if [ -n "$$CHARTS_BASE_REF" ]; then \
		bash ./scripts/generate-changed-charts "$$CHARTS_BASE_REF"; \
	else \
		./bin/charts-build-scripts charts --config configuration.yaml; \
	fi

validate: charts
	bash ./scripts/validate-charts . "$${LIVE_DIR:-}"

clean-charts:
	bash -c 'rm -rf ./assets ./charts ./index.yaml'

strip:
	@case "$$PACKAGE" in \
		rke2-calico-crd-?*) ;; \
		*) echo "error: PACKAGE must match rke2-calico-crd-*" >&2; exit 1 ;; \
	esac; \
	case "$$PACKAGE" in \
		*[!a-zA-Z0-9._-]*) echo "error: PACKAGE must be a package name, not a path" >&2; exit 1 ;; \
	esac; \
	templates="packages/$$PACKAGE/charts/templates"; \
	if [ ! -d "$$templates" ]; then \
		echo "error: $$templates does not exist; run PACKAGE=$$PACKAGE make prepare first" >&2; \
		exit 1; \
	fi; \
	perl ./scripts/strip-descriptions.pl "$$templates"

.PHONY: pull-scripts check-package-versions $(TARGETS) charts validate strip