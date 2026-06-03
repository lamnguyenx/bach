# Bach

> **Summary**: A modular bash configuration toolkit for developers, offering organized modules for common tasks, logging, and development tools with easy installation.

> **⚠️ WARNING:** Do NOT move this directory after installation. The configuration sources files using absolute paths that will break if relocated.

## Description

Bach provides a lightweight, modular way to manage your bash environment with organized modules for common tasks, logging, development tools, and more.

## Installation

### Python (Recommended)

```bash
pip install bach-cli
# or with pipx (preferred for CLI tools)
pipx install bach-cli

bach install
```

This will add the bach initialization to your `~/.bashrc`.

### From source

1. Clone the repository:

```bash
git clone <repo-url>
cd bach
```

2. Install the configuration:

```bash
make install
```

This will add the bach initialization to your `~/.bashrc`.

## Updating

When a new version is released, run:

```bash
bach update
```

This upgrades the package (via `pip` or `pipx`) and reinstalls the shell scripts in one step.

Or manually:

```bash
pip install --upgrade bach-cli
# or with pipx
pipx upgrade bach-cli

bach install
```

## Usage

After installation, restart your shell or run `source ~/.bashrc` to load the configuration.

Available commands:
- `bach install` — Install bach configuration (with shell completion)
- `bach uninstall` — Remove bach configuration
- `bach update` — Upgrade package and reinstall configuration
- `bach reload` — Show how to reload configuration in current shell
- `bach clean` — Alias for uninstall

**Shell completion** (bash) is automatically enabled during `bach install`. It requires bash 4.4+ — if you're on macOS with the default bash 3.2, install a newer bash via `brew install bash` to use completions.

Available modules:
- `common.sh`: Common utilities
- `logging.sh`: Logging functions
- `docker.sh`: Docker helpers
- `files.sh`: File operations
- `git.sh`: Git utilities
- `homebrew.sh`: Homebrew management
- `terminal.sh`: Terminal setup
- `lastly.sh`: Final configurations

To reload modules in the current shell: `reload_bash` or `source ~/.bashrc`

## Linting

To check shellscripts, install `shellcheck` and run `shellcheck --severity=error <input_file>`.

For VSCode users, install the Bash IDE extension (`mads-hartmann.bash-ide-vscode`) and add the following to your settings.json:

```json
"bashIde.shellcheckArguments": "--severity=warning"
```

## Uninstallation

### Python

```bash
bach uninstall
```

### From source

```bash
make clean
```

Or manually: `bash setup.sh uninstall`

## Structure

- `bach_cli/`: Python package (CLI entry point)
- `src/bach/`: Module files (shell scripts)
- `setup.sh`: Installation script (legacy)
- `bach_lite.sh`: Lightweight utility script
- `Makefile`: Build/install targets (legacy)
- `pyproject.toml`: Poetry / Python packaging configuration

