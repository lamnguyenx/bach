.PHONY: help all bax clean
.DEFAULT_GOAL := help

help:
	@bash ./bax_lite.sh echo_banner "Bax Installation" "=" 60
	@echo "Run 'make bax' to install bax configuration"
	@echo "Or run 'make all' to install bax configuration"
	@echo "Run 'make clean' to remove symlinks and create empty config directories"
	@echo ""
	@echo "WARNING: Do NOT move this directory. All configs use symlinks that will break if this folder is relocated."

all: bax

clean:
	@echo "Removing bax configuration..."
	@bash ./setup.sh uninstall
	@echo "Cleaned symlinks and created empty config directories"

bax:
	@bash ./bax_lite.sh echo_banner "Installing Bax" "=" 60 && \
	bash ./setup.sh
