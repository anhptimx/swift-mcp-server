#!/bin/bash

# Test script for Swift MCP Server functionality

set -e

echo "🧪 Testing Swift MCP Server..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if server is built
if [ ! -f ".build/release/swift-mcp-server" ]; then
    echo "${YELLOW}Building Swift MCP Server first...${NC}"
    swift build -c release
fi

# Start the server in background
echo "🚀 Starting Swift MCP Server..."
.build/release/swift-mcp-server --host 127.0.0.1 --port 8080 &
SERVER_PID=$!

# Wait for server to start
sleep 3

# Function to test MCP endpoint
test_mcp_endpoint() {
    local test_name="$1"
    local request_body="$2"
    local expected_key="$3"
    
    echo "Testing: $test_name"
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        http://127.0.0.1:8080/mcp)
    
    if echo "$response" | grep -q "$expected_key"; then
        echo "${GREEN}✅ $test_name passed${NC}"
        return 0
    else
        echo "${RED}❌ $test_name failed${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Test 1: Initialize
echo "Test 1: Initialize"
test_mcp_endpoint "Initialize" '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "initialize",
    "params": {
        "protocolVersion": "2024-11-05"
    }
}' "protocolVersion"

# Test 2: List Tools
echo "Test 2: List Tools"
test_mcp_endpoint "List Tools" '{
    "jsonrpc": "2.0",
    "id": "2",
    "method": "tools/list"
}' "find_symbols"

# Test 3: List Resources
echo "Test 3: List Resources"
test_mcp_endpoint "List Resources" '{
    "jsonrpc": "2.0",
    "id": "3",
    "method": "resources/list"
}' "swift://workspace"

# Test 4: Read Resource
echo "Test 4: Read Resource"
test_mcp_endpoint "Read Resource" '{
    "jsonrpc": "2.0",
    "id": "4",
    "method": "resources/read",
    "params": {
        "uri": "swift://workspace"
    }
}' "swift_workspace"

# Test 5: Call Tool - Find Symbols
echo "Test 5: Call Tool - Find Symbols"
test_mcp_endpoint "Find Symbols" '{
    "jsonrpc": "2.0",
    "id": "5",
    "method": "tools/call",
    "params": {
        "name": "find_symbols",
        "arguments": {
            "file_path": "'$(pwd)'/Examples/User.swift",
            "name_pattern": "User"
        }
    }
}' "content"

# Test 6: Call Tool - Get Hover Info
echo "Test 6: Call Tool - Get Hover Info"
test_mcp_endpoint "Get Hover Info" '{
    "jsonrpc": "2.0",
    "id": "6",
    "method": "tools/call",
    "params": {
        "name": "get_hover_info",
        "arguments": {
            "file_path": "'$(pwd)'/Examples/User.swift",
            "line": 10,
            "character": 15
        }
    }
}' "content"

# Test 7: Invalid Method
echo "Test 7: Invalid Method"
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "id": "7",
        "method": "invalid_method"
    }' \
    http://127.0.0.1:8080/mcp)

if echo "$response" | grep -q "error"; then
    echo "${GREEN}✅ Invalid method error handling passed${NC}"
else
    echo "${RED}❌ Invalid method error handling failed${NC}"
fi

# Test 8: CORS Headers
echo "Test 8: CORS Headers"
cors_response=$(curl -s -I -X OPTIONS http://127.0.0.1:8080/mcp)

if echo "$cors_response" | grep -q "Access-Control-Allow-Origin"; then
    echo "${GREEN}✅ CORS headers test passed${NC}"
else
    echo "${RED}❌ CORS headers test failed${NC}"
fi

# Cleanup
echo "🧹 Cleaning up..."
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo "${GREEN}🎉 All tests completed!${NC}"
