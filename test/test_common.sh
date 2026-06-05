#!/bin/bash
# Test script for common.sh functions
# Tests slugify, slugify_v2, and slugify_v3 functions

set -e

echo "🧪 Testing common.sh functions"
echo "=============================="

# Source the scripts
echo "1. Sourcing bach scripts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../bach_cli/bach/__init__.sh" 2>/dev/null || {
    echo "   ❌ Failed to source bach scripts"
    exit 1
}
echo "   ✅ Scripts sourced successfully"

passed=0
failed=0

# Test function
test_slugify_func() {
    local func_name="$1"
    local input="$2"
    local expected="$3"
    local result=$($func_name "$input")

    if [ "$result" = "$expected" ]; then
        echo "   ✅ '$input' -> '$result'"
        passed=$((passed + 1))
    else
        echo "   ❌ $func_name('$input')"
        echo "      Expected: '$expected'"
        echo "      Got:      '$result'"
        failed=$((failed + 1))
    fi
}

# Test slugify
echo "2. Testing slugify..."

test_slugify_func slugify "    This -- is a ## test ---        " "this-is-a-test-"
test_slugify_func slugify "    This is a test ---              " "this-is-a-test-"
test_slugify_func slugify "    ___This is a test ---           " "___this-is-a-test-"
test_slugify_func slugify "    ___This is a test___            " "___this-is-a-test___"
test_slugify_func slugify "    &#381;                          " "381"
test_slugify_func slugify "    &#x17D;                         " "x17d"
test_slugify_func slugify "    1,000 reasons you are #1        " "1000-reasons-you-are-1"
test_slugify_func slugify "    10 amazing secrets              " "10-amazing-secrets"
test_slugify_func slugify "    10 | 20 %                       " "10-20"
test_slugify_func slugify "    404                             " "404"
test_slugify_func slugify "    C'est déjà l'été.wav            " "cest-dj-ltwav"
test_slugify_func slugify "    Foo A FOO B foo C               " "foo-a-foo-b-foo-c"
test_slugify_func slugify "    I ♥ 🦄                          " "i"
test_slugify_func slugify "    Nín hǎo. Wǒ shì zhōng guó rén   " "nn-ho-w-sh-zhng-gu-rn"
test_slugify_func slugify "    buildings with 1000 windows     " "buildings-with-1000-windows"
test_slugify_func slugify "    foo &amp; bår                   " "foo-amp-br"
test_slugify_func slugify "    i love you                      " "i-love-you"
test_slugify_func slugify "    i love 🦄                       " "i-love"
test_slugify_func slugify "    jaja---lol-méméméoo--a          " "jaja-lol-mmmoo-a"
test_slugify_func slugify "    one two three four five         " "one-two-three-four-five"
test_slugify_func slugify "    recipe number 3                 " "recipe-number-3"
test_slugify_func slugify "    thIs Has a stopword Stopword    " "this-has-a-stopword-stopword"
test_slugify_func slugify "    thIs Has a öländ länd           " "this-has-a-lnd-lnd"
test_slugify_func slugify "    the quick brown fox jumps over  " "the-quick-brown-fox-jumps-over"
test_slugify_func slugify "    this has a Öländ                " "this-has-a-lnd"
test_slugify_func slugify "    ÜBER Über German Umlaut         " "ber-ber-german-umlaut"
test_slugify_func slugify "    Компьютер                       " ""
test_slugify_func slugify "    دو سه چهار پنج                  " ""
test_slugify_func slugify "    ,۰۰۰ reasons you are #۱         " "reasons-you-are"
test_slugify_func slugify "    影師嗎                           " ""

# Test slugify_v2
echo "3. Testing slugify_v2..."

