# Bach

> **Summary**: A modular bash configuration toolkit for developers, offering organized modules for common tasks, logging, and development tools with easy installation.

## Description

Bach provides a lightweight, modular way to manage your bash environment with organized modules for common tasks, logging, development tools, and more.

## Installation

Bach is a Bash toolkit with a Bash CLI. Installing it requires Bash 3.2+ and
standard Unix tools; installation from source also requires `make`. Python,
pip, pipx, and Poetry are not required for installation. Individual helpers
need their underlying tools (Git, Docker, etc.); workspace JSON parsing and a
relative-path fallback use Python when those features are invoked.

### From source or a release archive

```bash
git clone https://github.com/lamnguyenx/bach.git
cd bach
make install PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
bach init --write
```

Alternatively, extract a versioned release tarball and run the same `make
install` command inside it. Installed scripts are copied into the prefix, so
the source checkout or extracted archive can be moved or removed afterward.
Keep your chosen prefix's `bin` directory on your Bash startup `PATH`.

`make install` installs files only. `bach init --write` explicitly adds or
replaces a marked block in `~/.bashrc`, backing up existing content first.
To manage startup yourself, add this after your `PATH` setup:

```bash
eval "$(bach init)"
```

Preview the activation code with `bach init`. For another Bash startup file,
use `bach init --write --rc /path/to/file`.

On macOS, use a Bash shell to load Bach. Bash login shells read
`~/.bash_profile` (or `~/.bash_login` / `~/.profile`), so ensure your chosen
login profile sources `~/.bashrc`. Bash 3.2 supports the CLI and completion;
fzf bindings load only in interactive shells with the fzf helper available.

### Homebrew distribution

A maintainer formula template is provided at [`packaging/bach.rb.in`](packaging/bach.rb.in).
A published tap is not configured yet; see
[`packaging/README.md`](packaging/README.md) for release and tap setup.
Once published, Homebrew can manage installation and upgrades on macOS and Linux.

### Migrating from pip / pipx

Remove the old package with the same tool you used to install it
(`pipx uninstall bach-cli` or `python3 -m pip uninstall bach-cli`), then install
the Bash version above and run `bach init --write` from the new installation.
Uninstall the old package first because its uninstaller may remove the `bach`
command from the same prefix. This replaces the old
managed startup block, including its Python completion hook. Check `command -v bach`
to ensure your chosen prefix is on `PATH`. The old copied scripts under
`~/.local/share/bach` are no longer used; your configuration under
`${XDG_CONFIG_HOME:-$HOME/.config}/bach` is preserved.

## Updating

Install a newer release with the same `PREFIX`, then open a new Bash shell or
run `eval "$(bach init)"` in the current one. A source checkout can be updated
with `git pull --ff-only` before running `make install` again.

For a Homebrew installation, use `brew upgrade <owner>/<tap>/bach`.
`bach update` prints upgrade instructions; your installation method manages
package updates. The startup hook resolves the current `bach` on `PATH`, so
Homebrew upgrades do not leave activation tied to an old version's directory.

## Usage

Open a new Bash shell or run `eval "$(bach init)"` after activation.

- `bach init` — Print shell activation code.
- `bach init --write` — Activate in `~/.bashrc`, with a backup.
- `bach deinit` — Remove the managed activation block.
- `bach reload` — Print activation code to evaluate in the current shell.
- `bach update` — Show upgrade instructions.
- `bach --version` — Show the installed version.

Compatibility aliases: `bach install` activates the shell; `bach uninstall`
and `bach clean` remove activation. File installation/removal uses `make` or
your package manager. Static Bash completion loads in interactive shells.

Available modules:
- `common.sh`: Common utilities
- `logging.sh`: Logging functions
- `docker.sh`: Docker helpers
- `files.sh`: File operations
- `git.sh`: Git utilities
- `homebrew.sh`: Homebrew management
- `terminal.sh`: Terminal setup
- `lastly.sh`: Final configurations

To reload modules in the current shell, run `bach_reload` (`reload_bach` also
works). It re-reads the entry point, modules, and user configuration, and
returns nonzero if a file is missing, has invalid syntax, or fails to load.
Reload failures can leave some definitions updated; fix the reported file and
retry. Removed functions or configuration assignments are not automatically
unset; use a new shell for a clean state.

Reload reads the **installed files**. After editing a source checkout, run
`make install` before reloading. `bach reload` prints activation code because
an executable cannot change its parent shell; evaluate it with
`eval "$(bach reload)"`. That also selects the current installation after a
package-manager upgrade changes its path.

## Configuration

Bach loads optional user configuration from
`${XDG_CONFIG_HOME:-$HOME/.config}/bach/`. Nothing there is tracked by bach.

- `config.sh` — shared settings, loaded for every command.
- `config-<module>.sh` — settings for one module, e.g. `config-git.sh` for
  `git.sh`, `config-docker.sh` for `docker.sh`. Loaded after `config.sh`, so it
  wins on conflicts.

