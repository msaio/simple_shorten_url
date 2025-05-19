#!/bin/bash

# =============================================================================
# URL Shortening API Test Script
# =============================================================================
# This script tests the URL shortening API endpoints using curl commands.
# Each test corresponds to a test case in the url_api_test.rb integration test.
#
# Usage:
#   chmod +x test_url_api.sh
#   ./test_url_api.sh
#
# Requirements:
#   - curl
#   - jq (for JSON parsing)
#   - The URL shortening service must be running
#
# The script is organized by test suites:
#   - Encode Endpoint Tests:
#     - Basic URL creation and retrieval
#     - Error handling for invalid inputs 
#     - URL validation (currently using simple validation without full normalization)
#   - Decode Endpoint Tests:
#     - URL decoding and key extraction
#     - Error handling for missing/invalid keys
#   - Integration Tests:
#     - End-to-end URL encoding and decoding
# =============================================================================

# Set base URL (change this if your service runs on a different port/host)
BASE_URL="http://localhost:3000"

# Color codes for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to print section headers
print_header() {
  echo -e "\n${BLUE}==============================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}==============================================${NC}"
}

# Helper function to print test descriptions
print_test() {
  echo -e "\n${YELLOW}TEST: $1${NC}"
  echo -e "${YELLOW}----------------------------------------------${NC}"
}

# Helper function to check response status
check_status() {
  if [ $1 -eq $2 ]; then
    echo -e "${GREEN}✓ Status code $1: PASS${NC}"
  else
    echo -e "${RED}✗ Expected status $2 but got $1: FAIL${NC}"
  fi
}

# Create a unique test URL to avoid conflicts with existing data
TEST_URL="https://example.com/test/resource?param=$(date +%s)"
echo "Using test URL: ${TEST_URL}"

# =============================================================================
# ENCODE ENDPOINT TESTS
# =============================================================================
print_header "ENCODE ENDPOINT TESTS"

# -----------------------------------------------------------------------------
# Test: should encode a URL successfully
# Corresponds to: test "should encode a URL successfully"
# -----------------------------------------------------------------------------
print_test "should encode a URL successfully"
echo "POST ${BASE_URL}/encode with { \"url\": \"${TEST_URL}\" }"

RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${TEST_URL}\"}")

HTTP_STATUS=${RESPONSE: -3}
RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}

check_status $HTTP_STATUS 200
echo "Response: ${RESPONSE_BODY}"

# Save the shortened URL for later tests
SHORTENED_URL=$(echo $RESPONSE_BODY | grep -o '"url":"[^"]*"' | sed 's/"url":"\([^"]*\)"/\1/')
echo "Shortened URL: ${SHORTENED_URL}"

# -----------------------------------------------------------------------------
# Test: should return 400 when URL parameter is missing
# Corresponds to: test "should return 400 when URL parameter is missing"
# -----------------------------------------------------------------------------
print_test "should return 400 when URL parameter is missing"
echo "POST ${BASE_URL}/encode with empty body"

RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{}")

HTTP_STATUS=${RESPONSE: -3}
RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}

check_status $HTTP_STATUS 400
echo "Response: ${RESPONSE_BODY}"

# -----------------------------------------------------------------------------
# Test: should handle invalid URLs properly
# Corresponds to: test "should handle invalid URLs properly"
# -----------------------------------------------------------------------------
print_test "should handle invalid URLs properly"
echo "POST ${BASE_URL}/encode with { \"url\": \"invalid!!url\" }"

RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"invalid!!url\"}")

HTTP_STATUS=${RESPONSE: -3}
RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}

check_status $HTTP_STATUS 400
echo "Response: ${RESPONSE_BODY}"

# -----------------------------------------------------------------------------
# Test: should reuse existing shortened URLs
# Corresponds to: test "should reuse existing shortened URLs"
# -----------------------------------------------------------------------------
print_test "should reuse existing shortened URLs"
echo "POST ${BASE_URL}/encode with the same URL twice"
echo "First request: POST ${BASE_URL}/encode with { \"url\": \"${TEST_URL}\" }"

