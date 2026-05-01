INSTALL_DIR := $(HOME)/.local/bin
PROJECT_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)

CURRENT_VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
RELEASE_VERSION ?= $(shell echo "$(CURRENT_VERSION)" | awk -F. '{printf "%s.%s.%d", $$1, $$2, $$3+1}')

.PHONY: install uninstall test test-one-off lint sync release

install:
	@ln -sf "$(PROJECT_DIR)/bin/folio" "$(INSTALL_DIR)/folio"
	@echo "Linked folio -> $(INSTALL_DIR)/folio"

uninstall:
	@rm -f "$(INSTALL_DIR)/folio"
	@echo "Removed $(INSTALL_DIR)/folio"

lint:
	@echo "Perl syntax check..."
	@fail=0; \
	for f in bin/folio lib/Folio/*.pm lib/Folio/*/*.pm lib/OrgPlay/*.pm; do \
		if ! perl -Ilib -c "$$f" 2>/dev/null; then \
			echo "FAIL: $$f"; fail=1; \
		fi; \
	done; \
	if [ "$$fail" -eq 1 ]; then exit 1; fi
	@echo "All files pass syntax check."

test: lint
	@for t in tests/regression/test_*.sh; do \
		echo ""; \
		echo ">>> Running $$t"; \
		bash "$$t" || exit 1; \
	done

ifdef ISSUE
test-one-off:
	@bash tests/one_off/test_*$(ISSUE)*.sh
else
test-one-off:
	@echo "No one-off tests defined yet"
endif

sync:
	@git add --all
	@git commit -m "sync: $$(date +%Y-%m-%d)" || true
	@git pull --rebase
	@git push

release:
ifndef SKIP_TESTS
	@echo "Running tests..."
	$(MAKE) test
endif
	@echo ""
	@echo "Creating release $(RELEASE_VERSION) (current: $(CURRENT_VERSION))..."
	@echo ""
	@echo "Stamping version..."
	@perl -pi -e "s/VERSION = '[^']*'/VERSION = '$(RELEASE_VERSION)'/" bin/folio
	@git add -A
	@git commit -m "release: $(RELEASE_VERSION)" || true
	@git tag -a "$(RELEASE_VERSION)" -m "$(RELEASE_VERSION)"
	@git push
	@git push --tags
	@echo ""
	@echo "Updating Homebrew formula..."
	@bash scripts/update-homebrew.sh "$(shell echo $(RELEASE_VERSION) | sed 's/^v//')"
	@echo ""
	@echo "Done. Tagged $(RELEASE_VERSION)."