test_slugify_func slugify_v2 "    This -- is a ## test ---        " "This-is-a-test-"
test_slugify_func slugify_v2 "    This is a test ---              " "This-is-a-test-"
test_slugify_func slugify_v2 "    ___This is a test ---           " "___This-is-a-test-"
test_slugify_func slugify_v2 "    ___This is a test___            " "___This-is-a-test___"
test_slugify_func slugify_v2 "    &#381;                          " "381"
test_slugify_func slugify_v2 "    &#x17D;                         " "x17D"
test_slugify_func slugify_v2 "    1,000 reasons you are #1        " "1000-reasons-you-are-1"
test_slugify_func slugify_v2 "    10 amazing secrets              " "10-amazing-secrets"
test_slugify_func slugify_v2 "    10 | 20 %                       " "10-20"
test_slugify_func slugify_v2 "    404                             " "404"
test_slugify_func slugify_v2 "    C'est déjà l'été.wav            " "Cest-dj-lt.wav"
test_slugify_func slugify_v2 "    Foo A FOO B foo C               " "Foo-A-FOO-B-foo-C"
test_slugify_func slugify_v2 "    I ♥ 🦄                          " "I"
test_slugify_func slugify_v2 "    Nín hǎo. Wǒ shì zhōng guó rén   " "Nn-ho.-W-sh-zhng-gu-rn"
test_slugify_func slugify_v2 "    buildings with 1000 windows     " "buildings-with-1000-windows"
test_slugify_func slugify_v2 "    foo &amp; bår                   " "foo-amp-br"
test_slugify_func slugify_v2 "    i love you                      " "i-love-you"
test_slugify_func slugify_v2 "    i love 🦄                       " "i-love"
test_slugify_func slugify_v2 "    jaja---lol-méméméoo--a          " "jaja-lol-mmmoo-a"
test_slugify_func slugify_v2 "    one two three four five         " "one-two-three-four-five"
test_slugify_func slugify_v2 "    recipe number 3                 " "recipe-number-3"
test_slugify_func slugify_v2 "    thIs Has a stopword Stopword    " "thIs-Has-a-stopword-Stopword"
test_slugify_func slugify_v2 "    thIs Has a öländ länd           " "thIs-Has-a-lnd-lnd"
test_slugify_func slugify_v2 "    the quick brown fox jumps over  " "the-quick-brown-fox-jumps-over"
test_slugify_func slugify_v2 "    this has a Öländ                " "this-has-a-lnd"
test_slugify_func slugify_v2 "    ÜBER Über German Umlaut         " "BER-ber-German-Umlaut"
test_slugify_func slugify_v2 "    Компьютер                       " ""
test_slugify_func slugify_v2 "    دو سه چهار پنج                  " ""
test_slugify_func slugify_v2 "    ,۰۰۰ reasons you are #۱         " "reasons-you-are"
test_slugify_func slugify_v2 "    影師嗎                           " ""

# Test slugify_v3
echo "4. Testing slugify_v3..."

# Test cases based on Python slugify_v3 examples
test_slugify_func slugify_v3 "    This -- is a ## test ---        " "This -- is a  test ---"
test_slugify_func slugify_v3 "    This is a test ---              " "This is a test ---"
test_slugify_func slugify_v3 "    ___This is a test ---           " "___This is a test ---"
test_slugify_func slugify_v3 "    ___This is a test___            " "___This is a test___"
test_slugify_func slugify_v3 "    &#381;                          " "381"
test_slugify_func slugify_v3 "    &#x17D;                         " "x17D"
test_slugify_func slugify_v3 "    1,000 reasons you are #1        " "1000 reasons you are 1"
test_slugify_func slugify_v3 "    10 amazing secrets              " "10 amazing secrets"
test_slugify_func slugify_v3 "    10 | 20 %                       " "10  20"
test_slugify_func slugify_v3 "    404                             " "404"
test_slugify_func slugify_v3 "    C'est déjà l'été.wav            " "Cest dj lt.wav"
test_slugify_func slugify_v3 "    Foo A FOO B foo C               " "Foo A FOO B foo C"
test_slugify_func slugify_v3 "    I ♥ 🦄                          " "I"
test_slugify_func slugify_v3 "    Nín hǎo. Wǒ shì zhōng guó rén   " "Nn ho. W sh zhng gu rn"
test_slugify_func slugify_v3 "    buildings with 1000 windows     " "buildings with 1000 windows"
test_slugify_func slugify_v3 "    foo &amp; bår                   " "foo amp br"
test_slugify_func slugify_v3 "    i love you                      " "i love you"
test_slugify_func slugify_v3 "    i love 🦄                       " "i love"
test_slugify_func slugify_v3 "    jaja---lol-méméméoo--a          " "jaja---lol-mmmoo--a"
test_slugify_func slugify_v3 "    one two three four five         " "one two three four five"
test_slugify_func slugify_v3 "    recipe number 3                 " "recipe number 3"
test_slugify_func slugify_v3 "    thIs Has a stopword Stopword    " "thIs Has a stopword Stopword"
test_slugify_func slugify_v3 "    thIs Has a öländ länd           " "thIs Has a lnd lnd"
test_slugify_func slugify_v3 "    the quick brown fox jumps over  " "the quick brown fox jumps over"
test_slugify_func slugify_v3 "    this has a Öländ                " "this has a lnd"
test_slugify_func slugify_v3 "    ÜBER Über German Umlaut         " "BER ber German Umlaut"
test_slugify_func slugify_v3 "    Компьютер                       " ""
test_slugify_func slugify_v3 "    دو سه چهار پنج                  " ""
test_slugify_func slugify_v3 "    ,۰۰۰ reasons you are #۱         " "reasons you are"
test_slugify_func slugify_v3 "    影師嗎                           " ""

echo ""
echo "Results: $passed passed, $failed failed"

if [ $failed -gt 0 ]; then
    echo "❌ Some tests failed"
    exit 1
else
    echo "🎉 All tests passed!"
fi
