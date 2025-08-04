#!/bin/bash

echo "🔍 Swift MCP Server Health Check"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Swift installation
echo -n "Checking Swift installation... "
if command -v swift &> /dev/null; then
    echo -e "${GREEN}✅ Found${NC}"
    echo "   Version: $(swift --version | head -1)"
else
    echo -e "${RED}❌ Swift not found${NC}"
    echo "   Install from: https://swift.org/install/"
fi

# Check SourceKit-LSP
echo -n "Checking SourceKit-LSP... "
if command -v sourcekit-lsp &> /dev/null; then
    echo -e "${GREEN}✅ Found${NC}"
    echo "   Path: $(which sourcekit-lsp)"
else
    echo -e "${RED}❌ SourceKit-LSP not found${NC}"
    echo "   Run: xcode-select --install"
fi

# Check Xcode path
echo -n "Checking Xcode path... "
if xcode-select -p &> /dev/null; then
    echo -e "${GREEN}✅ Set${NC}"
    echo "   Path: $(xcode-select -p)"
else
    echo -e "${YELLOW}⚠️  Not set${NC}"
    echo "   Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

# Check server binary
echo -n "Checking server binary... "
if [ -f ".build/release/swift-mcp-server" ]; then
    echo -e "${GREEN}✅ Exists${NC}"
    echo "   Version: $(.build/release/swift-mcp-server --version)"
else
    echo -e "${RED}❌ Not found${NC}"
    echo "   Run: swift build --configuration release"
fi

# Check dependencies
echo -n "Checking Package.swift... "
if [ -f "Package.swift" ]; then
    echo -e "${GREEN}✅ Found${NC}"
else
    echo -e "${RED}❌ Package.swift missing${NC}"
fi

# Test package dependencies
echo -n "Checking dependencies... "
if swift package describe &> /dev/null; then
    echo -e "${GREEN}✅ Resolved${NC}"
else
    echo -e "${YELLOW}⚠️  Need resolution${NC}"
    echo "   Run: swift package resolve"
fi

# Test server startup (if binary exists)
if [ -f ".build/release/swift-mcp-server" ]; then
    echo "🧪 Testing server startup..."
    
    # Test HTTP mode
    echo -n "  HTTP transport... "
    timeout 3s .build/release/swift-mcp-server --transport http --port 8099 > /dev/null 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    if kill -0 $SERVER_PID 2>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        kill $SERVER_PID 2>/dev/null
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
    
    # Test STDIO mode
    echo -n "  STDIO transport... "
    echo '{"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}}}' | \
        timeout 3s .build/release/swift-mcp-server --transport stdio > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
fi

echo ""
echo "🎯 Quick Fixes:"
echo "   Build server: swift build --configuration release"
echo "   Install Xcode tools: xcode-select --install"
echo "   Resolve dependencies: swift package resolve"
echo "   Test manually: .build/release/swift-mcp-server --help"

# Check for common issues
echo ""
echo "💡 Common Issues:"

if ! command -v sourcekit-lsp &> /dev/null; then
    echo -e "${YELLOW}   • SourceKit-LSP missing - install Xcode Command Line Tools${NC}"
fi

if [ ! -f ".build/release/swift-mcp-server" ]; then
    echo -e "${YELLOW}   • Server binary missing - run build command${NC}"
fi

if [ ! -d ".build" ]; then
    echo -e "${YELLOW}   • No build directory - run 'swift build'${NC}"
fi

echo ""
echo "✅ Health check complete!"
