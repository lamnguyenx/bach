# Installation, packaging, activation, and reload

This is the operational reference for Bach's Bash distribution. Configuration
layering and jco model selection are covered in
[how-config-loading-works.md](how-config-loading-works.md).

## File ownership and layout

| Location | Purpose |
| --- | --- |
| Checkout `bin/bach` | Bash CLI; also works directly from the source tree. |
| Checkout `lib/bach/init.sh` | Loader and same-shell reload functions. |
| Checkout `lib/bach/*.sh` | Internal core, application, terminal, and optional fzf modules. |
| Checkout `lib/bach/completion.bash` | Static interactive Bash completion. |
| `<PREFIX>/bin/bach` | Installed CLI. |
| `<PREFIX>/lib/bach/` | Installed modules, completion, and VERSION. |
| `${XDG_CONFIG_HOME:-$HOME/.config}/bach/` | User-owned settings; preserved by uninstall. |
| `~/.bashrc` | Optional managed activation block, separate from package files. |

Installation needs Bash and Unix tools, with `make` for the supplied installer.
Python packaging is gone. Optional workspace parsing and relative-path helper
features may still need Python. The CLI/loader target Bash 3.2+ on Linux and
macOS; local verification in this session was Linux only.

All former `bach_cli/bach/*.sh` modules now live under `lib/bach/`; the old
`__init__.sh` is now `init.sh`. These shell files are not Git submodules.
The root `bach_lite.sh` remains standalone. The former Python package and its
bundled duplicate have been removed.

## Install files, then activate Bash

```bash
make install PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
bach init --write
eval "$(bach init)"
```

Keep the prefix's `bin` directory on PATH in future shells. `make install`
only copies files: it does not edit startup files or refresh loaded functions.
`bach init --write` backs up the selected startup file, removes/replaces its
marked Bach block, and appends activation. Use `--rc /path/to/file` for another
startup file. Existing symlinks and permissions are preserved. Unmatched or
nested marker pairs are rejected rather than guessed at.

For manually managed startup files, add `eval "$(bach init)"` after setting
PATH. The managed block uses the executable on PATH, so new shells select the
current installation rather than an old Homebrew Cellar version.

Bach is for Bash. On macOS, ensure the Bash login profile you actually use
sources `~/.bashrc`. Static completion loads only in interactive sessions;
fzf bindings additionally require the `__fzfcmd` integration helper.

### Migrate from older versions

For a pip/pipx installation, uninstall `bach-cli` with its original tool first,
then install the Bash version. The old uninstaller may remove `bin/bach`, so
reversing that order can delete the replacement command. Run `bach init --write`
to remove the Python completion hook and old managed source path. The copied
`~/.local/share/bach` tree is no longer used; user configuration is preserved.

For the old source-linked installer, the typical failure is:

```text
bash: .../bach_cli/bach/__init__.sh: No such file or directory
```

Copying the new files alone leaves that startup block unchanged. Repair it with:

```bash
"$HOME/.local/bin/bach" init --write
source "$HOME/.bashrc"
```

Use your actual prefix if different. If the error remains, inspect
`type -a bach` and `grep -n 'bach' ~/.bashrc` for a second unmanaged source line;
the installer only owns its marked block. Avoid defining Bach functions again
after activation in the startup file.

## Refresh the current shell

| Action | Effect |
| --- | --- |
| `make install` | Replace files in the chosen prefix. |
| `bach init --write` | Repair/update the managed startup block. |
| `eval "$(bach init)"` | Load the installation selected by the current CLI. |
| `bach_reload` or `reload_bach` | Re-source the recorded absolute entry file, modules, and configuration in this shell. |
| `bach reload` | Print activation code; evaluate it as `eval "$(bach reload)"`. |
| New Bash shell | Read startup configuration with a fresh shell state, subject to inherited exports. |

After checkout edits, install with the same prefix, then reload. A terminal
holding the old loader needs `eval "$(bach init)"` once to get the new reload
implementation. When a package-manager upgrade changes the installation path,
use `eval "$(bach reload)"` to select the current package.

Reload validates the entry file, module syntax/readability, and config syntax.
A failed load reports the file, returns nonzero, and does not print success.
Fix the reported file and retry. The process is not transactional: runtime
failures may leave partially updated definitions, and successful sourcing only
reports the script's final status, not every intermediate command's status.
Removed assignments/functions are not automatically unset. For a clean state,
start a new shell and check for stale exported functions or startup overrides.

## Uninstall

```bash
bach deinit
make uninstall PREFIX="$HOME/.local"
```

Deactivate before removing the executable. `make clean` aliases file removal;
`bach uninstall` and `bach clean` alias deactivation. Neither operation removes
user configuration. Loaded functions remain in an already-open shell.
`setup.sh` is a compatibility wrapper that combines installation/activation or
deactivation/file removal.

## Release assets and validation

See [packaging/README.md](../../packaging/README.md) for the release/tap process.
`make dist` generates an archive, checksum, and matching Homebrew formula under
`dist/`. Keep those artifacts together: rebuilding an archive can change its
checksum. The `v<VERSION>` workflow runs Linux/macOS tests before preparing a
**draft** release. No tap is configured or advertised as published yet.

`make test` includes reload, packaging, cross-platform, configuration, Git
copy, and common-function suites. See [test/README.md](../../test/README.md)
for coverage. Audio/video forwarding still requires the manual guides and
real devices/hosts; those tests were not run during this packaging migration.

Session records:

- [Shell packaging, release preparation, and startup migration](../plans/2026/11/10/2026-11-10-shell-packaging-and-release-migration.md)
- [Reliable same-shell reload](../plans/2026/11/10/2026-11-10-reliable-bash-reload.md)
