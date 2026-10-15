EMACS ?= emacs

RUNTIME_SOURCES = dired-eza-colors.el dired-eza-classify.el \
	dired-eza-permissions.el dired-eza-size.el dired-eza-metadata.el dired-eza.el
BATCH = "$(EMACS)" --batch -Q -L .

.PHONY: test compile check clean
.DEFAULT_GOAL := test

# Loads source or compiled runtime modules, according to what is present.
test:
	$(BATCH) --eval '(setq load-prefer-newer t)' -L test -l dired-eza-test -f ert-run-tests-batch-and-exit

compile:
	$(BATCH) --eval '(setq load-prefer-newer t byte-compile-error-on-warn t)' -f batch-byte-compile $(RUNTIME_SOURCES)

# Keep phases sequential, including when the caller uses parallel make.
check:
	$(MAKE) clean
	$(MAKE) test
	$(MAKE) compile
	$(MAKE) test
	$(MAKE) clean

# Remove only compiled counterparts of this package's runtime modules.
clean:
	$(RM) $(RUNTIME_SOURCES:.el=.elc)
