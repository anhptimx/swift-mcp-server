#!/bin/bash

# Quick Fix Script for Swift MCP Server Common Issues
# Version: 1.0
# Usage: ./quick-fix.sh [issue-type]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_BINARY="$SCRIPT_DIR/.build/release/swift-mcp-server"

print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}Swift MCP Server Quick Fix${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

fix_permissions() {
    print_info "Fixing file permissions..."
    
    if [ -f "$SERVER_BINARY" ]; then
        chmod +x "$SERVER_BINARY"
        print_success "Fixed server binary permissions"
    else
        print_error "Server binary not found. Run 'swift build -c release' first"
        return 1
    fi
    
    if [ -f "$SCRIPT_DIR/health-check.sh" ]; then
        chmod +x "$SCRIPT_DIR/health-check.sh"
        print_success "Fixed health check script permissions"
    fi
    
    if [ -f "$SCRIPT_DIR/quick-start.sh" ]; then
        chmod +x "$SCRIPT_DIR/quick-start.sh"
        print_success "Fixed quick start script permissions"
    fi
}

rebuild_server() {
    print_info "Rebuilding server..."
    
    cd "$SCRIPT_DIR"
    
    # Clean build
    swift package clean
    print_success "Cleaned previous build"
    
    # Resolve dependencies
    swift package resolve
    print_success "Resolved dependencies"
    
    # Build release
    swift build -c release
    print_success "Built release binary"
    
    # Fix permissions
    fix_permissions
}

fix_vscode_config() {
    print_info "Fixing VS Code MCP configuration..."
    
    # Check if VS Code settings directory exists
    VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
    
    if [ ! -d "$VSCODE_SETTINGS_DIR" ]; then
        print_warning "VS Code settings directory not found"
        print_info "Creating VS Code settings directory..."
        mkdir -p "$VSCODE_SETTINGS_DIR"
    fi
    
    # Backup existing settings
    if [ -f "$VSCODE_SETTINGS_DIR/settings.json" ]; then
        cp "$VSCODE_SETTINGS_DIR/settings.json" "$VSCODE_SETTINGS_DIR/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Backed up existing VS Code settings"
    fi
    
    # Create or update MCP configuration
    cat > "$VSCODE_SETTINGS_DIR/mcp-settings.json" << EOF
{
  "mcp": {
    "servers": {
      "swift-mcp-server": {
        "command": "$SERVER_BINARY",
        "args": [
          "--transport", "stdio",
          "--workspace", "\${workspaceFolder}",
          "--log-level", "info"
        ],
        "env": {
          "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/usr/bin",
          "SWIFT_MCP_MODE": "vscode"
        }
      }
    }
  }
}
EOF
    
    print_success "Created MCP configuration file"
    print_info "Copy contents of $VSCODE_SETTINGS_DIR/mcp-settings.json to your VS Code settings.json"
}

fix_sourcekit_path() {
    print_info "Fixing SourceKit-LSP path..."
    
    # Common SourceKit-LSP locations
    SOURCEKIT_PATHS=(
        "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"
        "/usr/local/bin/sourcekit-lsp"
        "/opt/homebrew/bin/sourcekit-lsp"
    )
    
    FOUND_SOURCEKIT=""
    for path in "${SOURCEKIT_PATHS[@]}"; do
        if [ -f "$path" ]; then
            FOUND_SOURCEKIT="$path"
            break
        fi
    done
    
    if [ -n "$FOUND_SOURCEKIT" ]; then
        print_success "Found SourceKit-LSP at: $FOUND_SOURCEKIT"
        
        # Add to PATH in shell profile
        SHELL_PROFILE=""
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_PROFILE="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_PROFILE="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_PROFILE="$HOME/.bash_profile"
        fi
        
        if [ -n "$SHELL_PROFILE" ]; then
            SOURCEKIT_DIR="$(dirname "$FOUND_SOURCEKIT")"
            if ! grep -q "$SOURCEKIT_DIR" "$SHELL_PROFILE"; then
                echo "export PATH=\"$SOURCEKIT_DIR:\$PATH\"" >> "$SHELL_PROFILE"
                print_success "Added SourceKit-LSP to PATH in $SHELL_PROFILE"
                print_warning "Restart your terminal or run: source $SHELL_PROFILE"
            else
                print_success "SourceKit-LSP already in PATH"
            fi
        fi
    else
        print_error "SourceKit-LSP not found. Install Xcode or Swift toolchain"
        print_info "Try: xcode-select --install"
    fi
}

test_server() {
    print_info "Testing server functionality..."
    
    if [ ! -f "$SERVER_BINARY" ]; then
        print_error "Server binary not found. Run rebuild first"
        return 1
    fi
    
    # Test help command
    if "$SERVER_BINARY" --help > /dev/null 2>&1; then
        print_success "Server binary is functional"
    else
        print_error "Server binary is not working properly"
        return 1
    fi
    
    # Test STDIO mode
    print_info "Testing STDIO mode..."
    
    # Test with a simple MCP request (works on all platforms)
    local test_request='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}'
    
    if echo "$test_request" | "$SERVER_BINARY" --transport stdio --workspace "$SCRIPT_DIR" > /tmp/stdio-test.json 2>&1; then
        if grep -q '"result"' /tmp/stdio-test.json; then
            print_success "STDIO mode working correctly"
        else
            print_warning "STDIO mode response unexpected"
        fi
    else
        print_error "STDIO mode failed to start"
        return 1
    fi
    
    print_success "All tests passed"
}

show_help() {
    cat << EOF
Swift MCP Server Quick Fix Script

Usage: $0 [command]

Commands:
  permissions    Fix file permissions
  rebuild        Clean and rebuild the server
  vscode         Fix VS Code MCP configuration  
  sourcekit      Fix SourceKit-LSP path issues
  test          Test server functionality
  all           Run all fixes
  help          Show this help message

Examples:
  $0 all                # Run all fixes
  $0 rebuild            # Rebuild server only
  $0 vscode             # Fix VS Code config only

EOF
}

# Main execution
case "${1:-help}" in
    "permissions")
        print_header
        fix_permissions
        ;;
    "rebuild")
        print_header
        rebuild_server
        ;;
    "vscode")
        print_header
        fix_vscode_config
        ;;
    "sourcekit")
        print_header
        fix_sourcekit_path
        ;;
    "test")
        print_header
        test_server
        ;;
    "all")
        print_header
        print_info "Running all fixes..."
        echo
        
        fix_permissions
        echo
        
        rebuild_server
        echo
        
        fix_vscode_config
        echo
        
        fix_sourcekit_path
        echo
        
        test_server
        echo
        
        print_success "All fixes completed!"
        ;;
    "help"|*)
        show_help
        ;;
esac
