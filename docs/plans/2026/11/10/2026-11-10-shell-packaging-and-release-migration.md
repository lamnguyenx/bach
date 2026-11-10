# Work log: shell packaging, release preparation, and startup migration

Date: 2026-11-10
Status: implemented and tested locally on Linux; installed locally; uncommitted.
Publishing status: no tag, GitHub release, or Homebrew tap was published.

## Scope: parent project and every touched module

Bach is the only repository/module root touched in this session. Both
`git submodule status` and the tracked Git gitlink inventory were empty: there
are no Git submodules to update. The shell modules below are internal files,
not separate repositories with their own README or documentation roots.

| Component | Work completed |
| --- | --- |
| Parent Bach project | Replaced Python distribution with a Bash CLI, prefix installation, release assets, and documentation. |
| CLI (`bin/bach`) | Added activation, deactivation, reload-code output, version, upgrade guidance, and legacy command aliases. |
| Loader (`lib/bach/init.sh`) | Moved from `bach_cli/bach/__init__.sh`; changed loading and reload behavior, covered by the separate reload work log. |
| Completion (`lib/bach/completion.bash`) | Added static completion; no Click or Python startup hook. |
| `android.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `apis.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `audio.sh` | Relocated unchanged; updated its manual test guide's source path. |
| `cdp.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `code-server.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `common.sh` | Relocated unchanged; corrected the test that accidentally invoked privileged firewall commands. |
| `display.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `docker.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `files.sh` | Relocated unchanged; its optional Python relative-path fallback remains. |
| `fzf_tools.sh` | Relocated unchanged; the loader now gates it on interactive Bash plus available fzf integration. |
| `git.sh` | Relocated unchanged; existing config/model behavior retained, including Python-based workspace parsing. |
| `homebrew.sh` | Relocated unchanged; this helper module is distinct from the new distribution formula. |
| `lastly.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `logging.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `ssh.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `terminal.sh` | Relocated to `lib/bach/`; contents unchanged. |
| `video.sh` | Relocated unchanged; updated its manual test guide's source paths. |
| `vscode.sh` | Relocated to `lib/bach/`; contents unchanged. |
| Build/install (`Makefile`, `setup.sh`, `.gitignore`, `VERSION`) | Added prefix/staging support, kept a compatibility setup wrapper, unignored the source `lib/` tree, and centralized version `2026.11.10`. |
| Packaging (`scripts/dist.sh`, `packaging/`) | Added archive/checksum/formula generation and maintainer instructions. |
| CI (`.github/workflows/`) | Added shared Linux/macOS tests and tag-triggered draft-release preparation. |
| Tests (`test/`) | Updated moved source paths; added packaging and reload suites and their README entries. |
| Python package | Removed `bach_cli/*.py`, bundled duplicate `bach_lite.sh`, `pyproject.toml`, and `poetry.lock`; kept the standalone root `bach_lite.sh`. |

The 18 non-loader shell modules were compared byte-for-byte with their old
tracked paths and confirmed unchanged. Earlier jco/config work is recorded in
[the existing configuration work log](2026-11-10-per-module-config-and-jco-model-selection.md);
it was not reimplemented in this session.

## Decisions and resulting behavior

The original runtime was already Bash, but installation and updates were
implemented in Python/Click and scripts were copied into
`~/.local/share/bach`. The wrapper then synchronized those copies. We removed
that extra distribution layer instead of continuing to recommend pip/pipx.
This does not make every optional helper independent of Python: workspace JSON
parsing and a relative-path fallback still invoke it when used.

`make install PREFIX="$HOME/.local"` installs `bin/bach` and `lib/bach/*`.
`DESTDIR` supports downstream staging without becoming an embedded runtime
path. The source checkout may be moved after installation. File installation
and shell activation are separate: `bach init --write` backs up and rewrites
only the marked block in the selected Bash startup file. `bach init` prints
activation for users managing their own startup files.

The managed block resolves `bach` on PATH and evaluates its activation code.
This avoids binding normal shell startup to a removed Homebrew version path.
The CLI resolves relative and absolute executable symlinks without GNU-only
`readlink -f`. Existing startup-file symlinks and permissions are preserved;
malformed Bach marker pairs are rejected. Package managers own upgrades;
`bach update` prints instructions rather than invoking pip or updating itself.

`make dist` creates an archive, SHA-256 checksum, and concrete `bach.rb` with
the checksum of that exact archive. `BACH_RELEASE_REPOSITORY` supports forks
and is validated as owner/repository. Available `LICENSE*`/`COPYING*` files are
included automatically. A matching `v<VERSION>` tag triggers shared tests on
Linux/macOS, then a build and upload to a draft GitHub release. It does not
publish the release or update a tap.

## Trials, errors, and corrections

| Trial / observation | Result and correction |
| --- | --- |
| Initial shell command under the default sandbox | Failed before running: `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`. Read/write checks were subsequently run through approved escalation. |
| Assumed the project could be described as entirely shell-only | Inspection found the actual Python installation wrapper and two optional Python-using helper paths. Documented installation independence separately from optional feature dependencies. |
| Replaced checkout-linked installation with copied prefix files | Tested paths with spaces, `DESTDIR`, prefix relocation, and installation from an extracted release after deleting that extraction. |
| Repeated activation writes | Avoided accumulating blank lines; compared the second write byte-for-byte with the first and verified backups and unrelated startup content. |
| Upgrade with a different executable symlink target | Verified startup loaded the new installation on PATH rather than the previous version's directory. |
| User ran only `make install`, then `source ~/.bashrc` | The old block still sourced `bach_cli/bach/__init__.sh`, which had been moved. Ran the installed `bach init --write`, saved a startup-file backup, checked syntax, and verified loading from `~/.local/lib/bach`. |
| Planned pip migration order | Corrected docs to uninstall the Python package before installing the replacement command, since the old package uninstaller may remove the same `bin/bach`. |
| ShellCheck/shfmt absent from PATH | Downloaded pinned official ShellCheck 0.10.0 and shfmt 3.10.0 tools into `/tmp`; linted and formatted the changed code. No runtime dependency was added. |
| Existing cross-platform test called `accept_all` on Linux | Changed it to check function availability, avoiding real `sudo iptables` calls during validation. |
| Hand-editing a formula checksum | Replaced the manual substitution step with formula generation from the same build as the archive. Tested custom repository URLs and rejection of malformed repository names. |
| GitHub publishing readiness | `gh` was unavailable; neither a GitHub CLI authentication file nor a GitHub token was present. Prepared and validated automation locally; did not claim publication. |
| Workflow validation | Downloaded pinned official actionlint 1.7.7 into `/tmp`; both workflow definitions passed local validation. |

The live startup repair saved `~/.bashrc.backup.bach.kDqVcr`, replaced the
old marked block using `~/.local/bin/bach init --write`, and passed
`bash -n ~/.bashrc`. A separate child-shell check loaded
`/home/lamnt45/.local/lib/bach/init.sh`. The repair did not claim to update
functions already held in the user's open terminal.

## Verification and practical limits

- `make test BASH=/bin/bash` passed on Linux, including packaging, reload,
  cross-platform, per-module config/model selection, Git copy, and all 90
  common-function assertions. The full suite was run with a temporary HOME.
- Packaging tests exercise legacy-block migration, backups, idempotency,
  startup symlinks, malformed markers, executable symlinks, staging,
  relocation, version switching, archive checksums, generated formulas,
  fork URLs, invalid input, and configuration-preserving uninstallation.
- Error-level ShellCheck, required shfmt formatting checks, actionlint, and
  `git diff --check` passed for the relevant files.
- The user's existing local prefix was updated and module loading verified.
  Open terminals still need to evaluate activation to refresh their state.
- macOS tests are configured in CI but were not run in this session. Neither
  Homebrew formula installation/audit nor real audio/video forwarding was
  exercised. Updating manual guide paths is not an end-to-end hardware test.
- The archive and generated formula are local artifacts under ignored `dist/`.
  Source changes remain uncommitted. No public installation command for a
  nonexistent tap is advertised.

## Lessons learned

1. Distribution should match the core runtime. Optional Python use in a helper
   does not require making Python the installer for a Bash toolkit.
2. Treat installation, shell activation, and same-shell refresh as distinct
   operations. Changing files alone cannot replace a stale startup block.
3. Preserve user startup content and configuration, and test migration from
   the old layout rather than only clean installation.
4. Resolve package-manager symlinks portably and test upgrades against a
   changed target; a versioned package path can become invalid later.
5. Ship the formula and checksum with their exact archive. Rebuilding a tarball
   may change its bytes; do not pair an old formula with a new archive.
6. Exercise staging and paths containing spaces before calling an installer
   portable. Keep platform support claims separate from tests actually run.
7. Tests must not invoke privileged helpers just to test availability.
8. A validated draft-release workflow is preparation, not a published release.

## Remaining maintainer steps

Review and commit the changes, run the macOS CI job, push a matching version
tag, review/publish the resulting draft release, and validate/publish its
formula in an actual Homebrew tap. The repository has no license file; no
license was chosen on the maintainer's behalf.

Operational instructions live in
[the installation/packaging/reload guide](../../../../important/how-installation-packaging-and-reload-work.md).
