.PHONY: help all install clean
.DEFAULT_GOAL := help

help:
	@bash ./bach_lite.sh echo_banner "Bach Installation" "=" 60
	@echo "Run 'make install' to install bach configuration"
	@echo "Or run 'make all' to install bach configuration"
	@echo "Run 'make clean' to remove symlinks and create empty config directories"
	@echo ""
	@echo "WARNING: Do NOT move this directory. All configs use symlinks that will break if this folder is relocated."

all: install

clean:
	@echo "Removing bach configuration..."
	@bash ./setup.sh uninstall
	@echo "Cleaned symlinks and created empty config directories"

install:
	@bash ./bach_lite.sh echo_banner "Installing Bach" "=" 60 && \
	bash ./setup.sh
