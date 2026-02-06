#!/bin/bash
#
# check-localization.sh
# VibeCap Localization Integrity Check
#
# This script validates that all localization files are complete and consistent.
# It's designed to be run as part of the build process (build.sh) as a hard gate.
#
# Exit codes:
#   0 - All checks passed
#   1 - Missing keys or languages detected
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCES_DIR="${1:-VibeCapture/Resources}"
BASE_LANGUAGE="en"
REQUIRED_LANGUAGES=(
    "en" "zh-Hans" "zh-Hant" "ja" "de" "fr" "es" "ko" "it" "sv"
)

echo "========================================"
echo "  VibeCap Localization Integrity Check"
echo "========================================"
echo ""

# Track errors
ERRORS=0
WARNINGS=0

# Function to extract keys from a .strings file
extract_keys() {
    local file="$1"
    # Extract keys from "key" = "value"; format, handling multiline values
    grep -E '^"[^"]+"\s*=' "$file" 2>/dev/null | sed 's/"\([^"]*\)".*/\1/' | sort
}

# Function to count keys
count_keys() {
    local file="$1"
    extract_keys "$file" | wc -l | tr -d ' '
}

# Step 1: Check that base language exists
echo "Step 1: Checking base language ($BASE_LANGUAGE)..."
BASE_FILE="$RESOURCES_DIR/$BASE_LANGUAGE.lproj/Localizable.strings"

if [[ ! -f "$BASE_FILE" ]]; then
    echo -e "${RED}ERROR: Base language file not found: $BASE_FILE${NC}"
    exit 1
fi

BASE_KEYS=$(extract_keys "$BASE_FILE")
BASE_KEY_COUNT=$(echo "$BASE_KEYS" | grep -c . || echo 0)
echo -e "${GREEN}✓ Base language ($BASE_LANGUAGE) has $BASE_KEY_COUNT keys${NC}"
echo ""

# Step 2: Check all required languages exist
echo "Step 2: Checking required languages..."
MISSING_LANGUAGES=()

for lang in "${REQUIRED_LANGUAGES[@]}"; do
    LANG_FILE="$RESOURCES_DIR/$lang.lproj/Localizable.strings"
    if [[ ! -f "$LANG_FILE" ]]; then
        MISSING_LANGUAGES+=("$lang")
        echo -e "${RED}✗ Missing: $lang.lproj/Localizable.strings${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ Found: $lang.lproj/Localizable.strings${NC}"
    fi
done

echo ""

# Step 3: Check key consistency across all languages
echo "Step 3: Checking key consistency..."