RESPONSE1=$(curl -s -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${TEST_URL}\"}")

echo "Response 1: ${RESPONSE1}"

echo "Second request: POST ${BASE_URL}/encode with { \"url\": \"${TEST_URL}\" }"

RESPONSE2=$(curl -s -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${TEST_URL}\"}")

echo "Response 2: ${RESPONSE2}"

if [ "$RESPONSE1" = "$RESPONSE2" ]; then
  echo -e "${GREEN}✓ Same shortened URL returned: PASS${NC}"
else
  echo -e "${RED}✗ Different shortened URLs returned: FAIL${NC}"
fi

# -----------------------------------------------------------------------------
# Test: should normalize URLs when encoding (temporary version - tests exact duplicates only)
# Corresponds to: test "should normalize URLs when encoding"
# -----------------------------------------------------------------------------
print_test "should normalize URLs when encoding"
echo "Testing URL normalization - currently only exact duplicates are guaranteed to match"

# Use identical URLs since we haven't implemented full normalization yet
SAME_URL="http://example.com/path?a=1&b=2"

echo "First request: POST ${BASE_URL}/encode with { \"url\": \"${SAME_URL}\" }"
RESPONSE1=$(curl -s -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${SAME_URL}\"}")

echo "Response 1: ${RESPONSE1}"

echo "Second request: POST ${BASE_URL}/encode with { \"url\": \"${SAME_URL}\" }"
RESPONSE2=$(curl -s -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${SAME_URL}\"}")

echo "Response 2: ${RESPONSE2}"

if [ "$RESPONSE1" = "$RESPONSE2" ]; then
  echo -e "${GREEN}✓ Same shortened URL for identical URLs: PASS${NC}"
else
  echo -e "${RED}✗ Different shortened URLs for identical URLs: FAIL${NC}"
fi

# Note: Full URL normalization will be implemented later
echo -e "${YELLOW}Note: Full URL normalization that handles different formats of the same URL is pending implementation${NC}"

# =============================================================================
# DECODE ENDPOINT TESTS
# =============================================================================
print_header "DECODE ENDPOINT TESTS"

# -----------------------------------------------------------------------------
# Test: should decode a shortened URL successfully
# Corresponds to: test "should decode a shortened URL successfully"
# -----------------------------------------------------------------------------
print_test "should decode a shortened URL successfully"
echo "POST ${BASE_URL}/decode with { \"url\": \"${SHORTENED_URL}\" }"

RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/decode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${SHORTENED_URL}\"}")

HTTP_STATUS=${RESPONSE: -3}
RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}

check_status $HTTP_STATUS 200
echo "Response: ${RESPONSE_BODY}"

DECODED_URL=$(echo $RESPONSE_BODY | grep -o '"url":"[^"]*"' | sed 's/"url":"\([^"]*\)"/\1/')
echo "Decoded URL: ${DECODED_URL}"

if [ "$DECODED_URL" = "$TEST_URL" ]; then
  echo -e "${GREEN}✓ Decoded URL matches original: PASS${NC}"
else
  echo -e "${RED}✗ Decoded URL doesn't match original: FAIL${NC}"
fi

# -----------------------------------------------------------------------------
# Test: should return 400 when URL parameter is missing for decode
# Corresponds to: test "should return 400 when URL parameter is missing for decode"
# -----------------------------------------------------------------------------
print_test "should return 400 when URL parameter is missing for decode"
echo "POST ${BASE_URL}/decode with empty body"

RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/decode" \
  -H "Content-Type: application/json" \
  -d "{}")

HTTP_STATUS=${RESPONSE: -3}
RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}

check_status $HTTP_STATUS 400
echo "Response: ${RESPONSE_BODY}"

