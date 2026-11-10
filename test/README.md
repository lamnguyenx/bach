# Test Scripts

This directory contains test scripts for the bach project.

## Available Tests

- `test_cross_platform.sh`: Tests cross-platform compatibility of shell scripts on macOS and Linux
- `test_git_copy_clean.sh`: Tests `git_copy_clean` (ignored files excluded, submodules, `--with-git`, destination guards)
- `test_config.sh`: Tests user configuration loading (shared `config.sh` + per-module `config-<module>.sh`, re-source before each command, `reload_bach`) and `BACH_JCO_MODEL` selection (single, multiple/menu, `-m` override). Runs fully sandboxed under a temporary `XDG_CONFIG_HOME` and a stub `opencode`; never touches the real user config.

## Running Tests

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