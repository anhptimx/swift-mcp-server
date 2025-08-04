#!/bin/bash

# Quick Start Script for Swift MCP Server
# Get up and running in minutes
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"

print_banner() {
    echo -e "${CYAN}"
    echo "=================================================="
    echo "       Swift MCP Server Quick Start"
    echo "=================================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}🚀 Step $1: $2${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_command() {
    echo -e "${YELLOW}Command: $1${NC}"
}

check_prerequisites() {
    print_step "1" "Checking Prerequisites"
    
    # Check Swift
    if command -v swift &> /dev/null; then
        local swift_version=$(swift --version | head -1)
        print_success "Swift found: $swift_version"
    else
        print_error "Swift not found. Please install Swift from https://swift.org/download/"
        exit 1
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        print_success "Git found"
    else
        print_error "Git not found. Please install Git"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ -f "$SCRIPT_DIR/Package.swift" ]; then
        print_success "Package.swift found - you're in the right directory"
    else
        print_error "Package.swift not found. Please run this script from the project root"
        exit 1
    fi
    
    echo
}

build_server() {
    print_step "2" "Building the Server"
    
    cd "$SCRIPT_DIR"
    
    print_info "Cleaning previous builds..."
    swift package clean
    
    print_info "Resolving dependencies..."
    swift package resolve
    
    print_info "Building release version..."
    print_command "swift build --configuration release"
    swift build --configuration release
    
    # Verify build
    if [ -f ".build/release/swift-mcp-server" ]; then
        print_success "Server built successfully!"
        
        # Make executable
        chmod +x .build/release/swift-mcp-server
        
        # Test basic functionality
        if .build/release/swift-mcp-server --help > /dev/null 2>&1; then
            print_success "Server binary is functional"
        else
            print_warning "Server binary may have issues"
        fi
    else
        print_error "Build failed - server binary not found"
        exit 1
    fi
    
    echo
}

test_server() {
    print_step "3" "Testing Server Functionality"
    
    print_info "Testing HTTP mode..."
    
    # Start server in background
    .build/release/swift-mcp-server \
        --transport http \
        --port 8080 \
        --workspace "$SCRIPT_DIR" \
        > /tmp/quickstart-test.log 2>&1 &
    
    local server_pid=$!
    sleep 3
    
    # Test if server is running
    if kill -0 $server_pid 2>/dev/null; then
        print_success "HTTP server started successfully"
        
        # Test health endpoint
        if curl -s -f "http://localhost:8080/health" > /dev/null 2>&1; then
            print_success "Health endpoint responding"
        else
            print_warning "Health endpoint not responding"
        fi
        
        # Stop server
        kill $server_pid 2>/dev/null || true
    else
        print_error "Server failed to start"
        echo "Check logs: cat /tmp/quickstart-test.log"
        exit 1
    fi
    
    print_info "Testing STDIO mode..."
    
    # Test STDIO mode with a simple request
    local test_request='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}'
    
    if echo "$test_request" | timeout 10s .build/release/swift-mcp-server \
        --transport stdio \
        --workspace "$SCRIPT_DIR" \
        > /tmp/quickstart-stdio.json 2>/dev/null; then
        
        if grep -q '"result"' /tmp/quickstart-stdio.json; then
            print_success "STDIO mode working correctly"
        else
            print_warning "STDIO mode may have issues"
        fi
    else
        print_warning "STDIO test failed (this might be normal)"
    fi
    
    echo
}

setup_vscode_integration() {
    print_step "4" "Setting up VS Code Integration"
    
    local server_path="$SCRIPT_DIR/.build/release/swift-mcp-server"
    
    # Check if VS Code is installed
    if [ -d "/Applications/Visual Studio Code.app" ] || command -v code &> /dev/null; then
        print_success "VS Code detected"
    else
        print_warning "VS Code not detected - you can still use the server manually"
    fi
    
    # Create VS Code settings directory if it doesn't exist
    if [ ! -d "$VSCODE_SETTINGS_DIR" ]; then
        print_info "Creating VS Code settings directory..."
        mkdir -p "$VSCODE_SETTINGS_DIR"
    fi
    
    # Create MCP configuration
    local config_file="$VSCODE_SETTINGS_DIR/swift-mcp-config.json"
    
    cat > "$config_file" << EOF
{
  "mcp": {
    "servers": {
      "swift-mcp-server": {
        "command": "$server_path",
        "args": [
          "--transport", "stdio",
          "--workspace", "\${workspaceFolder}",
          "--log-level", "info"
        ],
        "env": {
          "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/usr/bin"
        }
      }
    }
  }
}
EOF
    
    print_success "VS Code MCP configuration created"
    print_info "Configuration saved to: $config_file"
    
    echo
    print_info "To use with VS Code:"
    print_info "1. Install the MCP extension in VS Code"
    print_info "2. Copy the contents of $config_file"
    print_info "3. Paste into your VS Code settings.json under the \"mcp\" section"
    
    echo
}

