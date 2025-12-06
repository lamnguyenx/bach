# Cross-Platform Shell Scripts Implementation Plan

## Overview

Ensure all shell scripts in the bach project work on both macOS and Linux by addressing platform-specific differences in commands, paths, and system interfaces. The scripts currently have several BSD (macOS) vs GNU (Linux) incompatibilities that need to be resolved.

## Current State Analysis

The codebase contains 11 shell scripts with various platform-specific issues:
- `sed` command syntax differences (in-place editing)
- `date` command format specifiers (nanoseconds)
- Networking commands (`ipconfig` vs `hostname`)
- System information retrieval (`sysctl` vs `/proc`)
- Firewall commands (`iptables` Linux-only)
- File system paths (`/proc` Linux-only)
- Audio commands (platform-specific)
- Homebrew installation paths

## Desired End State

All shell scripts execute successfully on both macOS (Darwin) and Linux systems without platform-specific errors. Scripts detect the operating system using `uname` and adapt commands accordingly.

### Key Discoveries:
- macOS uses BSD tools with different flags and behaviors than GNU tools on Linux
- Critical issues in `setup.sh` (sed syntax) and `common.sh` (multiple commands)
- Audio notifications already have cross-platform detection but need verification
- Homebrew paths differ between macOS and Linux installations

## What We're NOT Doing

- Changing the overall functionality or user interface of the scripts
- Adding new features or dependencies beyond what's needed for compatibility
- Supporting non-Unix-like systems (Windows, etc.)
- Modifying existing working cross-platform code

## Implementation Approach

Use `uname` to detect the operating system and create wrapper functions or conditional logic for platform-specific commands. Prioritize fixes based on impact and usage frequency.

## Phase 1: Critical Command Fixes

### Overview
Fix the most critical platform differences that prevent scripts from running at all.

### Changes Required:

#### 1. Fix sed -i syntax in setup.sh
**File**: `setup.sh`
**Changes**: Replace BSD sed syntax with cross-platform approach using backup files.

```bash
# Before (macOS-specific)
sed -i '.bak' '/pattern/d' ~/.bashrc

# After (cross-platform)
sed -i.bak '/pattern/d' ~/.bashrc && rm ~/.bashrc.bak 2>/dev/null || true
```

#### 2. Fix date nanoseconds in common.sh and bach_lite.sh
**File**: `src/bach/common.sh:32`, `bach_lite.sh:19`
**Changes**: Remove %3N specifier or provide fallback for macOS.

```bash
# Before
date +"%Y.%m.%d__%Hh%Mm%Ss.%3N"

# After (remove nanoseconds for compatibility)
date +"%Y.%m.%d__%Hh%Mm%Ss"
```

### Success Criteria:

#### Automated Verification:
- [ ] setup.sh runs without sed errors on both platforms
- [ ] date commands execute without format errors
- [ ] Scripts can be sourced without syntax errors

#### Manual Verification:
- [ ] setup.sh install/uninstall works on macOS
- [ ] setup.sh install/uninstall works on Linux
- [ ] Date formatting produces consistent output format

## Phase 2: Networking and System Info

### Overview
Make networking and system information retrieval cross-platform.

### Changes Required:

#### 1. Cross-platform host IP detection
**File**: `src/bach/common.sh:16-22`
**Changes**: Improve networking command detection.

```bash
function get_host_ip() {
    if [ "$(uname)" = "Darwin" ]; then
        # macOS: try multiple interfaces
        ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo ""
    else
        # Linux: use hostname -I
        hostname -I 2>/dev/null | awk '{print $1}' || echo ""
    fi
}
```

#### 2. Cross-platform host model detection
**File**: `src/bach/common.sh:24-30`
**Changes**: Add error handling for missing sysctl.

```bash
function get_host_model() {
    if [ "$(uname)" = "Darwin" ]; then
        sysctl -n hw.model 2>/dev/null || echo "Unknown"
    else
        cat /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown"
    fi
}
```

### Success Criteria:

