#!/bin/bash
# Tests per-module user configuration:
#   - config.sh is shared, config-<module>.sh is module-specific
#   - module files load after config.sh and win on conflicts
#   - configs are re-sourced on the next command, without reload_bach
#   - jco picks the model from config-git.sh, and -m still overrides it

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fail() {
    echo "❌ $*"
    exit 1
}

pass() {
    echo "   ✅ $*"
}

# -----------------------------------
#            fixtures
# -----------------------------------

# Isolate from the real user config; must be set before bach is sourced.
export XDG_CONFIG_HOME="$workdir/config"
config_dir="$XDG_CONFIG_HOME/bach"
mkdir -p "$config_dir"

write_shared() {
    cat >"$config_dir/config.sh" <<'EOF'
BACH_TEST_SHARED="shared"
BACH_TEST_OVERRIDE="shared"
EOF
}

write_git() {
    cat >"$config_dir/config-git.sh" <<'EOF'
BACH_TEST_GIT="git"
BACH_TEST_OVERRIDE="git"
EOF
}

write_shared
write_git
cat >"$config_dir/config-docker.sh" <<'EOF'
BACH_TEST_DOCKER="docker"
EOF

unset BACH_JCO_MODEL BACH_JCO_PROMPT_FILE BACH_TEST_SHARED BACH_TEST_OVERRIDE BACH_TEST_GIT BACH_TEST_DOCKER

# shellcheck source=../bach_cli/bach/__init__.sh
source "$SCRIPT_DIR/../bach_cli/bach/__init__.sh"

# -----------------------------------
#            assertions
# -----------------------------------

echo "🧪 Testing bach per-module config"

# At startup every config file is loaded, so values are usable right away.
[ "${BACH_TEST_SHARED:-}" = "shared" ] || fail "config.sh not sourced at startup"
[ "${BACH_TEST_GIT:-}" = "git" ] || fail "config-git.sh not sourced at startup"
[ "${BACH_TEST_DOCKER:-}" = "docker" ] || fail "config-docker.sh not sourced at startup"
pass "startup loads all config files"

# load_bach_config with no args refreshes the shared file only.
BACH_TEST_SHARED="stale"
BACH_TEST_GIT=""
load_bach_config
[ "$BACH_TEST_SHARED" = "shared" ] || fail "load_bach_config did not re-source config.sh"
[ -z "$BACH_TEST_GIT" ] || fail "load_bach_config loaded a module file unasked"
pass "load_bach_config re-sources config.sh"

# load_bach_config <module> loads the shared file first, then the module file.
BACH_TEST_SHARED="stale"
BACH_TEST_OVERRIDE="stale"
BACH_TEST_DOCKER=""
load_bach_config git
[ "$BACH_TEST_SHARED" = "shared" ] || fail "shared config not loaded for a module command"
[ "$BACH_TEST_GIT" = "git" ] || fail "config-git.sh not sourced"
[ "$BACH_TEST_OVERRIDE" = "git" ] || fail "module config did not override shared config"
[ -z "${BACH_TEST_DOCKER:-}" ] || fail "config-docker.sh loaded by a git command"
pass "load_bach_config git loads config.sh then config-git.sh"

# Accepts file-style module names too.
BACH_TEST_GIT=""
load_bach_config git.sh
[ "$BACH_TEST_GIT" = "git" ] || fail "load_bach_config git.sh not normalised"
pass "module names accept a .sh suffix"

# A second command sees edits made after the first one (no reload_bach).
cat >"$config_dir/config-git.sh" <<'EOF'
BACH_TEST_GIT="edited"
EOF
load_bach_config git
[ "$BACH_TEST_GIT" = "edited" ] || fail "config edits not re-sourced on the next command"
pass "edits apply on the next command"

# reload_bach re-sources every config file present.
write_shared
write_git
BACH_TEST_SHARED="stale"
BACH_TEST_GIT="stale"
BACH_TEST_DOCKER="stale"
reload_bach >/dev/null
[ "$BACH_TEST_SHARED" = "shared" ] || fail "reload_bach missed config.sh"
[ "$BACH_TEST_GIT" = "git" ] || fail "reload_bach missed config-git.sh"
[ "$BACH_TEST_DOCKER" = "docker" ] || fail "reload_bach missed config-docker.sh"
pass "reload_bach re-sources all config files"

# -----------------------------------
#            jco integration
# -----------------------------------

unset BACH_JCO_MODEL BACH_JCO_PROMPT_FILE

cat >"$config_dir/config.sh" <<'EOF'
EOF
cat >"$config_dir/config-git.sh" <<'EOF'
BACH_JCO_MODEL="provider/model-from-git-config"
EOF

# Stub opencode so no model is actually called; record the argv.
mkdir -p "$workdir/bin"
cat >"$workdir/bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$JCO_STUB_OUT"
EOF
chmod +x "$workdir/bin/opencode"

