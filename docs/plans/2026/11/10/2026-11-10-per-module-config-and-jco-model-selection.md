# Work Log: per-module config loading + jco model selection

**Date**: 2026-11-10
**Status**: ✅ **IMPLEMENTED** (uncommitted at time of writing)
**Related**: `bach_cli/bach/__init__.sh`, `bach_cli/bach/git.sh`,
`test/test_config.sh`, `README.md`, `docs/important/how-config-loading-works.md`,
`~/.bashrc`, `~/.config/bach/config.sh`, `~/.config/bach/config-git.sh`

## Overview

Three consecutive pieces of work on the same theme:

1. **Debug**: `jcoap`/`jco` ignored a `BACH_JCO_MODEL` change in
   `~/.config/bach/config.sh`. Root cause was a stale `jco()` defined *after*
   the bach block in `~/.bashrc`, with the model hardcoded — plus `export -f`
   broadcasting that stale function into every child shell.
2. **Feature**: optional per-module user config, re-sourced before every bach
   command: `~/.config/bach/config.sh` (shared) +
   `~/.config/bach/config-<module>.sh` (module-specific, wins). Module `git.sh`
   migrated; other modules can adopt the same one-line pattern.
3. **Feature**: `BACH_JCO_MODEL` accepts several models (one per line, or a
   bash array). With more than one configured, `jco*` shows a numbered menu.

## Act 1 — why the model change did not apply

### Symptom

`~/.config/bach/config.sh` was edited to `VAI 2/glm-5.3` but `jcoap` kept
committing with `opencode-go/deepseek-v4.1-flash`.

### Trials and errors

| # | Trial | Result |
|---|-------|--------|
| 1 | `which jcoap` | Useless — `jcoap` is a shell function, not a file. `type -a jcoap` is the right tool for functions. |
| 2 | Read bach source | Bach's `jco` *does* read `BACH_JCO_MODEL`; config is sourced once at shell startup. Suspected "need to restart shell" as the whole story. It wasn't. |
| 3 | Remove the bashrc override, re-test with `bash -lc` | **Still** showed the old hardcoded model. Confusing. |
| 4 | `env \| grep BASH_FUNC` | Found `BASH_FUNC_jco%%` with the hardcoded body. bach does `export -f jco jcoa jcop jcoap`, so the override had been exported into the environment and child shells inherited the *stale* function — no bashrc involved. Lesson: with `export -f`, the environment can shadow rc files. |
| 5 | Sandbox shell (`bash --noprofile --norc`, `env -u BASH_FUNC_jco%%`) + fake `opencode` shim on PATH | Proved bach's own `jco` correctly used `VAI 2/glm-5.3`. Root cause confirmed as the bashrc override, full stop. |

`jco`/`jcoap` have **no `--dryrun` flag** (the user asked to test with one).
The equivalent dry-run: a stub `opencode` earlier on `PATH` that prints its
argv, so you see exactly `-m <model>` without running a model:

```bash
mkdir -p /tmp/shim && printf '#!/usr/bin/env bash\necho "CALLED: $*"\n' > /tmp/shim/opencode
chmod +x /tmp/shim/opencode
PATH=/tmp/shim:$PATH jco ...
```

### Fix

Deleted the `jco()` override from `~/.bashrc` (it lived ~30 lines *after* the
bach source block, defining a body bach already provides) and left a comment
warning not to redefine bach commands there. One `reload_bach` per open shell
to drop the stale exported function.

## Act 2 — per-module config, re-sourced per command

### Design

```bash
load_bach_config            # config.sh only (shared)
load_bach_config git docker # config.sh, then config-git.sh, config-docker.sh
load_all_bach_configs       # every config file present (startup + reload_bach)
```

- Shared file first, module file second → module wins conflicts.
- Sourced at shell startup (values usable immediately) **and** re-sourced by
  each module command → edits apply on the next command, no
  restart/`reload_bach`.
- Every exported command in `git.sh` starts with `load_bach_config git`
  (22 functions). `bach_config_dir()` centralizes the XDG path. Help texts
  updated.

### Trials and errors

- **First version loaded only `config.sh` at startup**; module files loaded
  only on command. My own test asserted "startup loads config.sh only", and
  while making the assertions pass I asked *why* — a module variable that is
  unset until first command use is a footgun for anything else reading it
  (prompts, completions). Changed to `load_all_bach_configs()` at startup and
  rewrote the test to assert the opposite. Writing the test first caught a
  design smell.
