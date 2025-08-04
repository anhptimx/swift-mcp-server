#!/bin/bash

# Swift MCP Server - Quick Start Setup Script
# This script automates the installation and setup process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   Swift MCP Server Setup                     ║"
    echo "║            Professional Swift Analysis for Serena            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_footer() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      Setup Complete! 🎉                     ║"
    echo "║                                                              ║"
    echo "║  Your Swift MCP Server is ready for Serena integration      ║"
    echo "║                                                              ║"
    echo "║  Next steps:                                                 ║"
    echo "║  1. Configure Claude Desktop (see SERENA_INTEGRATION.md)    ║"
    echo "║  2. Test with: curl http://127.0.0.1:8081/health            ║"
    echo "║  3. Start analyzing Swift projects with Serena!             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running on macOS
check_platform() {
    log_info "Checking platform compatibility..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "Running on macOS - platform supported"
        PLATFORM="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "Running on Linux - platform supported"
        PLATFORM="linux"
    else
        log_error "Unsupported platform: $OSTYPE"
        log_info "Swift MCP Server requires macOS 13.0+ or Linux Ubuntu 18.04+"
        exit 1
    fi
}

# Check Swift installation
check_swift() {
    log_info "Checking Swift installation..."
    
    if command -v swift &> /dev/null; then
        SWIFT_VERSION=$(swift --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+')
        log_success "Swift $SWIFT_VERSION found"
        
        # Check minimum version requirement (5.9)
        if [[ "$(printf '%s\n' "5.9" "$SWIFT_VERSION" | sort -V | head -n1)" = "5.9" ]]; then
            log_success "Swift version meets requirements (5.9+)"
        else
            log_info "Swift version: $SWIFT_VERSION (compatible with 5.9+)"
        fi
    else
        log_error "Swift not found!"
        if [[ "$PLATFORM" == "macos" ]]; then
            log_info "Install Xcode Command Line Tools: xcode-select --install"
        else
            log_info "Install Swift: curl -s https://swift.org/install.sh | bash"
        fi
        exit 1
    fi
}

# Check SourceKit-LSP (macOS only)
check_sourcekit_lsp() {
    if [[ "$PLATFORM" == "macos" ]]; then
        log_info "Checking SourceKit-LSP installation..."
        
        if command -v sourcekit-lsp &> /dev/null; then
            log_success "SourceKit-LSP found at $(which sourcekit-lsp)"
        else
            log_warning "SourceKit-LSP not found in PATH"
            
            # Check common Xcode locations
            XCODE_SOURCEKIT="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"
            if [[ -f "$XCODE_SOURCEKIT" ]]; then
                log_success "SourceKit-LSP found in Xcode: $XCODE_SOURCEKIT"
                export SOURCEKIT_LSP_PATH="$XCODE_SOURCEKIT"
            else
                log_error "SourceKit-LSP not found. Install Xcode or Xcode Command Line Tools"
                exit 1
            fi
        fi
    fi
}

# Build the server
build_server() {
    log_info "Building Swift MCP Server..."
    
    # Clean previous builds
    if [[ -d ".build" ]]; then
        log_info "Cleaning previous build..."
        rm -rf .build
    fi
    
    # Resolve dependencies
    log_info "Resolving Swift package dependencies..."
    swift package resolve
    
    # Build release version
    log_info "Building release version (this may take a few minutes)..."
    swift build --configuration release
    
    # Check if build succeeded
    if [[ -f ".build/release/SwiftMCPServer" ]]; then
        log_success "Build completed successfully!"
        
        # Make executable
        chmod +x .build/release/SwiftMCPServer
        
        # Show build info
        BUILD_SIZE=$(du -h .build/release/SwiftMCPServer | cut -f1)
        log_info "Executable size: $BUILD_SIZE"
    else
        log_error "Build failed! Check the output above for errors."
        exit 1
    fi
}

# Test the server
test_server() {
    log_info "Testing server functionality..."
    
    # Start server in background
    ./.build/release/SwiftMCPServer --host 127.0.0.1 --port 8081 &
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 3
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    if curl -s http://127.0.0.1:8081/health > /dev/null; then
        log_success "Health endpoint responding correctly"
    else
        log_error "Health endpoint not responding"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    # Test MCP tools endpoint
    log_info "Testing MCP tools endpoint..."
    TOOLS_RESPONSE=$(curl -s -X POST http://127.0.0.1:8081/mcp \
        -H "Content-Type: application/json" \
        -d '{"method": "tools/list", "params": {}}' || echo "ERROR")
    
    if [[ "$TOOLS_RESPONSE" != "ERROR" ]] && [[ "$TOOLS_RESPONSE" == *"analyze_project"* ]]; then
        TOOL_COUNT=$(echo "$TOOLS_RESPONSE" | grep -o "analyze_project\|detect_architecture\|find_symbols" | wc -l)
        log_success "MCP tools endpoint working (found $TOOL_COUNT tools)"
    else
        log_error "MCP tools endpoint not working properly"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    # Stop test server
    kill $SERVER_PID 2>/dev/null || true
    sleep 1
    
    log_success "Server tests passed!"
}

# Install Serena (optional)
install_serena() {
    log_info "Checking for Serena MCP installation..."
    
    if command -v uvx &> /dev/null; then
        log_success "UV found - Serena can be installed"
        
        echo
        read -p "🤖 Would you like to install Serena MCP for enhanced Swift development? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing Serena MCP..."
            uvx --from git+https://github.com/oraios/serena serena --help > /dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                log_success "Serena MCP installed successfully!"
                log_info "See SERENA_INTEGRATION.md for configuration instructions"
            else
                log_warning "Serena installation failed, but you can install it later"
            fi
        else
            log_info "Skipping Serena installation"
        fi
    else
        log_info "UV not found - install it to use Serena MCP"
        log_info "Install UV: curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
}

# Generate configuration examples
generate_configs() {
    log_info "Generating configuration examples..."
    
    # Create examples directory
    mkdir -p examples/configs
    
    # Claude Desktop config
    cat > examples/configs/claude_desktop_config.json << 'EOF'
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": [
        "--from", "git+https://github.com/oraios/serena",
        "serena", "start-mcp-server",
        "--context", "desktop-app"
      ]
    },
    "swift-mcp": {
      "command": "/REPLACE_WITH_ACTUAL_PATH/.build/release/SwiftMCPServer",
      "args": ["--host", "127.0.0.1", "--port", "8081"],
      "env": {
        "SWIFT_MCP_SERVER": "http://127.0.0.1:8081"
      }
    }
  }
}
EOF

    # Replace with actual path
    CURRENT_PATH=$(pwd)
    sed -i.bak "s|/REPLACE_WITH_ACTUAL_PATH|$CURRENT_PATH|g" examples/configs/claude_desktop_config.json
    rm examples/configs/claude_desktop_config.json.bak 2>/dev/null || true
    
    # Serena project config
    cat > examples/configs/serena_project.yml << 'EOF'
