pull-scripts:
	./scripts/pull-scripts

TARGETS := prepare patch charts clean sync validate rebase docs

$(TARGETS):
	@ls ./bin/charts-build-scripts 1>/dev/null 2>/dev/null || ./scripts/pull-scripts
	./bin/charts-build-scripts $@

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
	./scripts/strip-descriptions.sh "$$templates"

.PHONY: $(TARGETS) strip