#### Automated Verification:
- [ ] get_host_ip returns valid IP or empty string on both platforms
- [ ] get_host_model returns model info or "Unknown" on both platforms

#### Manual Verification:
- [ ] HOST_IP and HOST_MODEL variables set correctly on macOS
- [ ] HOST_IP and HOST_MODEL variables set correctly on Linux

## Phase 3: Utility Functions and Commands

### Overview
Fix remaining utility functions and commands for full compatibility.

### Changes Required:

#### 1. Make list_swap Linux-only with warning
**File**: `src/bach/common.sh:200-206`
**Changes**: Add OS check and skip on macOS.

```bash
function list_swap(){
    if [ "$(uname)" != "Linux" ]; then
        echo "list_swap is only available on Linux systems"
        return 1
    fi
    # ... existing code
}
```

#### 2. Make accept_all Linux-only
**File**: `src/bach/common.sh:192-198`
**Changes**: Add OS check for iptables.

```bash
function accept_all(){
    if [ "$(uname)" != "Linux" ]; then
        echo "accept_all (iptables) is only available on Linux systems"
        return 1
    fi
    # ... existing code
}
```

#### 3. Fix sort and tac commands
**File**: `src/bach/common.sh:201-205`
**Changes**: Replace GNU-specific options.

```bash
# Replace sort -h with sort -n for numeric sorting
# Replace tac with tail -r or sed '1!G;h;$!d'
```

#### 4. Update Homebrew paths
**File**: `src/bach/homebrew.sh:8`
**Changes**: Detect Homebrew installation path.

```bash
function set_brew_envs() {
    local brew_path=""
    if [ "$(uname)" = "Darwin" ]; then
        brew_path="/usr/local/bin/brew"  # Intel macOS
        [ -f "/opt/homebrew/bin/brew" ] && brew_path="/opt/homebrew/bin/brew"  # Apple Silicon
    else
        brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
    fi
    
    if [ -f "$brew_path" ]; then
        eval "$("$brew_path" shellenv)"
        echo "✅ Homebrew activated"
    else
        echo "❌ Homebrew not found at $brew_path"
        return 1
    fi
}
```

### Success Criteria:

#### Automated Verification:
- [ ] list_swap and accept_all functions don't error on macOS
- [ ] Homebrew activation works on both platforms
- [ ] All scripts source without errors

#### Manual Verification:
- [ ] Audio notifications work on macOS (afplay)
- [ ] Audio notifications work on Linux (paplay/aplay)
- [ ] Docker operations work on both platforms

## Phase 4: Testing and Validation

### Overview
Test all changes on both platforms to ensure compatibility.

### Changes Required:

#### 1. Create test script
**File**: `test_cross_platform.sh` (new)
**Changes**: Test script that validates all functions work on current platform.

### Success Criteria:

#### Automated Verification:
- [ ] Test script passes on macOS
- [ ] Test script passes on Linux
- [ ] All scripts can be sourced without errors

#### Manual Verification:
- [ ] Full bach setup works on macOS
- [ ] Full bach setup works on Linux
- [ ] All functions behave as expected on both platforms

## Testing Strategy

### Unit Tests:
- Test each modified function individually
- Verify OS detection works correctly
- Check error handling for unsupported operations

### Integration Tests:
- Source all scripts and verify no errors
- Run setup.sh install/uninstall cycle
- Test common functions like get_host_ip

### Manual Testing Steps:
1. On macOS: Source scripts, run setup, test functions
2. On Linux: Source scripts, run setup, test functions
3. Verify audio notifications work
4. Test Docker operations if Docker is available

## Performance Considerations

- OS detection using `uname` is fast and cached
- Fallback commands add minimal overhead
- No performance impact on working platform

## Migration Notes

- Existing installations will continue to work
- No data migration needed
- Scripts are backward compatible

## References

- macOS vs Linux shell differences research
- BSD vs GNU command incompatibilities
- Homebrew installation documentation</content>
<parameter name="filePath">docs/plans/2025-12-06-cross-platform-shell-scripts.md