.PHONY: help all helix tmux termux lazygit amp opencode bax yazi tmux-powerline firefox clean

help:
	@echo "Configuration Setup"
	@echo "=================="
	@echo ""
	@echo "Run 'make <amp|opencode|tmux|helix|termux|lazygit|bax|yazi|tmux-powerline|firefox>' to install specific config"
	@echo "Or run 'make all' to install all configurations"
	@echo "Run 'make clean' to remove symlinks and create empty config directories"
	@echo ""
	@echo "WARNING: Do NOT move this directory. All configs use symlinks that will break if this folder is relocated."
	@echo ""

all: helix tmux termux lazygit amp opencode bax yazi tmux-powerline firefox

clean:
	@rm -f ~/.config/helix
	@mkdir -p ~/.config/helix
	@rm -f ~/.config/tmux
	@rm -f ~/.tmux.conf
	@mkdir -p ~/.config/tmux
	@rm -f ~/.config/lazygit
	@mkdir -p ~/.config/lazygit
	@rm -f ~/.config/yazi
	@mkdir -p ~/.config/yazi
	@rm -f ~/.config/tmux-powerline
	@mkdir -p ~/.config/tmux-powerline
	@echo "Cleaned symlinks and created empty config directories"

helix:
	@bash ./local/archive.sh ~/.config/helix
	@ln -sf "$(shell pwd)/dot-config/helix" ~/.config/helix
	@bash ./local/echo_banner.sh "Helix"
	@echo "Symlinks:"
	@bash ./local/show_symlinks.sh ~/.config/helix

tmux:
	@bash ./local/archive.sh ~/.config/tmux
	@bash ./local/archive.sh ~/.tmux.conf
	@ln -sf "$(shell pwd)/dot-config/tmux" ~/.config/tmux
	@ln -sf "$(shell pwd)/dot-config/tmux/tmux.conf" ~/.tmux.conf
	@bash ./local/echo_banner.sh "Tmux"
	@echo "Symlinks:"
	@bash ./local/show_symlinks.sh ~/.config/tmux ~/.tmux.conf
	@-tmux source-file ~/.tmux.conf 2>/dev/null || true

termux:
	@bash ./local/archive.sh ~/.termux
	@ln -sf "$(shell pwd)/dot-termux" ~/.termux
	@bash ./local/echo_banner.sh "Termux"
	@echo "Symlinks:"
	@bash ./local/show_symlinks.sh ~/.termux

lazygit:
	@mkdir -p "$(shell lazygit --print-config-dir)"
	@ln -sf "$(shell pwd)/dot-config/lazygit/config.yml" "$(shell lazygit --print-config-dir)/config.yml"
	@bash ./local/echo_banner.sh "Lazygit"
	@echo "Symlinks:"
	@ls -la "$(shell lazygit --print-config-dir)/config.yml"

amp:
	@bash ./local/archive.sh ~/.config/amp
	@mkdir -p ~/.config/amp
	@ln -sf "$(shell pwd)/__submodules__/humanlayer2/.claude/commands" ~/.config/amp/commands
	@bash ./local/echo_banner.sh "Amp"
	@echo "Symlinks:"
	@bash ./local/show_symlinks.sh ~/.config/amp

opencode:
	@bash ./local/archive.sh ~/.config/opencode/command
	@mkdir -p ~/.config/opencode
	@ln -sf "$(shell pwd)/__submodules__/humanlayer2/.claude/commands" ~/.config/opencode/command
	@bash ./local/echo_banner.sh "OpenCode"
	@echo "Symlinks:"
	@bash ./local/show_symlinks.sh ~/.config/opencode/command

yazi:
	@bash ./local/archive.sh ~/.config/yazi
	@ln -sf "$(shell pwd)/dot-config/yazi" ~/.config/yazi
	@bash ./local/echo_banner.sh "Yazi"
	@echo "Symlinks:"
	@bash ./local/show_symlinks.sh ~/.config/yazi

tmux-powerline:
	@bash ./local/archive.sh ~/.config/tmux-powerline
	@ln -sf "$(shell pwd)/dot-config/tmux-powerline" ~/.config/tmux-powerline
	@bash ./local/echo_banner.sh "Tmux Powerline"
	@echo "Symlinks:"
	@bash ./local/show_symlinks.sh ~/.config/tmux-powerline

firefox:
	@bash ./local/install_firefox_custom_css.sh "$(shell pwd)/dot-config/firefox/chrome/userChrome.css"

bax:
	@bash ./local/install_bax.sh
