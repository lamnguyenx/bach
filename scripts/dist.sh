#!/bin/bash
# ==============================================================
#                         BACH RELEASE
# ==============================================================
# Build a platform-independent source archive and checksum.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
version=$(cat VERSION)
case "$version" in
'' | *[!0-9A-Za-z.-]*)
    echo 'Invalid VERSION' >&2
    exit 1
    ;;
esac
release_repository=${BACH_RELEASE_REPOSITORY:-lamnguyenx/bach}
if [[ ! $release_repository =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo 'BACH_RELEASE_REPOSITORY must be owner/repository' >&2
    exit 1
fi
stage=$(mktemp -d "${TMPDIR:-/tmp}/bach-dist.XXXXXX")
trap 'rm -rf "$stage"' EXIT
name="bach-$version"
mkdir -p "$stage/$name" dist
cp -R bin lib scripts test docs coding_conventions packaging "$stage/$name/"
cp VERSION README.md Makefile setup.sh bach_lite.sh "$stage/$name/"
for license_file in LICENSE LICENSE.* COPYING COPYING.*; do
    [ ! -f "$license_file" ] || cp "$license_file" "$stage/$name/"
done
COPYFILE_DISABLE=1 tar -czf "dist/$name.tar.gz" -C "$stage" "$name"
cd dist
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$name.tar.gz" >"$name.tar.gz.sha256"
else
    shasum -a 256 "$name.tar.gz" >"$name.tar.gz.sha256"
fi
read -r checksum _ <"$name.tar.gz.sha256"
sed -e "s|@VERSION@|$version|g" \
    -e "s|@SHA256@|$checksum|g" \
    -e "s|@REPOSITORY@|$release_repository|g" \
    ../packaging/bach.rb.in >bach.rb
printf 'Created dist/%s.tar.gz, checksum, and dist/bach.rb\n' "$name"
