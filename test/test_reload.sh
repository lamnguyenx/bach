#!/bin/bash
# ==============================================================
#                         RELOAD TESTS
# ==============================================================
# Exercise reload in the current shell with isolated module/config fixtures.

set -e
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workdir=$(mktemp -d "${TMPDIR:-/tmp}/bach-reload.XXXXXX")
trap 'rm -rf "$workdir"' EXIT
fixture="$workdir/fixture with spaces"
mkdir -p "$fixture" "$workdir/config/bach" "$workdir/elsewhere"
cp "$repo/lib/bach/init.sh" "$fixture/init.sh"
for file in "$repo"/lib/bach/*.sh "$repo"/lib/bach/*.bash; do
    [ "$(basename "$file")" = init.sh ] || printf ':\n' >"$fixture/$(basename "$file")"
done
cat >"$fixture/files.sh" <<'MODULE'
reload_fixture_command() { printf 'original\n'; }
MODULE

# All mutations below affect fixtures, not installed scripts or user config.
env XDG_CONFIG_HOME="$workdir/config" bash --noprofile --norc -s -- "$workdir" "$repo" <<'TESTS'
set -e
workdir=$1
repo=$2
fixture="$workdir/fixture with spaces"
fail() { echo "FAIL: $*" >&2; exit 1; }
expect_failure() {
    if bach_reload >"$workdir/output" 2>"$workdir/errors"; then
        fail 'reload returned success after a load failure'
    fi
    if grep -q 'All bach modules reloaded' "$workdir/output"; then
        fail 'reload printed success after a load failure'
    fi
    grep -Fq "$1" "$workdir/errors" || fail 'diagnostic omitted the failed file'
}

cd "$workdir"
source 'fixture with spaces/init.sh'
type -t bach_reload | grep -qx function
type -t reload_bach | grep -qx function
cd elsewhere
module=personal-value
bach_dir=/stale/path
bach_reload >/dev/null
[ "$PWD" = "$workdir/elsewhere" ] || fail 'reload changed directory'
[ "$module" = personal-value ] || fail 'module loop leaked a global variable'
[ "$(reload_fixture_command)" = original ] || fail 'relative source failed after cd'
[ "$bach_dir" = "$fixture" ] || fail 'reload did not restore its absolute directory'
echo 'PASS: both spellings work after a relative source and directory change'

# Source into this shell, not a subprocess, so replaced definitions persist.
cat >"$fixture/files.sh" <<'MODULE'
reload_fixture_command() { printf 'edited\n'; }
MODULE
reload_bach >/dev/null
[ "$(reload_fixture_command)" = edited ] || fail 'module definition stayed stale'
echo 'PASS: edited module definitions replace the loaded functions'

# The loader itself must refresh to pick up new module lists and helpers.
printf 'reload_fixture_new_module=loaded\n' >"$fixture/new.sh"
sed 's/APP_MODULES=(/APP_MODULES=("new.sh" /' "$fixture/init.sh" >"$workdir/new-init"
cp "$workdir/new-init" "$fixture/init.sh"
bach_reload >/dev/null
[ "$reload_fixture_new_module" = loaded ] || fail 'new module list was ignored'
cp "$repo/lib/bach/init.sh" "$fixture/init.sh"
echo 'PASS: entry point and module lists refresh'

# Catch missing or invalid modules before applying any module changes.
mv "$fixture/git.sh" "$fixture/git.saved"
expect_failure "$fixture/git.sh"
mv "$fixture/git.saved" "$fixture/git.sh"
printf 'broken_function( {\n' >"$fixture/git.sh"
expect_failure "$fixture/git.sh"
printf ':\n' >"$fixture/git.sh"
printf 'return 7\n' >"$fixture/git.sh"
expect_failure "$fixture/git.sh"
printf ':\n' >"$fixture/git.sh"
bach_reload >/dev/null
echo 'PASS: missing files, syntax errors and module failure return nonzero'

# Config failures must not be hidden by a successful subsequent config.
printf 'reload_fixture_setting=updated\n' >"$XDG_CONFIG_HOME/bach/config.sh"
printf 'return 9\n' >"$XDG_CONFIG_HOME/bach/config-git.sh"
printf ':\n' >"$XDG_CONFIG_HOME/bach/config-video.sh"
expect_failure "$XDG_CONFIG_HOME/bach/config-git.sh"
printf 'broken_config( {\n' >"$XDG_CONFIG_HOME/bach/config-git.sh"
expect_failure "$XDG_CONFIG_HOME/bach/config-git.sh"
printf 'reload_fixture_module_setting=updated\n' >"$XDG_CONFIG_HOME/bach/config-git.sh"
bach_reload >/dev/null
[ "$reload_fixture_setting" = updated ] || fail 'shared config was not refreshed'
[ "$reload_fixture_module_setting" = updated ] || fail 'module config was not refreshed'
echo 'PASS: config failures propagate and corrected configs reload'

# Reject a broken entry point without replacing the currently working loader.
printf 'broken_entry( {\n' >"$fixture/init.sh"
expect_failure "$fixture/init.sh"
cp "$repo/lib/bach/init.sh" "$fixture/init.sh"
bach_reload >/dev/null
echo 'PASS: entry point syntax errors are reported and recoverable'

# Exported reload functions need enough state to initialize a fresh child Bash.
bash --noprofile --norc -c '
    set -e
    bach_reload >/dev/null
    [ "$(reload_fixture_command)" = edited ]
    [ "$reload_fixture_setting" = updated ]
'
echo 'PASS: exported reload initializes child Bash state'

# A noninteractive child may inherit fzf functions but has no Readline session.
__fzfcmd() { :; }
printf 'return 12\n' >"$fixture/fzf_tools.sh"
bach_reload >/dev/null
echo 'PASS: noninteractive reload skips Readline bindings'
TESTS