```bash
# ~/.config/bach/config.sh
# Shared defaults for every module (nothing is required here).

# ~/.config/bach/config-git.sh
BACH_JCO_MODEL="
VAI 2/glm-5.3
opencode-go/deepseek-v4.1-flash
"
BACH_JCO_PROMPT_FILE="$HOME/.claude/commands/commit.md"
```

`BACH_JCO_MODEL` may list several models, one per line (a bash array works
too). When more than one is set, `jco`/`jcoa`/`jcop`/`jcoap` show a numbered
menu; non-interactive runs use the first entry. `-m <model>` skips the menu.

Assign values directly rather than using `${VAR:-default}` fallbacks: the file
is re-sourced before each command, and a fallback would keep the value from the
first source, so later edits would not apply. Use the command's own flag (e.g.
`jco -m`) for one-off overrides.

Module commands source their config before reading it, so edits apply to the
next command — no shell restart or `reload_bach` needed. All config files are
also loaded at shell startup so their values are available immediately. Config
files must be idempotent because they are sourced repeatedly. `reload_bach`
still exists and re-sources every config file present.

How config is discovered, layered, and refreshed — including the
`BACH_JCO_MODEL` menu and troubleshooting (stale exported functions, why
`${VAR:-default}` must not be used) — is documented in
[`docs/important/how-config-loading-works.md`](docs/important/how-config-loading-works.md).

`jco` commits the current repository with `opencode run`. `jcoa` commits all
submodules first (deepest first), then the current repository. `jcop` and
`jcoap` do the same and then push:

```bash
jco                        # commit with the configured defaults
jcoa                       # commit submodules first, then the repo
jcop                       # commit, then push
jcoap                      # commit submodules + repo, then push all
jco "also update the docs" # append extra instructions
jco -m "provider/model"    # override the model for this run
```

`jcoa` and `jcoap` are best-effort and resumable: one failing submodule does
not stop the others, failures are listed at the end, and rerunning skips repos
that are already clean or pushed. A parent/root repo is not committed or pushed
while a child submodule is still failing.

## Documentation

- [`docs/important/README.md`](docs/important/README.md) — operational documentation index.
- [`docs/important/how-installation-packaging-and-reload-work.md`](docs/important/how-installation-packaging-and-reload-work.md) — installation versus activation, old-path migration, reload troubleshooting, release assets, and removal.
- [`docs/important/how-config-loading-works.md`](docs/important/how-config-loading-works.md) — user config layout (`config.sh` + `config-<module>.sh`), when files are (re-)sourced, config rules, and `jco` model selection; read before touching config or `jco*`
- [`docs/important/how-test-test-audio.md`](docs/important/how-test-test-audio.md) — manual end-to-end test of `mic_forward`
- [`docs/important/how-test-test-video.md`](docs/important/how-test-test-video.md) — manual end-to-end test of video forwarding
- [`2026-11-10 packaging migration`](docs/plans/2026/11/10/2026-11-10-shell-packaging-and-release-migration.md) — every touched component, trials/errors, local activation repair, verification, and publication status.
- [`2026-11-10 reload fixes`](docs/plans/2026/11/10/2026-11-10-reliable-bash-reload.md) — reproduced failures, same-shell reload changes, tests, and lessons.
- `docs/plans/` — dated work logs (decisions, trials, errors, lessons)

## Linting

To check shellscripts, install `shellcheck` and run `shellcheck --severity=error <input_file>`.

For VSCode users, install the Bash IDE extension (`mads-hartmann.bash-ide-vscode`) and add the following to your settings.json:

```json
"bashIde.shellcheckArguments": "--severity=warning"
```

## Uninstallation

Remove activation before removing the installed command:

```bash
bach deinit
make uninstall PREFIX="$HOME/.local"
```

`make clean` remains an alias for `make uninstall`. For a Homebrew install,
run `bach deinit` followed by `brew uninstall <owner>/<tap>/bach`.
User configuration is preserved. Removing activation takes effect in new
shells; functions already loaded remain in the current shell.

`setup.sh` remains a compatibility wrapper around installation and activation.

## Structure

- `bin/bach`: Bash CLI for activation and installation guidance.
- `lib/bach/`: Shell modules, entry point, and Bash completion.
- `VERSION`: Release version shared by the CLI and release tooling.
- `Makefile`: Installation, uninstallation, tests, and release archive targets.
- `scripts/dist.sh`: Release tarball and SHA-256 checksum creation.
- `packaging/`: Homebrew formula template and release instructions.
- `bach_lite.sh`: Standalone lightweight utility script.

Run `make test` for installation and shell tests, or `make dist` to build a
release archive, checksum, and ready-to-use Homebrew formula. Pushing a matching
`v<VERSION>` tag runs Linux/macOS tests and prepares a draft GitHub release;
see [`packaging/README.md`](packaging/README.md) for the publishing steps.
