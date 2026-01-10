# Agent Instructions for Bach Project

## Requirements
- **Cross-platform**: All code must work on both Linux and macOS

## Commands
- **Install**: `make install` or `make all`
- **Uninstall**: `make clean`
- **Lint**: `shellcheck --severity=error <file>`
- **Test all**: `bash test/test_cross_platform.sh`

## Code Style
See `coding_conventions/` for detailed style guidelines

- Shell scripts are formatted using `shfmt -i 4` (using 4 spaces for indentation). To format inplace, use `shfmt -i 4 -w`.
