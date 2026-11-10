# Bach operational documentation

- [Installation, packaging, activation, and reload](how-installation-packaging-and-reload-work.md): file ownership, migration, stale startup paths, reload troubleshooting, releases, and uninstall.
- [Configuration loading](how-config-loading-works.md): shared/per-module settings, reload semantics, jco model selection, and stale function troubleshooting.
- [Manual audio test](how-test-test-audio.md): microphone forwarding with real devices and a remote host.
- [Manual video test](how-test-test-video.md): camera forwarding with real devices and a remote host.

The audio/video guides use shell-script format despite their `.md` extension;
read them and adapt the target host before running their commands. Automated
packaging/reload checks do not substitute for these hardware tests.

Dated trials, errors, verification, and lessons live under
[docs/plans/](../plans/), including the
[2026-11-10 packaging work](../plans/2026/11/10/2026-11-10-shell-packaging-and-release-migration.md)
and [reload fixes](../plans/2026/11/10/2026-11-10-reliable-bash-reload.md).
