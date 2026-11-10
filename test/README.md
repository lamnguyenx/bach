# Test Scripts

This directory contains test scripts for the bach project.

## Available Tests

- `test_reload.sh`: Reload from a relative source after changing directories, refreshed functions and module lists, load failure reporting, config refresh, child shells, and Readline isolation. Uses temporary fixtures.

- `test_packaging.sh`: Isolated installation, activation, migration from the Python block, symlink resolution, staged installs, release archives, and uninstallation.

- `test_cross_platform.sh`: Tests cross-platform compatibility of shell scripts on macOS and Linux
- `test_git_copy_clean.sh`: Tests `git_copy_clean` (ignored files excluded, submodules, `--with-git`, destination guards)
- `test_config.sh`: Tests user configuration loading (shared `config.sh` + per-module `config-<module>.sh`, re-source before each command, `reload_bach`) and `BACH_JCO_MODEL` selection (single, multiple/menu, `-m` override). Runs fully sandboxed under a temporary `XDG_CONFIG_HOME` and a stub `opencode`; never touches the real user config.

## Running Tests

```bash
# Complete suite, including reload and packaging regressions
make test

# New suites individually
bash test/test_reload.sh
bash test/test_packaging.sh
```

The reload suite uses stub modules/configuration in a temporary tree. The
packaging suite creates temporary prefixes and startup files and also generates
ignored `dist/` release artifacts in the checkout. Its malformed-marker and
invalid-repository cases intentionally emit errors; the suite checks that they
fail correctly. The Linux cross-platform suite checks `accept_all` availability
without executing `sudo iptables`.

The complete suite passed on Linux during this session, including all 90
common-function assertions. The shared CI workflow runs Linux and macOS;
macOS execution was not observed locally. Manual audio/video checks remain
separate and were not performed.

```bash
# Run cross-platform compatibility test
bash test/test_cross_platform.sh

# Run configuration loading / model selection tests
bash test/test_config.sh
```

## Adding New Tests

When adding new test scripts:
1. Place them in this `test/` directory
2. Follow the naming convention: `test_*.sh`
3. Include a header comment explaining what the test does
4. Make sure scripts are executable: `chmod +x test_script.sh`

## Implementation records

- [Packaging migration, trials, errors, and lessons](../docs/plans/2026/11/10/2026-11-10-shell-packaging-and-release-migration.md)
- [Reload reproduction, regression coverage, and lessons](../docs/plans/2026/11/10/2026-11-10-reliable-bash-reload.md)
- [Installation and reload operational reference](../docs/important/how-installation-packaging-and-reload-work.md)
