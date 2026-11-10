#!/bin/bash
# ==============================================================
#                         PACKAGING TESTS
# ==============================================================
# Exercise staged installs, activation, migration, symlinks and releases.

set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workdir=$(mktemp -d "${TMPDIR:-/tmp}/bach-packaging.XXXXXX")
trap 'rm -rf "$workdir"' EXIT
test_home="$workdir/home"
prefix="$workdir/prefix with spaces"
mkdir -p "$test_home"
run_cli() {
    env HOME="$test_home" PATH="$prefix/bin:$PATH" "$prefix/bin/bach" "$@"
}

make -s -C "$repo" install PREFIX="$prefix"
[ ! -e "$test_home/.bashrc" ]
[ "$(run_cli --version)" = "$(cat "$repo/VERSION")" ]
run_cli init >"$workdir/activation"
bash -n "$workdir/activation"
[ ! -e "$test_home/.bashrc" ]

# Replace the legacy Python block, preserving unrelated content.
cat >"$test_home/.bashrc" <<'RC'
export PERSONAL_SETTING=kept
# >>> bach initialize >>>
source "/old/python/package/init.sh"
eval "$(_BACH_COMPLETE=bash_source bach)"
# <<< bach initialize <<<
# Personal footer
RC
cp "$test_home/.bashrc" "$workdir/original"
run_cli init --write
[ "$(grep -c '^# >>> bach initialize >>>$' "$test_home/.bashrc")" -eq 1 ]
! grep -q '_BACH_COMPLETE\|/old/python' "$test_home/.bashrc"
grep -q '^export PERSONAL_SETTING=kept$' "$test_home/.bashrc"
grep -q '^# Personal footer$' "$test_home/.bashrc"
cmp "$workdir/original" "$(find "$test_home" -name '.bashrc.backup.bach.*' | head -n 1)"
cp "$test_home/.bashrc" "$workdir/once"
run_cli init --write
cmp "$workdir/once" "$test_home/.bashrc"

# Existing files and symlinks are preserved; missing files can be created.
mv "$test_home/.bashrc" "$test_home/startup"
ln -s startup "$test_home/.bashrc"
run_cli deinit
[ -L "$test_home/.bashrc" ]
! grep -q 'bach initialize' "$test_home/startup"
run_cli init --write --rc "$test_home/new startup"
bash -n "$test_home/new startup"
printf '%s\n' '# >>> bach initialize >>>' >"$test_home/broken"
cp "$test_home/broken" "$workdir/broken"
if run_cli init --write --rc "$test_home/broken"; then
    echo 'Malformed markers should be rejected' >&2
    exit 1
fi
cmp "$workdir/broken" "$test_home/broken"

# Both absolute and relative package-manager symlinks locate modules.
mkdir -p "$workdir/links"
ln -s "$prefix/bin/bach" "$workdir/links/absolute"
ln -s '../prefix with spaces/bin/bach' "$workdir/links/relative"
[ "$("$workdir/links/absolute" --version)" = "$(cat "$repo/VERSION")" ]
"$workdir/links/relative" init | grep -q 'lib/bach/init.sh'

# DESTDIR is staging only; the copied prefix works after being relocated.
make -s -C "$repo" install PREFIX=/usr/local DESTDIR="$workdir/stage"
mv "$workdir/stage/usr/local" "$workdir/relocated"
"$workdir/relocated/bin/bach" init >"$workdir/relocated-init"
! grep -q '/stage/' "$workdir/relocated-init"
grep -q "$workdir/relocated/lib/bach/init.sh" "$workdir/relocated-init"

# Startup resolves the command on PATH after a package version changes.
run_cli init --write
mkdir -p "$workdir/active-bin"
ln -s "$prefix/bin/bach" "$workdir/active-bin/bach"
env HOME="$test_home" PATH="$workdir/active-bin:$PATH" bash -c '
    source "$HOME/.bashrc" >/dev/null
    declare -F load_bach_config >/dev/null
    trap - EXIT
'
rm "$workdir/active-bin/bach"
ln -s "$workdir/relocated/bin/bach" "$workdir/active-bin/bach"
env HOME="$test_home" PATH="$workdir/active-bin:$PATH" bash -c '
    source "$HOME/.bashrc" >/dev/null
    case "$bach_dir" in */relocated/lib/bach) ;; *) exit 1 ;; esac
    trap - EXIT
'

# Build and install the shipped artifact, then remove its source tree.
make -s -C "$repo" dist
version=$(cat "$repo/VERSION")
archive="$repo/dist/bach-$version.tar.gz"
if command -v sha256sum >/dev/null 2>&1; then
    (cd "$repo/dist" && sha256sum -c "bach-$version.tar.gz.sha256")
else
    (cd "$repo/dist" && shasum -a 256 -c "bach-$version.tar.gz.sha256")
fi
# The formula must reference this exact archive and contain no placeholders.
read -r release_checksum _ <"$archive.sha256"
grep -Fq "sha256 \"$release_checksum\"" "$repo/dist/bach.rb"
grep -Fq "releases/download/v$version/bach-$version.tar.gz" "$repo/dist/bach.rb"
! grep -Eq '@(VERSION|SHA256|REPOSITORY)@' "$repo/dist/bach.rb"
tar -xzf "$archive" -C "$workdir"
# Forks generate their own release URLs, and invalid repository names fail.
env BACH_RELEASE_REPOSITORY=example/bach-fork make -s -C "$workdir/bach-$version" dist
grep -Fq 'https://github.com/example/bach-fork/releases/download/' \
    "$workdir/bach-$version/dist/bach.rb"
if env BACH_RELEASE_REPOSITORY=invalid/repository/extra \
    make -s -C "$workdir/bach-$version" dist; then
    echo 'Invalid release repository should be rejected' >&2
    exit 1
fi
make -s -C "$workdir/bach-$version" install PREFIX="$workdir/release"
rm -rf "$workdir/bach-$version"
[ "$("$workdir/release/bin/bach" --version)" = "$version" ]
"$workdir/release/bin/bach" init | grep -q '/release/lib/bach/init.sh'

mkdir -p "$test_home/.config/bach"
printf 'personal config\n' >"$test_home/.config/bach/config.sh"
run_cli deinit
make -s -C "$repo" uninstall PREFIX="$prefix"
[ ! -e "$prefix/bin/bach" ]
[ ! -e "$prefix/lib/bach" ]
[ -f "$test_home/.config/bach/config.sh" ]
[ -L "$test_home/.bashrc" ]
echo 'Packaging tests passed.'
