.PHONY: help all install uninstall clean dist test
.DEFAULT_GOAL := help

PREFIX ?= $(HOME)/.local
DESTDIR ?=
BASH ?= bash

help:
	@echo 'make install [PREFIX=$$HOME/.local] [DESTDIR=staging]'
	@echo 'make uninstall [PREFIX=$$HOME/.local] [DESTDIR=staging]'
	@echo 'make dist       Create a release archive, checksum, and Homebrew formula'
	@echo 'make test       Run shell and installation tests'
	@echo 'Activate after installation: bach init --write'

all: install

install:
	install -d "$(DESTDIR)$(PREFIX)/bin" "$(DESTDIR)$(PREFIX)/lib/bach"
	install -m 755 bin/bach "$(DESTDIR)$(PREFIX)/bin/bach"
	install -m 644 lib/bach/*.sh lib/bach/*.bash VERSION "$(DESTDIR)$(PREFIX)/lib/bach/"
	@echo 'Installed Bach files. Add PREFIX/bin to PATH, then run bach init --write.'

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/bach"
	rm -rf "$(DESTDIR)$(PREFIX)/lib/bach"
	@echo 'Removed Bach files. User configuration is preserved.'

# Compatibility alias for the previous uninstall target.
clean: uninstall

dist:
	"$(BASH)" scripts/dist.sh

test:
	"$(BASH)" test/test_reload.sh
	"$(BASH)" test/test_packaging.sh
	"$(BASH)" test/test_cross_platform.sh
	"$(BASH)" test/test_config.sh
	"$(BASH)" test/test_git_copy_clean.sh
	"$(BASH)" test/test_common.sh