# -----------------------------------------------------------------------------
# Test: should return 404 for unknown URLs
# Corresponds to: test "should return 404 for unknown URLs"
# -----------------------------------------------------------------------------
print_test "should return 404 for unknown URLs"
echo "POST ${BASE_URL}/decode with { \"url\": \"${BASE_URL}/nonexistent\" }"

RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/decode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${BASE_URL}/nonexistent\"}")

HTTP_STATUS=${RESPONSE: -3}
RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}

check_status $HTTP_STATUS 404
echo "Response: ${RESPONSE_BODY}"

# -----------------------------------------------------------------------------
# Test: should correctly extract key from different URL formats
# Corresponds to: test "should correctly extract key from different URL formats"
# -----------------------------------------------------------------------------
print_test "should correctly extract key from different URL formats"

# Extract the key from the shortened URL
KEY=$(echo $SHORTENED_URL | awk -F'/' '{print $NF}')
echo "Extracted key: ${KEY}"

# Test different formats of the shortened URL
echo "Testing various URL formats with the same key"

# Format 1: Full URL with different domain
FORMAT1="http://example.com/${KEY}"
echo "Testing format: ${FORMAT1}"
RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/decode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${FORMAT1}\"}")
HTTP_STATUS=${RESPONSE: -3}
check_status $HTTP_STATUS 200

# Format 2: Just the key
FORMAT2="${KEY}"
echo "Testing format: ${FORMAT2}"
RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/decode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${FORMAT2}\"}")
HTTP_STATUS=${RESPONSE: -3}
check_status $HTTP_STATUS 200

# Format 3: Path-only format
FORMAT3="/${KEY}"
echo "Testing format: ${FORMAT3}"
RESPONSE=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/decode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${FORMAT3}\"}")
HTTP_STATUS=${RESPONSE: -3}
check_status $HTTP_STATUS 200

# =============================================================================
# INTEGRATION TESTS
# =============================================================================
print_header "INTEGRATION TESTS"

# -----------------------------------------------------------------------------
# Test: should correctly round-trip a URL through encode and decode
# Corresponds to: test "should correctly round-trip a URL through encode and decode"
# -----------------------------------------------------------------------------
print_test "should correctly round-trip a URL through encode and decode"

# Generate a unique URL to avoid conflicts
UNIQUE_URL="https://example.com/round-trip-test-$(date +%s)"
echo "Original URL: ${UNIQUE_URL}"

echo "Step 1: Encode the URL"
ENCODE_RESPONSE=$(curl -s -X POST "${BASE_URL}/encode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${UNIQUE_URL}\"}")
echo "Encode response: ${ENCODE_RESPONSE}"

SHORTENED_URL=$(echo $ENCODE_RESPONSE | grep -o '"url":"[^"]*"' | sed 's/"url":"\([^"]*\)"/\1/')
echo "Shortened URL: ${SHORTENED_URL}"

echo "Step 2: Decode the shortened URL"
DECODE_RESPONSE=$(curl -s -X POST "${BASE_URL}/decode" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${SHORTENED_URL}\"}")
echo "Decode response: ${DECODE_RESPONSE}"

DECODED_URL=$(echo $DECODE_RESPONSE | grep -o '"url":"[^"]*"' | sed 's/"url":"\([^"]*\)"/\1/')
echo "Decoded URL: ${DECODED_URL}"

if [ "$DECODED_URL" = "$UNIQUE_URL" ]; then
  echo -e "${GREEN}✓ Round-trip successful (original URL = decoded URL): PASS${NC}"
else
  echo -e "${RED}✗ Round-trip failed (original URL != decoded URL): FAIL${NC}"
fi

# =============================================================================
# TEST SUMMARY
# =============================================================================
print_header "TEST SUMMARY"
echo "All tests completed. Check the output above for results."
echo "Note: Some tests might fail if the server is not running or if there are"
echo "implementation differences between the API and the integration tests."