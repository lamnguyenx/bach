# Bach

A modular bash configuration toolkit for developers.

> **⚠️ WARNING:** Do NOT move this directory after installation. The configuration sources files using absolute paths that will break if relocated.

## Description

Bach provides a lightweight, modular way to manage your bash environment with organized modules for common tasks, logging, development tools, and more.

## Installation

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

## Usage

After installation, restart your shell or run `source ~/.bashrc` to load the configuration.

Available modules:
- `common.sh`: Common utilities
- `logging.sh`: Logging functions
- `docker.sh`: Docker helpers
- `files.sh`: File operations
- `git.sh`: Git utilities
- `homebrew.sh`: Homebrew management
- `terminal.sh`: Terminal setup
- `lastly.sh`: Final configurations

To reload modules: `reload_bach`

## Linting

To check shellscripts, install `shellcheck` and run `shellcheck --severity=error <input_file>`.

For VSCode users, install the Bash IDE extension (`mads-hartmann.bash-ide-vscode`) and add the following to your settings.json:

```json
"bashIde.shellcheckArguments": "--severity=warning"
```

## Uninstallation

```bash
make clean
```

Or manually: `bash setup.sh uninstall`

## Structure

- `src/bach/`: Module files
- `setup.sh`: Installation script
- `bach_lite.sh`: Lightweight utility script
- `Makefile`: Build/install targets