repo="$workdir/repo"
git init -q "$repo"
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
: >"$repo/file"
git -C "$repo" add file
git -C "$repo" commit -qm init
echo change >>"$repo/file"

export JCO_STUB_OUT="$workdir/jco-args"
orig_path="$PATH"
orig_dir="$PWD"
export PATH="$workdir/bin:$PATH"

cd "$repo" || fail "cannot cd to test repository"

jco >/dev/null 2>&1 || fail "first jco run failed"
grep -q -- '-m provider/model-from-git-config ' "$JCO_STUB_OUT" || fail "jco did not use BACH_JCO_MODEL from config-git.sh"
pass "jco uses the model from config-git.sh"

# Edit the config without restarting, then call jco again from the SAME shell:
# the value from the previous source must not stick.
cat >"$config_dir/config-git.sh" <<'EOF'
BACH_JCO_MODEL="provider/model-edited"
EOF
jco >/dev/null 2>&1 || fail "jco failed after editing config-git.sh"
grep -q -- '-m provider/model-edited ' "$JCO_STUB_OUT" || fail "jco did not pick up an edited config-git.sh"
pass "jco picks up config edits immediately"

# An explicit -m still wins.
jco -m provider/model-flag >/dev/null 2>&1 || fail "jco -m failed"
grep -q -- '-m provider/model-flag ' "$JCO_STUB_OUT" || fail "jco -m no longer overrides the configured model"
pass "jco -m still overrides config"

# -----------------------------------
#        multiple models
# -----------------------------------

# One per line, blank lines and surrounding whitespace ignored.
BACH_JCO_MODEL=$'\n  provider/model-a  \n\n\tprovider/model-b\n'
models="$(jco_configured_models)"
[ "$models" = $'provider/model-a\nprovider/model-b' ] || fail "multiline model list parsed wrong: [$models]"
pass "BACH_JCO_MODEL accepts one model per line"

# Bash array form.
BACH_JCO_MODEL=("provider/model-a" "provider/model-b")
models="$(jco_configured_models)"
[ "$models" = $'provider/model-a\nprovider/model-b' ] || fail "array model list parsed wrong: [$models]"
pass "BACH_JCO_MODEL accepts a bash array"

# Non-interactive selection falls back to the first model.
BACH_JCO_MODEL=$'provider/model-a\nprovider/model-b'
jco_select_model >/dev/null 2>&1
[ "$JCO_MODEL_CHOICE" = "provider/model-a" ] || fail "non-interactive selection did not use the first model"
pass "non-interactive selection uses the first model"

# jco with several configured models uses the first when non-interactive.
cat >"$config_dir/config-git.sh" <<'EOF'
BACH_JCO_MODEL="
provider/model-a
provider/model-b
"
EOF
jco >/dev/null 2>&1 || fail "jco with several models failed"
grep -q -- '-m provider/model-a ' "$JCO_STUB_OUT" || fail "jco did not use the first configured model"
pass "jco uses the first of several models when non-interactive"

# -m skips the menu entirely.
jco -m provider/model-b >/dev/null 2>&1 || fail "jco -m with several models failed"
grep -q -- '-m provider/model-b ' "$JCO_STUB_OUT" || fail "jco -m did not override the model list"
pass "jco -m skips the model menu"

# jcoa resolves the model once and passes it to submodule and root commits.
(
    calls="$workdir/jcoa-calls"
    : >"$calls"
    jco() { printf '%s\n' "$*" >>"$calls"; }
    jco_commit_submodules() { jco "$@"; }
    jcoa "extra instructions" >/dev/null 2>&1
)
[ "$(wc -l <"$workdir/jcoa-calls")" -eq 2 ] || fail "jcoa did not call jco for both submodules and root"
[ "$(grep -c -- '-m provider/model-a' "$workdir/jcoa-calls")" -eq 2 ] || fail "jcoa did not pass the selected model down"
grep -q -- 'extra instructions' "$workdir/jcoa-calls" || fail "jcoa dropped the extra instructions"
pass "jcoa selects the model once and passes it down"

# jcoa with an explicit -m must not ask at all.
rm -f "$workdir/jcoa-asked"
(
    calls="$workdir/jcoa-flag-calls"
    : >"$calls"
    jco() { printf '%s\n' "$*" >>"$calls"; }
    jco_commit_submodules() { jco "$@"; }
    jco_select_model() { printf 'asked\n' >>"$workdir/jcoa-asked"; }
    jcoa -m provider/model-flag "extra instructions" >/dev/null 2>&1
)
[ ! -f "$workdir/jcoa-asked" ] || fail "jcoa asked for a model despite -m"
grep -q -- '-m provider/model-flag' "$workdir/jcoa-flag-calls" || fail "jcoa dropped the -m override"
pass "jcoa -m skips the model menu"

cd "$orig_dir" || fail "cannot restore working directory"
export PATH="$orig_path"

echo "🎉 All bach config tests passed"
