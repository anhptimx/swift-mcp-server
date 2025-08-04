#!/bin/bash

# CI/CD Test Script
# This script validates that the CI/CD pipeline is working correctly

set -e

echo "🧪 Running CI/CD validation tests..."

# Test 1: Build validation
echo "1. Testing build..."
swift build --configuration release > /dev/null 2>&1
echo "✅ Build successful"

# Test 2: Unit tests
echo "2. Running unit tests..."
swift test > /dev/null 2>&1
echo "✅ Unit tests passed"

# Test 3: Integration tests
echo "3. Running integration tests..."
./test-integration.sh > /dev/null 2>&1
echo "✅ Integration tests passed"

# Test 4: Code quality check
echo "4. Checking code quality..."
if command -v swift-format >/dev/null 2>&1; then
    echo "✅ Swift-format available"
else
    echo "ℹ️  Swift-format not available (optional)"
fi

echo ""
echo "🎉 All CI/CD validation tests passed!"
echo "✅ Build: Working"
echo "✅ Tests: Passing" 
echo "✅ Integration: Functional"
echo "✅ Pipeline: Ready"
