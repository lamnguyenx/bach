# Work log: reliable same-shell Bach reload

Date: 2026-11-10
Status: implemented, tested on Linux, and installed into the existing local
prefix; source changes remain uncommitted.

## Scope and symptom

The user reported that `bach_reload` seldom worked. This changed Bach's
internal loader (`lib/bach/init.sh`), added `test/test_reload.sh`, integrated
that suite into `make test`, and updated the README/configuration guide.
No separate Git submodules exist. The 18 relocated application/core shell
modules retained their contents; their inventory and packaging work are in
[the packaging work log](2026-11-10-shell-packaging-and-release-migration.md).

The existing function was named `reload_bach`; `bach_reload` did not exist.
The loader recorded `bach_dir` using only `dirname`, which could leave a
relative path. The reload function re-used the current module arrays/helper
functions, then printed success without checking module/config results.

## Trials and observed failures

1. Built a temporary module tree with the real loader and stub modules, sourced
   it by a relative path, then changed directories. `reload_bach` produced
   **17 missing-file errors**, printed `All bach modules reloaded`, and
   returned **0**. This reproduced a concrete false-success failure without
   changing the user's files.
2. Inspected the loader: re-sourcing only module files left loader helpers and
   module-list changes stale. The global loop variable `module` also leaked
   into the calling shell.
3. Checked exported-function behavior: child Bash processes inherit exported
   function bodies, but not the loader's ordinary globals and arrays. A
   working reload needs enough state to rebuild those definitions.
4. Checked fzf integration: an inherited `__fzfcmd` alone does not establish an
   interactive Readline session. The loader must gate the binding module on
   both an interactive shell and the fzf helper's presence.

## Changes

- Record an absolute entry-file path in exported `_BACH_INIT_FILE`, using
  builtin `cd`/`pwd` so the user's `cd` function cannot alter path resolution.
- Add `bach_reload` and retain `reload_bach` as a wrapper. Both source the entry
  point into the current shell rather than launching a child to do the work.
- Re-read the complete entry point on reload, refreshing module arrays,
  config helpers, reload functions, and interactive completion.
- Make the module loop variable local and validate module readability/syntax
  before applying module changes.
- Report a failed module/config source with its path and return nonzero.
  Validate every startup/reload config before applying config assignments.
- Print the success message only after the full reload succeeds.
- Skip Readline/fzf binding setup in noninteractive shells.

## Regression checks and installation

`test/test_reload.sh` uses only temporary fixtures. It checks both function
spellings, relative loading followed by a directory change, paths with spaces,
restoration after a stale `bach_dir`, unchanged caller working directory,
no global `module` leak, edited definitions, new module-list entries, missing
modules, syntax failures, explicit module/config return failures, recovery,
entry-file syntax failure, fresh child Bash state, and noninteractive fzf
isolation. The test verifies both exit status and absence of false success.

The reload suite and complete `make test BASH=/bin/bash` passed on Linux.
An interactive Bash check successfully ran both names and found completion
loaded. That check used no controlling terminal, so Bash printed the expected
job-control warnings; it was not a full terminal-emulator test. ShellCheck,
shfmt checks, and `git diff --check` passed. macOS validation remains for CI.

After tests, ran `make install PREFIX=/home/lamnt45/.local` and tested both
reload functions from the installed files with a temporary HOME. Verified the
entry path was `/home/lamnt45/.local/lib/bach/init.sh`. The user was instructed
to run `eval "$(bach init)"` once in the existing terminal to replace the old
in-memory loader; installing files cannot update functions already loaded in
a parent shell.

## Lessons learned and limits

1. A reload's success message must reflect its exit status and completed work.
   A final `echo` must not hide earlier source failures.
2. Re-read the loader, not just its current list of modules. Otherwise upgrades
   to the mechanism doing the reload never reach the running shell.
3. Reload must operate in the caller's shell; an executable can only print
   code for the parent to evaluate. `bach reload` therefore differs from
   `bach_reload`: use `eval "$(bach reload)"` for the executable form.
4. Capture absolute paths when loading. Do not assume the caller stays in the
   original directory or preserves generic global variables.
5. Exported functions need a way to reconstruct unexported state in children.
6. Source edits and installed files are separate. Run `make install` after
   editing the checkout; reload then reads that installed version.
7. Reload is not transactional. A runtime failure can leave some definitions
   changed. Syntax checking does not make arbitrary sourced code safe from
   side effects or detect every intermediate command failure.
8. Deleted assignments/functions are not automatically unset/removed. Use a
   new shell when a clean environment is required.
9. If an upgrade replaces the recorded installation path, evaluate
   `$(bach reload)` through the current executable to select the active
   package instead of relying on the old recorded entry file.

See [the operational guide](../../../../important/how-installation-packaging-and-reload-work.md)
and [configuration reference](../../../../important/how-config-loading-works.md).