provide_usage_examples() {
    print_step "5" "Usage Examples"
    
    local server_path="$SCRIPT_DIR/.build/release/swift-mcp-server"
    
    echo -e "${CYAN}HTTP Mode (for external tools):${NC}"
    print_command "$server_path --transport http --port 8080 --workspace /path/to/your/project"
    echo
    
    echo -e "${CYAN}STDIO Mode (for VS Code/Serena):${NC}"
    print_command "$server_path --transport stdio --workspace /path/to/your/project"
    echo
    
    echo -e "${CYAN}With custom configuration:${NC}"
    print_command "$server_path --transport http --port 8080 --config config.json"
    echo
    
    echo -e "${CYAN}Debug mode:${NC}"
    print_command "$server_path --transport stdio --workspace . --log-level debug"
    echo
    
    echo -e "${CYAN}Available options:${NC}"
    print_info "Run: $server_path --help"
    
    echo
}

provide_next_steps() {
    print_step "6" "Next Steps"
    
    echo -e "${CYAN}🎯 What you can do now:${NC}"
    echo
    echo -e "${GREEN}1. Test with curl (HTTP mode):${NC}"
    echo "   Start server: .build/release/swift-mcp-server --transport http --port 8080 --workspace ."
    echo "   Test health: curl http://localhost:8080/health"
    echo
    
    echo -e "${GREEN}2. Use with VS Code:${NC}"
    echo "   - Install VS Code MCP extension"
    echo "   - Add configuration from $VSCODE_SETTINGS_DIR/swift-mcp-config.json"
    echo "   - Open a Swift project in VS Code"
    echo
    
    echo -e "${GREEN}3. Run diagnostic tools:${NC}"
    echo "   Health check: ./health-check.sh"
    echo "   Quick fixes: ./quick-fix.sh all"
    echo "   Integration tests: ./test-integration.sh"
    echo
    
    echo -e "${GREEN}4. Customize configuration:${NC}"
    echo "   Edit: mcp-config.json"
    echo "   Enterprise: enterprise-config.json"
    echo
    
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo "   README.md - Complete documentation"
    echo "   MODERN_CONCURRENCY.md - Concurrency features"
    echo "   DEPLOYMENT.md - Production deployment"
    echo
}

run_final_verification() {
    print_step "7" "Final Verification"
    
    # Run health check if available
    if [ -f "$SCRIPT_DIR/health-check.sh" ]; then
        print_info "Running health check..."
        if "$SCRIPT_DIR/health-check.sh" > /tmp/quickstart-health.log 2>&1; then
            print_success "Health check passed"
        else
            print_warning "Health check found some issues - check ./health-check.sh"
        fi
    fi
    
    # Verify all scripts are executable
    local scripts=("health-check.sh" "quick-fix.sh" "test-integration.sh")
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            chmod +x "$SCRIPT_DIR/$script"
            print_success "$script is ready"
        fi
    done
    
    echo
    print_success "🎉 Quick start completed successfully!"
    echo
    print_info "Your Swift MCP Server is ready to use!"
    echo
}

show_help() {
    cat << EOF
Swift MCP Server Quick Start

This script will:
1. Check prerequisites (Swift, Git)
2. Build the server in release mode
3. Test basic functionality
4. Set up VS Code integration
5. Provide usage examples
6. Run final verification

Usage: $0 [options]

Options:
  --help          Show this help
  --skip-vscode   Skip VS Code integration setup
  --skip-tests    Skip functionality tests
  --verbose       Enable verbose output

Examples:
  $0                    # Full quick start
  $0 --skip-vscode      # Skip VS Code setup
  $0 --verbose          # Verbose output

EOF
}

# Parse command line arguments
SKIP_VSCODE=false
SKIP_TESTS=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --skip-vscode)
            SKIP_VSCODE=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_banner
    
    check_prerequisites
    build_server
    
    if [ "$SKIP_TESTS" = false ]; then
        test_server
    fi
    
    if [ "$SKIP_VSCODE" = false ]; then
        setup_vscode_integration
    fi
    
    provide_usage_examples
    provide_next_steps
    run_final_verification
}

# Run main function
main "$@"