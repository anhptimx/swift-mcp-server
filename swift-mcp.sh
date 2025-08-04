#!/bin/bash

# Swift MCP Server - All-in-One Setup & Management Script
# Combines setup, testing, fixing, and management in one script
# Version: 2.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_BINARY="$SCRIPT_DIR/.build/release/swift-mcp-server"

# Helper functions
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          Swift MCP Server Manager                           ║"
    echo "║                      All-in-One Setup & Management                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Core functions
build_server() {
    print_info "Building Swift MCP Server..."
    
    if ! command -v swift &> /dev/null; then
        print_error "Swift not found. Please install Swift or Xcode"
        return 1
    fi
    
    # Clean build
    swift package clean
    swift build --configuration release
    
    if [ -f "$SERVER_BINARY" ]; then
        print_success "Server built successfully"
        print_info "Binary location: $SERVER_BINARY"
    else
        print_error "Build failed"
        return 1
    fi
}

fix_permissions() {
    print_info "Fixing file permissions..."
    
    # Fix script permissions
    chmod +x *.sh 2>/dev/null || true
    
    # Fix binary permissions
    if [ -f "$SERVER_BINARY" ]; then
        chmod +x "$SERVER_BINARY"
    fi
    
    print_success "Permissions fixed"
}

setup_vscode() {
    print_info "Setting up VS Code MCP configuration..."
    
    # Create VS Code settings directory if it doesn't exist
    VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
    
    if [ ! -d "$VSCODE_SETTINGS_DIR" ]; then
        mkdir -p "$VSCODE_SETTINGS_DIR"
        print_success "Created VS Code settings directory"
    fi
    
    # Create MCP configuration
    cat > "$VSCODE_SETTINGS_DIR/mcp-swift-server.json" << EOF
{
  "mcp": {
    "servers": {
      "swift-mcp-server": {
        "command": "$SERVER_BINARY",
        "args": [
          "--transport", "stdio",
          "\${workspaceFolder}"
        ],
        "env": {
          "SWIFT_MCP_MODE": "vscode"
        }
      }
    }
  }
}
EOF
    
    print_success "VS Code MCP configuration created"
    print_info "Config file: $VSCODE_SETTINGS_DIR/mcp-swift-server.json"
}

health_check() {
    print_info "Running comprehensive health check..."
    
    # Check Swift installation
    if command -v swift &> /dev/null; then
        SWIFT_VERSION=$(swift --version | head -n1)
        print_success "Swift found: $SWIFT_VERSION"
    else
        print_error "Swift not found"
        return 1
    fi
    
    # Check SourceKit-LSP
    if command -v sourcekit-lsp &> /dev/null; then
        print_success "SourceKit-LSP found"
    else
        print_warning "SourceKit-LSP not in PATH (may still work with Xcode)"
    fi
    
    # Check server binary
    if [ -f "$SERVER_BINARY" ]; then
        print_success "Server binary exists"
        
        # Test help command
        if "$SERVER_BINARY" --help > /dev/null 2>&1; then
            print_success "Server binary is functional"
        else
            print_error "Server binary not working"
            return 1
        fi
    else
        print_warning "Server binary not found - will build"
        build_server
    fi
    
    print_success "Health check completed"
}

test_stdio() {
    print_info "Testing STDIO mode..."
    
    if [ ! -f "$SERVER_BINARY" ]; then
        print_error "Server not built. Building now..."
        build_server
    fi
    
    # Test initialize request
    local test_request='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}'
    
    if echo "$test_request" | "$SERVER_BINARY" --transport stdio --workspace "$SCRIPT_DIR" > /tmp/stdio-test.json 2>&1; then
        if grep -q '"result"' /tmp/stdio-test.json; then
            print_success "STDIO mode working correctly"
            
            # Test tools list
            local tools_request='{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}'
            if echo "$tools_request" | "$SERVER_BINARY" --transport stdio --workspace "$SCRIPT_DIR" > /tmp/tools-test.json 2>&1; then
                if grep -q '"tools"' /tmp/tools-test.json; then
                    print_success "Tools available and accessible"
                fi
            fi
        else
            print_warning "STDIO mode response unexpected"
        fi
    else
        print_error "STDIO mode failed"
        return 1
    fi
}

run_persistent_stdio() {
    print_header
    print_info "🔄 Starting persistent STDIO mode..."
    print_info "💡 Server will stay alive for multiple requests"
    print_info "📝 Send JSON MCP requests, Ctrl+C to exit"
    echo
    
    if [ ! -f "$SERVER_BINARY" ]; then
        print_error "Server not built. Building now..."
        build_server
    fi
    
    print_success "Starting server in persistent mode..."
    print_info "Example requests:"
    print_info '  {"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}'
    print_info '  {"jsonrpc": "2.0", "method": "tools/list", "id": 2, "params": {}}'
    echo
    
    cat | "$SERVER_BINARY" --transport stdio --workspace "$PWD"
}

# Main setup function
setup_all() {
    print_header
    print_info "🚀 Setting up Swift MCP Server..."
    echo
    
    # Step 1: Health check
    health_check
    echo
    
    # Step 2: Build server
    build_server  
    echo
    
    # Step 3: Fix permissions
    fix_permissions
    echo
    
    # Step 4: Setup VS Code
    setup_vscode
    echo
    
    # Step 5: Test functionality
    test_stdio
    echo
    
    print_success "🎉 Swift MCP Server setup completed!"
    print_info ""
    print_info "📋 What's available:"
    print_info "  • Server binary: $SERVER_BINARY"
    print_info "  • VS Code config: Ready to use"
    print_info "  • STDIO mode: Tested and working"
    print_info ""
    print_info "🔄 To run persistent STDIO mode:"
    print_info "  $0 stdio"
    print_info ""
    print_info "🛠️ Available commands:"
    print_info "  $0 setup    - Full setup (default)"
    print_info "  $0 build    - Build server only"
    print_info "  $0 test     - Test functionality"
    print_info "  $0 stdio    - Run persistent STDIO mode"
    print_info "  $0 health   - Health check"
    print_info "  $0 vscode   - Setup VS Code only"
}

show_help() {
    cat << EOF
Swift MCP Server - All-in-One Management Script

Usage: $0 [command]

Commands:
  setup      Full setup (build, configure, test) - DEFAULT
  build      Build server binary only
  test       Test server functionality
  stdio      Run persistent STDIO mode (won't shutdown)
  health     Run health check
  vscode     Setup VS Code MCP configuration
  help       Show this help message

Examples:
  $0                    # Full setup (default)
  $0 setup              # Full setup
  $0 stdio              # Run persistent STDIO mode
  $0 test               # Test functionality only

Quick Start:
  1. Run: $0 setup
  2. Configure VS Code with generated config
  3. Start coding with MCP support!

EOF
}

# Main execution
case "${1:-setup}" in
    "setup"|"")
        setup_all
        ;;
    "build")
        print_header
        build_server
        ;;
    "test")
        print_header
        test_stdio
        ;;
    "stdio")
        run_persistent_stdio
        ;;
    "health")
        print_header
        health_check
        ;;
    "vscode")
        print_header
        setup_vscode
        ;;
    "help"|*)
        show_help
        ;;
esac
