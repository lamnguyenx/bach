# bax - Modularized Bash Configuration

A modularized bash configuration system for development environments, providing organized utilities and tools for efficient command-line workflows.

## Structure

- `__init__.sh` - Main initialization script that sources all modules
- `common.sh` - Consolidated common utilities (essentials, args, proxies, misc, projects)
- `logging.sh` - ANSI color functions and logging utilities
- `terminal.sh` - Terminal setup and prompt configuration
- `docker.sh` - Docker-related aliases and functions
- `git.sh` - Git utilities and submodule navigation
- `homebrew.sh` - Homebrew environment management

## Features

### Core Utilities (common.sh)
- **Essentials**: Environment variables, host IP detection, path setup
- **Args**: Advanced argument parsing with dry-run and config support
- **Proxies**: Proxy management functions for network configurations
- **Misc**: Various utilities like tensorboard launcher, file renaming, aliases
- **Projects**: Automatic sourcing of project-specific configurations

### Logging & Terminal
- Colorized output functions (`log_green`, `log_red`, etc.)
- Hierarchical logging with process levels
- Custom PS1 prompt with git branch and project information

### Docker Tools
- Container management aliases (`dc`, `enter`)
- Hot reload functions for development
- Docker image tagging and transfer utilities

### Git Tools
- Submodule navigation system (`gl` command)
- Bulk commit/push functions for repositories and submodules
- Large object detection and submodule management

### Homebrew Integration
- Environment switching between conda and homebrew

## Usage

The bax system is automatically loaded when sourcing the main `__init__.sh` file. All functions and aliases become available in your bash session.

### Reload Configuration
```bash
reload_bax
```

### Key Commands
- `gl` - Git submodule navigation
- `dc_replace_tag` - Docker image tagging
- `just_commit_all` - Bulk git operations
- `set_legacy_proxy` - Proxy configuration

## Configuration

Project-specific configurations can be added via:
- `.project.sh` - Tracked project configuration
- `.project-untracked.sh` - Untracked local configuration

These files are automatically sourced if present in the current directory.

## Module Dependencies & Reuse

Later-sourced modules extensively reuse functions from earlier modules, following a dependency hierarchy:

**Sourcing Order:**
1. `common.sh` (essentials, args, proxies, misc, projects)
2. `logging.sh`
3. `docker.sh`
4. `git.sh`
5. `homebrew.sh`
6. `terminal.sh`

**Reuse Patterns:**

- **`terminal.sh`** → **`common.sh` & `logging.sh`**
  - Uses `get_host_ip()` for host detection
  - Uses ANSI color variables (`$ANSIFmt__*`) for prompt styling
  - Uses `echo_*` color functions for formatted output

- **`docker.sh`** → **`common.sh` & `logging.sh`**
  - Uses `parse_args()` for advanced argument processing
  - Uses logging functions (`log`, `log_green`, `log_red`) for status messages
  - Uses `print_proxy()` for proxy status display

- **`git.sh`** → **`logging.sh`**
  - Uses `log_error()` for error messages
  - Uses `log_green()` for success confirmations
  - Uses `log()` for informational messages
  - All emojis preserved with enhanced color coding

- **`homebrew.sh`** → Self-contained (no external dependencies)

This design ensures utilities are defined early in the load order and reused by application-specific modules, promoting code reuse and maintainability.

## Development

The modular structure allows for easy extension and maintenance. Each module focuses on a specific domain while sharing common utilities through the logging and common modules.