name: "MySwiftApp"
language: "swift"
build_command: "swift build"
test_command: "swift test"
format_command: "swift-format format"
lint_command: "swiftlint lint"

swift_specific:
  sourcekit_lsp: true
  target_platform: "ios"
  min_version: "15.0"
  
integration:
  swift_mcp_server: "http://127.0.0.1:8081"
  enable_symbol_analysis: true
  auto_documentation: true
EOF
    
    log_success "Configuration examples created in examples/configs/"
}

# Create startup script
create_startup_script() {
    log_info "Creating startup script..."
    
    cat > start-server.sh << 'EOF'
#!/bin/bash

# Swift MCP Server Startup Script
echo "🚀 Starting Swift MCP Server..."

# Default configuration
HOST=${SWIFT_MCP_HOST:-127.0.0.1}
PORT=${SWIFT_MCP_PORT:-8081}
LOG_LEVEL=${SWIFT_MCP_LOG_LEVEL:-info}

# Check if server is already running
if curl -s http://$HOST:$PORT/health > /dev/null 2>&1; then
    echo "⚠️  Server already running on http://$HOST:$PORT"
    exit 1
fi

# Start server
echo "📡 Starting server on http://$HOST:$PORT"
exec ./.build/release/SwiftMCPServer \
    --host "$HOST" \
    --port "$PORT" \
    --log-level "$LOG_LEVEL"
EOF
    
    chmod +x start-server.sh
    log_success "Startup script created: ./start-server.sh"
}

# Show next steps
show_next_steps() {
    echo
    log_info "🎯 Next Steps:"
    echo
    echo "  1. Start the server:"
    echo "     ./start-server.sh"
    echo
    echo "  2. Test the server:"
    echo "     curl http://127.0.0.1:8081/health"
    echo
    echo "  3. Configure Claude Desktop:"
    echo "     Copy examples/configs/claude_desktop_config.json"
    echo "     to Claude Desktop settings"
    echo
    echo "  4. Read the integration guide:"
    echo "     open SERENA_INTEGRATION.md"
    echo
    echo "  5. Start using with Serena:"
    echo "     \"Activate the Swift project at /path/to/project and analyze its architecture\""
    echo
}

# Main execution
main() {
    print_header
    
    log_info "Starting Swift MCP Server setup..."
    echo
    
    # Run setup steps
    check_platform
    check_swift
    check_sourcekit_lsp
    
    echo
    log_info "Building Swift MCP Server..."
    build_server
    
    echo
    log_info "Testing server functionality..."
    test_server
    
    echo
    install_serena
    
    echo
    log_info "Creating configuration files..."
    generate_configs
    create_startup_script
    
    echo
    print_footer
    show_next_steps
}

# Run main function
main "$@"
