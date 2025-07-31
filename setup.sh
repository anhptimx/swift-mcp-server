#!/bin/bash

# Swift MCP Server Setup Script

set -e

echo "🚀 Setting up Swift MCP Server..."

# Check Swift version
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode or Swift toolchain."
    exit 1
fi

SWIFT_VERSION=$(swift --version | head -n 1)
echo "✅ Found Swift: $SWIFT_VERSION"

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Package.swift not found. Please run this script from the swift-mcp-server directory."
    exit 1
fi

# Build the project
echo "🔨 Building Swift MCP Server..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Run tests
echo "🧪 Running tests..."
swift test

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed!"
    exit 1
fi

# Create symlink for easy access
EXECUTABLE_PATH=$(pwd)/.build/release/swift-mcp-server
if [ -f "$EXECUTABLE_PATH" ]; then
    echo "📁 Executable available at: $EXECUTABLE_PATH"
    
    # Optionally create a symlink in /usr/local/bin (requires sudo)
    read -p "Do you want to create a symlink in /usr/local/bin for global access? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ln -sf "$EXECUTABLE_PATH" /usr/local/bin/swift-mcp-server
        echo "✅ Symlink created: /usr/local/bin/swift-mcp-server"
    fi
fi

echo "🎉 Setup complete!"
echo ""
echo "Usage:"
echo "  Local: $EXECUTABLE_PATH --host 127.0.0.1 --port 8080"
if [ -L "/usr/local/bin/swift-mcp-server" ]; then
    echo "  Global: swift-mcp-server --host 127.0.0.1 --port 8080"
fi
echo ""
echo "For Serena MCP integration, add this to your MCP configuration:"
echo '{
  "mcpServers": {
    "swift": {
      "command": "'$EXECUTABLE_PATH'",
      "args": ["--host", "127.0.0.1", "--port", "8080"],
      "env": {}
    }
  }
}'
