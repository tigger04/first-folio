INSTALL_DIR := $(HOME)/.local/bin
PROJECT_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)

.PHONY: install uninstall test test-one-off lint sync

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
