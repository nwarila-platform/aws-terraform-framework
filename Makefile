PYTHON ?= python3
TFLINT ?= tflint

# The deny-all guard scans the whole repository. Only rooted, known runtime/scratch artifacts are
# excluded: Terraform's local cache/state, Python bytecode caches, and the handoff workspace.
GUARD_EXCLUDE := ^(_handoff/|(terraform|overlays)/\.terraform/|(terraform|overlays)/terraform\.tfstate(\.backup)?$$|(terraform|overlays)/\.terraform\.tfstate\.lock\.info$$|([^/]+/)*__pycache__/|([^/]+/)*[^/]+\.py[co]$$)

.PHONY: fmt fmt-check init validate test docs docs-diff docs-check allowlist-check tflint \
	overlay-check alias-contract-check ci

# Mutating: rewrites HCL in place. Use locally before committing.
fmt:
	terraform -chdir=terraform fmt -recursive
	terraform -chdir=overlays fmt -recursive

# Non-mutating: fails if any file would change. Use in CI.
fmt-check:
	terraform -chdir=terraform fmt -check -recursive
	terraform -chdir=overlays fmt -check -recursive

init:
	terraform -chdir=terraform init -backend=false -input=false
	terraform -chdir=overlays init -backend=false -input=false

validate:
	terraform -chdir=terraform validate
	terraform -chdir=overlays validate

test:
	terraform -chdir=terraform test
	terraform -chdir=overlays test

# Mutating: regenerates the injected blocks in both Terraform reference pages.
docs:
	terraform-docs --config .terraform-docs.yml terraform
	terraform-docs --config .terraform-docs.overlays.yml overlays

# Non-mutating: fails if either generated reference page is out of sync with its root.
docs-diff:
	terraform-docs --config .terraform-docs.yml --output-check terraform
	terraform-docs --config .terraform-docs.overlays.yml --output-check overlays

docs-check:
	$(PYTHON) tools/check_docs_layout.py

# Bidirectional deny-all allowlist guard. The forward half catches deliverable files that exist on
# disk but git would silently omit; the reverse half catches stale unignore entries after a path is
# renamed or deleted.
allowlist-check:
	@ignored=$$(git ls-files --others --ignored --exclude-standard -- . 2>/dev/null \
	  | grep -vE '$(GUARD_EXCLUDE)' || true); \
	if [ -n "$$ignored" ]; then \
	  printf 'ERROR: repository files are NOT allowlisted in .gitignore:\n'; \
	  printf '%s\n' "$$ignored" | sed 's/^/  /'; \
	  printf 'Add an explicit "!/<path>" line to .gitignore, or remove the non-deliverable artifact.\n'; \
	  exit 1; \
	else \
	  printf 'allowlist-check: OK — every repository file is explicitly allowlisted\n'; \
	fi
	@# Root-level core-file rules intentionally use !name syntax; this reverse check polices rooted
	@# !/ entries only.
	@orphans=$$(grep '^!/' .gitignore | sed 's|^!/||; s|/\*\*$$||' | while read -r p; do \
	  case "$$p" in \
	    */) git ls-files --cached --others --exclude-standard -- "$${p%/}" | grep -q . \
	          || echo "$$p" ;; \
	    *)  git ls-files --error-unmatch "$$p" >/dev/null 2>&1 || echo "$$p" ;; \
	  esac; \
	done); \
	if [ -n "$$orphans" ]; then \
	  printf 'ERROR: .gitignore allowlists paths not in the tracked set:\n'; \
	  printf '%s\n' "$$orphans" | sed 's|^|  !/|'; \
	  exit 1; \
	else \
	  printf 'allowlist-check: OK — every rooted allowlist entry resolves\n'; \
	fi

tflint:
	$(TFLINT) --config "$(CURDIR)/.tflint.hcl" --chdir terraform
	$(TFLINT) --config "$(CURDIR)/.tflint.hcl" --chdir overlays

overlay-check:
	tools/check_overlay_plan.sh

alias-contract-check:
	tools/check_alias_file.sh --self-test

ci:
	$(MAKE) fmt-check
	$(MAKE) init
	$(MAKE) validate
	$(MAKE) test
	$(MAKE) tflint
	$(MAKE) overlay-check
	$(MAKE) alias-contract-check
	$(MAKE) docs-diff
	$(MAKE) docs-check
	$(MAKE) allowlist-check
