# Releasing Bach

The same source archive installs on Linux and macOS. No architecture-specific
build, Python wheel, or Python runtime is needed for installation.

1. Update `VERSION` and run `make test`.
2. Run `make dist`. This creates `dist/bach-<version>.tar.gz`, its
   `.tar.gz.sha256` checksum file, and `dist/bach.rb`. The generated formula
   references the exact archive and checksum from that build.
3. Commit the changes, tag that commit as `v<version>`, and push the commit and
   tag. The release workflow runs the shared Linux/macOS tests, checks the tag
   against `VERSION`, builds the assets once, and uploads them to a draft GitHub
   release. Review the draft and publish it when ready.
4. Download `bach.rb` from that release and place it at `Formula/bach.rb` in
   your `homebrew-<tap>` repository. Use the formula shipped with the release;
   rebuilding the archive locally may produce a different checksum.
5. Test the actual formula with `brew install <owner>/<tap>/bach`,
   `brew test <owner>/<tap>/bach`, and `brew audit <owner>/<tap>/bach`, then
   commit and push the tap changes.

The template defaults to releases in `lamnguyenx/bach`. To build for another
repository, use `BACH_RELEASE_REPOSITORY=owner/repository make dist`; the release
workflow sets this to its own repository automatically. Local builds do not
publish anything. Tag pushes prepare draft releases; they do not publish the
release or update a tap. The workflow uses GitHub's built-in token, with write
permission limited to the release job.

For a manual release, upload the archive, checksum, and generated formula from
the same `make dist` invocation. Do not substitute GitHub's automatically
generated source archive, since it has a different checksum.

The repository currently has no license file. If a license is added, `make
dist` includes `LICENSE*` and `COPYING*` files automatically; add the matching
`license` declaration to the formula template as well.

## Installation contract

`make install PREFIX=/some/prefix DESTDIR=/staging` installs only:

- `/staging/some/prefix/bin/bach`
- `/staging/some/prefix/lib/bach/*`

`DESTDIR` is a packaging staging directory and is not embedded in the installed
files. Keep `PREFIX` absolute. The CLI resolves its modules relative to its
installation, including package-manager symlinks. `make uninstall` uses the
same variables and preserves user configuration. The prefix's Bach directories
are reserved for package files; do not put personal files there.

Installation never activates the shell. The user runs `bach init --write`
(or manages `eval "$(bach init)"` themselves) after installation. Package
upgrades replace files directly, with no per-user copy or synchronization step.


## Session record and current verification

The [packaging work log](../docs/plans/2026/11/10/2026-11-10-shell-packaging-and-release-migration.md)
records the migration, every touched shell module, failed trials, and lessons.
The [operational guide](../docs/important/how-installation-packaging-and-reload-work.md)
explains startup migration and installed-file reloads.

Archive/formula generation, staging/relocation, fork URL validation, Linux
regressions, ShellCheck/shfmt, and actionlint passed locally. macOS execution
and actual Homebrew formula installation/audit were not performed in this
session. No release or tap is published, and the changes remain uncommitted.
