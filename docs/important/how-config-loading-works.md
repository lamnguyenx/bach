# How user configuration loads

How bach discovers, layers, and refreshes user configuration, and how the
`jco*` model selection works. Work log for the change itself:
`docs/plans/2026/11/10/2026-11-10-per-module-config-and-jco-model-selection.md`.

Installation, the migration from `bach_cli/bach/__init__.sh`, and the
one-time activation needed to replace an old in-memory loader are documented
in [the installation and reload guide](how-installation-packaging-and-reload-work.md).
The reload review and regression results are recorded in
[the reload work log](../plans/2026/11/10/2026-11-10-reliable-bash-reload.md).

## File layout

All config lives in one directory and none of it is tracked by bach:

```
${XDG_CONFIG_HOME:-$HOME/.config}/bach/
├── config.sh            # shared settings, read by every module
├── config-git.sh        # settings for git.sh commands only
├── config-docker.sh     # settings for docker.sh commands only
└── config-<module>.sh   # settings for <module>.sh commands
```

`config.sh` is always loaded first; `config-<module>.sh` is loaded after it,
so a module file wins on conflicts.

## When files are sourced

- **Shell startup** (`init.sh`): all config files present are sourced, so
  values are usable immediately anywhere in the shell.
- **Before each module command**: `jco`, `jcoa`, `jcop`, `jcoap`, `gl`,
  `just_*`, `git_copy_clean`, … all begin with `load_bach_config git`, which
  re-sources `config.sh` and `config-git.sh` before reading any setting.
  Edits therefore apply to the *next command* — no shell restart and no
  `reload_bach`.
- **`bach_reload` / `reload_bach`**: re-sources the recorded entry point,
  every module, and every config file in the current shell. The absolute entry
  path works after changing directories; re-reading it also refreshes loader
  helpers and module lists. Missing files, syntax errors, and failed loads
  return nonzero rather than printing success. A runtime failure can leave
  partially updated definitions; fix the reported file and retry.
- **Source edits vs. installed files**: run `make install` after editing a
  checkout, then reload. For a package-manager upgrade that replaces the
  installation path, use `eval "$(bach reload)"` to select the current package.
  Plain `bach reload` only prints activation code.
- **Removed settings**: reload applies the assignments still present; it does
  not unset variables or remove functions whose definitions were deleted.
  Open a new shell for a clean state.

## Rules for config files

1. **Assign directly — no `${VAR:-default}` fallbacks.**

   ```bash
   # ✅ correct: edits always apply
   BACH_JCO_MODEL="VAI 2/glm-5.3"

   # ❌ wrong: after the first source, BACH_JCO_MODEL is already set, so the
   # fallback resurrects the first value forever and edits never land
   BACH_JCO_MODEL="${BACH_JCO_MODEL:-VAI 2/glm-5.3}"
   ```

   For one-off overrides use the command's flag (`jco -m <model>`), not an
   ad-hoc environment variable.
2. **Keep files idempotent** — they are sourced repeatedly (once per command).
   Direct assignments are idempotent; `export`-accumulating or appending
   lines are not.
3. **Never redefine bach commands in `~/.bashrc`.** A local `jco()` there
   silently replaces bach's (and via `export -f` leaks into child shells).
   The model lives in `config-git.sh`; tweak it there.

## Adding config for another module

One line per public command, then the config file:

```bash
# in lib/bach/docker.sh, first line of each exported function:
load_bach_config docker

# user creates: ~/.config/bach/config-docker.sh
BACH_DOCKER_SOMETHING="value"
```

`load_bach_config` normalizes module names (`git` and `git.sh` both map to
`config-git.sh`) and silently skips missing files.

## jco model selection

`BACH_JCO_MODEL` (usually in `config-git.sh`) accepts **one model per line**
(blank lines and indentation ignored) or a **bash array**:

```bash
BACH_JCO_MODEL="
VAI 2/glm-5.3
opencode-go/deepseek-v4.1-flash
"
```

Behavior:

- **One model** — used directly.
- **Several models** — a numbered menu asks which one to use:

  ```
  1) VAI 2/glm-5.3
  2) opencode-go/deepseek-v4.1-flash
  Select model>
  ```

  Canceling (Ctrl-D) aborts the commit.
- **Non-interactive stdin** (scripts, CI) — the first model is used and a
  warning is printed suggesting `-m`. Pass `-m <model>` to choose explicitly;
  an explicit `-m` always skips the menu.
- **`jcoa`/`jcoap`** ask once, then pass the choice down to every submodule
  commit — never once per repository.

## Troubleshooting

- **A config edit does not apply**: confirm the file uses direct assignment
  (rule 1); confirm nothing redefines the command (`type -a jco` — the body
  should be bach's, not `~/.bashrc`'s).
- **The command still misbehaves after fixing things**: bach exports its
  functions (`export -f`), so shells started *before* the fix keep the old
  body in their environment. If the loader itself is old, first run
  `eval "$(bach init)"`; afterward use `bach_reload` or `reload_bach`. Check
  for startup overrides if a new shell still inherits the wrong function.
- **Which model would actually run?** Dry-run without calling a model:
  put a stub `opencode` that prints `"$*"` first on `PATH` and run `jco`.