for lang in "${REQUIRED_LANGUAGES[@]}"; do
    LANG_FILE="$RESOURCES_DIR/$lang.lproj/Localizable.strings"
    
    if [[ ! -f "$LANG_FILE" ]]; then
        continue
    fi
    
    LANG_KEYS=$(extract_keys "$LANG_FILE")
    # grep -c prints 0 but exits 1 when there are no matches; avoid duplicating output with "|| echo 0"
    LANG_KEY_COUNT=$(echo "$LANG_KEYS" | grep -c . 2>/dev/null || true)
    
    # Find missing keys (in base but not in this language)
    MISSING_KEYS=$(comm -23 <(echo "$BASE_KEYS") <(echo "$LANG_KEYS") 2>/dev/null || true)
    MISSING_COUNT=$(echo "$MISSING_KEYS" | grep -c . 2>/dev/null || true)
    
    # Find extra keys (in this language but not in base)
    EXTRA_KEYS=$(comm -13 <(echo "$BASE_KEYS") <(echo "$LANG_KEYS") 2>/dev/null || true)
    EXTRA_COUNT=$(echo "$EXTRA_KEYS" | grep -c . 2>/dev/null || true)
    
    if [[ "$MISSING_COUNT" -gt 0 ]]; then
        echo -e "${RED}✗ $lang: Missing $MISSING_COUNT keys${NC}"
        echo "  Missing keys:"
        echo "$MISSING_KEYS" | head -10 | sed 's/^/    - /'
        if [[ "$MISSING_COUNT" -gt 10 ]]; then
            echo "    ... and $((MISSING_COUNT - 10)) more"
        fi
        ((ERRORS++))
    elif [[ "$EXTRA_COUNT" -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $lang: Has $EXTRA_COUNT extra keys (not in base)${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓ $lang: All $LANG_KEY_COUNT keys present${NC}"
    fi
done

echo ""

# Step 4: Check for empty values
echo "Step 4: Checking for empty values..."

for lang in "${REQUIRED_LANGUAGES[@]}"; do
    LANG_FILE="$RESOURCES_DIR/$lang.lproj/Localizable.strings"
    
    if [[ ! -f "$LANG_FILE" ]]; then
        continue
    fi
    
    # Find lines with empty values: "key" = "";
    EMPTY_VALUES=$(grep -E '^"[^"]+"\s*=\s*""\s*;' "$LANG_FILE" 2>/dev/null || true)
    EMPTY_COUNT=$(echo "$EMPTY_VALUES" | grep -c . 2>/dev/null || true)
    
    if [[ "$EMPTY_COUNT" -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $lang: Has $EMPTY_COUNT empty values${NC}"
        ((WARNINGS++))
    fi
done

echo ""

# Step 5: Check for format specifier consistency
echo "Step 5: Checking format specifier consistency..."

# Extract keys with format specifiers from base
KEYS_WITH_SPECIFIERS=$(grep -E '%[@difs]' "$BASE_FILE" 2>/dev/null | sed 's/"\([^"]*\)".*/\1/' | sort -u || true)

for lang in "${REQUIRED_LANGUAGES[@]}"; do
    if [[ "$lang" == "$BASE_LANGUAGE" ]]; then
        continue
    fi
    
    LANG_FILE="$RESOURCES_DIR/$lang.lproj/Localizable.strings"
    
    if [[ ! -f "$LANG_FILE" ]]; then
        continue
    fi
    
    SPECIFIER_ERRORS=0
    
    for key in $KEYS_WITH_SPECIFIERS; do
        # Get base value
        BASE_VALUE=$(grep "^\"$key\"" "$BASE_FILE" 2>/dev/null | sed 's/.*=\s*"\(.*\)";/\1/' || true)
        # Get lang value  
        LANG_VALUE=$(grep "^\"$key\"" "$LANG_FILE" 2>/dev/null | sed 's/.*=\s*"\(.*\)";/\1/' || true)
        
        if [[ -n "$BASE_VALUE" && -n "$LANG_VALUE" ]]; then
            # Count specifiers
            BASE_SPEC_COUNT=$(echo "$BASE_VALUE" | grep -o '%[@difs]' | wc -l | tr -d ' ')
            LANG_SPEC_COUNT=$(echo "$LANG_VALUE" | grep -o '%[@difs]' | wc -l | tr -d ' ')
            
            if [[ "$BASE_SPEC_COUNT" != "$LANG_SPEC_COUNT" ]]; then
                if [[ $SPECIFIER_ERRORS -eq 0 ]]; then
                    echo -e "${RED}✗ $lang: Format specifier mismatch${NC}"
                fi
                echo "    - $key: expected $BASE_SPEC_COUNT specifiers, got $LANG_SPEC_COUNT"
                ((SPECIFIER_ERRORS++))
                ((ERRORS++))
            fi
        fi
    done
    
    if [[ $SPECIFIER_ERRORS -eq 0 ]]; then
        echo -e "${GREEN}✓ $lang: Format specifiers OK${NC}"
    fi
done

echo ""

# Summary
echo "========================================"
echo "  Summary"
echo "========================================"
echo "Languages checked: ${#REQUIRED_LANGUAGES[@]}"
echo "Base keys: $BASE_KEY_COUNT"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}========================================"
    echo "  BUILD FAILED: Localization errors"
    echo "========================================${NC}"
    echo ""
    echo "Fix the above errors before building."
    echo "All languages must have all keys from the base language ($BASE_LANGUAGE)."
    exit 1
fi

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Build passed with warnings.${NC}"
else
    echo -e "${GREEN}All localization checks passed!${NC}"
fi

exit 0