- **The `${VAR:-default}` trap (the big one).** The original user config was
  `BACH_JCO_MODEL="${BACH_JCO_MODEL:-VAI 2/glm-5.3}"`. That is *actively
  harmful* under re-sourcing: after the first source the variable is set, so
  the `:-` fallback keeps resurrecting the first value forever — edits to the
  file never land in the same shell. My first interactive verification
  ("edit the file, run `jco` again in the same shell") failed exactly this way
  while the test passed (the test edited between *separate* invocations).
  Fix: direct assignment in config files; documented in README and in the
  config file header. Trade-off accepted: ad-hoc env override
  (`BACH_JCO_MODEL=X jco`) no longer wins over the file — use `jco -m X`.
- Tests must not touch the real `~/.config/bach`: `test_config.sh` exports its
  own `XDG_CONFIG_HOME` sandbox *before* sourcing bach.
- `shellcheck` is not installed on this host; AGENTS.md's
  `shellcheck --severity=error` works via `npx --yes shellcheck …`.
  (`shfmt` unavailable either.)

## Act 3 — multiple models with a menu

### Behavior

`BACH_JCO_MODEL` may be one model per line (blank/whitespace lines ignored) or
a bash array. One model → used silently. Several → numbered bash `select`
menu; Ctrl-D aborts the commit rather than guessing; non-interactive stdin →
first model + a warning pointing at `-m`; explicit `-m` skips the menu.

New helpers in `git.sh`: `jco_configured_models` (parse/trim),
`jco_select_model` (choose), `jco_has_model_arg` (did the user already pass
`-m` before the first non-option word). `jco` and `jcoa` use them; `jcop`/
`jcoap` delegate and inherit. `jcoa` resolves the model **once** and injects
`-m <model>` into the args passed down to every submodule `jco` call — without
that, an N-submodule repo would prompt N times.

### Trials and errors

- Interactive `select` cannot be tested by piping stdin — `[ -t 0 ]` is false,
  so the non-interactive path runs (that's how the warning path got
  exercised). To drive the real menu: `printf '2\n' | script -qec 'bash
  script.sh' /dev/null` (pty). Verified menu rendering, choice propagation,
  and `jcoa` prompting exactly once across submodule + root commits.
- `PS3` was first assigned as a non-local variable inside the function;
  made it `local` so the global env isn't polluted.
- Bash 3.2 compatibility (macOS): iterating an array under `set -u` uses a
  `${BACH_JCO_MODEL+set}` guard instead of `"${BACH_JCO_MODEL[@]:-}"`; the
  menu uses built-in `select` (no fzf dependency).

## Verification summary

- `bash test/test_config.sh` — 16 assertions: startup load, shared→module
  order + override, `.sh` suffix normalization, same-shell edit pickup,
  `reload_bach`, jco/jcoa model plumbing, multiline/array parsing, `-m`
  precedence, non-interactive fallback.
- `bash test/test_cross_platform.sh`, `bash test/test_git_copy_clean.sh` —
  no regressions.
- `npx --yes shellcheck --severity=error` clean on all changed shell files.
- Live pty runs with an `opencode` shim and with real `opencode`
  (`build · glm-5.3` observed).

## Lessons learnt

1. **`export -f` makes functions environment-borne.** A stale exported
   function shadows rc files and persists in agents/CI children. When a shell
   function misbehaves, check *where its body comes from*:
   `type -a <fn>`, `declare -f <fn>`, `env | grep BASH_FUNC`.
2. **Define a command once, in its module.** The `~/.bashrc` copy diverged
   silently from bach's. The note left behind says: change the model in
   `config-git.sh`, never redefine `jco` in bashrc.
3. **Re-sourced config files must assign directly.** `${VAR:-default}` freezes
   the first value; that pattern is only safe for load-once configs.
4. **Config files must be idempotent** (sourced repeatedly, per command).
5. **A PATH shim is the honest dry-run** for "which model/args would run".
6. **`script -qec` (pty) is the way to test interactive bash menus**; plain
   pipes take the non-interactive branch.
7. **Sandbox config in tests** (`XDG_CONFIG_HOME` override) — user config is
   global state otherwise.

## Follow-ups

- Other modules (`docker.sh`, `android.sh`, …) can adopt
  `load_bach_config <module>` + a `config-<module>.sh` — not done yet.
- Install `shellcheck` natively (and `shfmt` per coding conventions) so the
  AGENTS.md lint command works without npx.
- Everything is uncommitted; tests + docs land with the code in one commit.
