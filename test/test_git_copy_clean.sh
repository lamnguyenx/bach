#!/bin/bash
# Tests git_copy_clean: ignored files stay behind, tracked and
# untracked-not-ignored files (and symlinks) come along, submodules get their
# own .gitignore applied, and -g produces a clean working checkout.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/bach/init.sh
source "$SCRIPT_DIR/../lib/bach/init.sh"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fail() {
    echo "❌ $*"
    exit 1
}

pass() {
    echo "   ✅ $*"
}

make_repo() {
    git init -q "$1"
    git -C "$1" config user.email test@example.com
    git -C "$1" config user.name test
}

# -----------------------------------
#            fixtures
# -----------------------------------

src="$workdir/src"
sub="$workdir/sub-src"
make_repo "$src"
make_repo "$sub"

printf 'sub-ignored/\n*.log\n' >"$sub/.gitignore"
printf 'sub\n' >"$sub/sub.txt"
mkdir -p "$sub/sub-ignored"
printf 'junk\n' >"$sub/sub-ignored/blob.bin"
git -C "$sub" add -A
git -C "$sub" commit -qm "sub init"

printf 'ignored_dir/\n*.log\n' >"$src/.gitignore"
mkdir -p "$src/src" "$src/ignored_dir" "$src/nested"
printf 'hello\n' >"$src/README.md"
printf 'code\n' >"$src/src/app.sh"
printf 'junk\n' >"$src/ignored_dir/big.bin"
printf 'log\n' >"$src/nested/run.log"
ln -s README.md "$src/link-to-readme"
git -C "$src" add .gitignore README.md src link-to-readme
git -C "$src" commit -qm "init"

git -C "$src" -c protocol.file.allow=always submodule add -q "$sub" vendor/sub
git -C "$src" commit -qm "add submodule"
mkdir -p "$src/vendor/sub/sub-ignored"
printf 'junk\n' >"$src/vendor/sub/sub-ignored/blob.bin"

# -----------------------------------
#            tests
# -----------------------------------

echo "1. Testing usage..."
if git_copy_clean >/dev/null 2>&1; then
    fail "git_copy_clean with no arguments should fail"
fi
if ! git_copy_clean --help | grep -q "USAGE:"; then
    fail "--help should print usage"
fi
pass "usage and --help"

echo "2. Testing copy without .git..."
dst="$workdir/dst"
git_copy_clean "$src" "$dst" >/dev/null 2>&1 || fail "git_copy_clean failed"

[ -f "$dst/README.md" ] || fail "tracked file missing"
[ -f "$dst/src/app.sh" ] || fail "tracked file in subdir missing"
[ -L "$dst/link-to-readme" ] || fail "symlink not preserved as a symlink"
[ ! -e "$dst/ignored_dir" ] || fail "ignored directory was copied"
[ ! -e "$dst/nested/run.log" ] || fail "ignored file was copied"
[ ! -e "$dst/.git" ] || fail ".git copied without --with-git"
pass "tracked files in, ignored files out"

echo "3. Testing submodule contents..."
[ -f "$dst/vendor/sub/sub.txt" ] || fail "submodule tracked file missing"
[ -f "$dst/vendor/sub/.gitignore" ] || fail "submodule .gitignore missing"
[ ! -e "$dst/vendor/sub/sub-ignored" ] || fail "submodule ignored dir was copied"
pass "submodule files copied, its own ignores respected"

echo "4. Testing --with-git..."
printf 'untracked but visible\n' >"$src/NOTES.md"
git -C "$src" add NOTES.md
git -C "$src" commit -qm "notes"

dst_git="$workdir/dst-git"
git_copy_clean -g "$src" "$dst_git" >/dev/null 2>&1 || fail "git_copy_clean -g failed"

[ -f "$dst_git/NOTES.md" ] || fail "file from the latest commit missing"
[ -f "$dst_git/.git/HEAD" ] || fail ".git not copied"
[ -f "$dst_git/vendor/sub/.git" ] || fail "submodule .git gitfile not copied"
[ "$(git -C "$dst_git" rev-parse HEAD)" = "$(git -C "$src" rev-parse HEAD)" ] || fail "HEAD differs"
[ -z "$(git -C "$dst_git" status --porcelain)" ] || fail "copy has a dirty status"
pass "working checkout with clean status"

echo "5. Testing non-empty destination..."
if git_copy_clean "$src" "$dst_git" >/dev/null 2>&1; then
    fail "should refuse a non-empty destination without --force"
fi
pass "refuses non-empty destination"

echo "6. Testing destination inside source..."
if git_copy_clean "$src" "$src/clean" >/dev/null 2>&1; then
    fail "should refuse a destination inside the source"
fi
pass "refuses destination inside source"

echo ""
echo "✅ All git_copy_clean tests passed"
