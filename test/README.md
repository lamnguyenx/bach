# Test Scripts

This directory contains test scripts for the bach project.

## Available Tests

- `test_cross_platform.sh`: Tests cross-platform compatibility of shell scripts on macOS and Linux

## Running Tests

```bash
# Run cross-platform compatibility test
bash test/test_cross_platform.sh
```

## Adding New Tests

When adding new test scripts:
1. Place them in this `test/` directory
2. Follow the naming convention: `test_*.sh`
3. Include a header comment explaining what the test does
4. Make sure scripts are executable: `chmod +x test_script.sh`