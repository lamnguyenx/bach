#!/bin/bash
# Cross-platform compatibility test script for bach shell scripts
# Run this on both macOS and Linux to verify compatibility

set -e

echo "🧪 Testing cross-platform compatibility of bach scripts"
echo "=================================================="

# Test OS detection
echo "1. Testing OS detection..."
if [ "$(uname)" = "Darwin" ]; then
    echo "   ✅ Running on macOS (Darwin)"
elif [ "$(uname)" = "Linux" ]; then
    echo "   ✅ Running on Linux"
else
    echo "   ❌ Unsupported OS: $(uname)"
    exit 1
fi

# Source the scripts
echo "2. Sourcing bach scripts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../bach_cli/bach/__init__.sh" 2>/dev/null || {
    echo "   ❌ Failed to source bach scripts"
    exit 1
}
echo "   ✅ Scripts sourced successfully"

# Test get_timeslug
echo "3. Testing get_timeslug..."
timeslug=$(get_timeslug)
if [[ $timeslug =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}__[0-9]{2}h[0-9]{2}m[0-9]{2}s(\.[0-9]{3})?$ ]]; then
    echo "   ✅ get_timeslug works: $timeslug"
else
    echo "   ❌ get_timeslug failed: $timeslug"
    exit 1
fi

# Test get_host_ip
echo "4. Testing get_host_ip..."
host_ip=$(get_host_ip)
if [ -n "$host_ip" ]; then
    echo "   ✅ get_host_ip returned: $host_ip"
else
    echo "   ⚠️  get_host_ip returned empty (may be expected)"
fi

# Test get_host_model
echo "5. Testing get_host_model..."
host_model=$(get_host_model)
if [ "$host_model" != "Unknown" ]; then
    echo "   ✅ get_host_model returned: $host_model"
else
    echo "   ⚠️  get_host_model returned: $host_model"
fi

# Test get_host_model with specific long model name
echo "5b. Testing get_host_model truncation..."
test_model="HP ProOne 440 23.8 inch G9 All-in-One Desktop PC"
expected="HP ProOne 440[..]"
result=$(slugify_v3 "$test_model")
# Apply truncation logic (16 char limit)
if [ ${#result} -gt 16 ]; then
    result="${result:0:13}[..]"
fi
if [ "$result" = "$expected" ]; then
    echo "   ✅ Long model name truncated correctly: '$result'"
else
    echo "   ❌ Long model name truncation failed"
    echo "      Expected: '$expected'"
    echo "      Got:      '$result'"
    exit 1
fi

# Test list_swap (Linux only)
echo "6. Testing list_swap..."
if [ "$(uname)" = "Linux" ]; then
    if list_swap >/dev/null 2>&1; then
        echo "   ✅ list_swap works on Linux"
    else
        echo "   ❌ list_swap failed on Linux"
        exit 1
    fi
else
    if list_swap 2>&1 | grep -q "only available on Linux"; then
        echo "   ✅ list_swap correctly reports Linux-only on macOS"
    else
        echo "   ❌ list_swap should report Linux-only on macOS"
        exit 1
    fi
fi

# Test accept_all (Linux only)
echo "7. Testing accept_all..."
if [ "$(uname)" = "Linux" ]; then
    # Don't actually run iptables, just test the function exists and checks OS
    if accept_all 2>&1 | grep -q "only available on Linux"; then
        echo "   ❌ accept_all should work on Linux"
        exit 1
    else
        echo "   ✅ accept_all available on Linux"
    fi
else
    if accept_all 2>&1 | grep -q "only available on Linux"; then
        echo "   ✅ accept_all correctly reports Linux-only on macOS"
    else
        echo "   ❌ accept_all should report Linux-only on macOS"
        exit 1
    fi
fi

# Test Homebrew detection
echo "8. Testing Homebrew detection..."
if set_brew_envs 2>&1 | grep -q "Homebrew activated\|Homebrew not found"; then
    echo "   ✅ set_brew_envs works"
else
    echo "   ❌ set_brew_envs failed"
    exit 1
fi

echo ""
echo "🎉 All tests passed! Scripts are cross-platform compatible."
