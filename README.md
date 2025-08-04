# Swift MCP Server

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Linux-blue.svg)](https://github.com/anhptimx/swift-mcp-server)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift 6](https://img.shields.io/badge/Swift%206-Compatible-red.svg)](https://swift.org)

> **Enterprise Model Context Protocol (MCP) server for Swift projects. Dual transport support for VS Code, Serena, and HTTP clients.**

## Overview

Swift MCP Server provides comprehensive Swift project analysis through the Model Context Protocol. Built with dual transport architecture supporting both HTTP APIs and STDIO integration for maximum compatibility.

### Key Features

- 🔄 **Dual Transport**: HTTP server + STDIO for VS Code/Serena integration  
- 🛠️ **15+ Analysis Tools**: Symbol search, references, architecture analysis
- 🏢 **Enterprise Ready**: JSON config, structured logging, graceful shutdown
- ⚡ **Swift 6 Compatible**: Modern concurrency and production-ready architecture
- 📊 **Real-time Analysis**: Live compilation feedback and performance metrics
- 🎯 **VS Code Integration**: Direct STDIO support for MCP extensions

## Quick Start

### Installation

```bash
# Clone and build
git clone https://github.com/anhptimx/swift-mcp-server.git
cd swift-mcp-server
swift build --configuration release
```

### Usage

#### VS Code/Serena Integration (STDIO)
```bash
# Direct integration with VS Code MCP extensions
swift-mcp-server --transport stdio --workspace /path/to/project
```

#### HTTP API Server
```bash
# HTTP server with intelligent port selection
swift-mcp-server --transport http --port-min 8080 --port-max 8090
```

#### Enterprise Deployment
```bash
# JSON configuration with advanced features
swift-mcp-server --config enterprise-config.json --json-logs
```

## VS Code Integration

### Setup

Add to your VS Code MCP configuration:

```json
{
  "mcp.servers": {
    "swift-mcp-server": {
      "command": "/path/to/swift-mcp-server/.build/release/swift-mcp-server",
      "args": ["--transport", "stdio", "--workspace", "${workspaceFolder}"],
      "env": {
        "SWIFT_MCP_MODE": "vscode"
      }
    }
  }
}
```

### Available Tools

- `find_symbols` - Search Swift symbols with intelligent filtering
- `find_references` - Find all references to symbols  
- `get_definition` - Navigate to symbol definitions
- `analyze_project` - Complete project analysis and metrics
- `generate_documentation` - Auto-generate project documentation
- `analyze_architecture` - Architectural pattern detection

## Configuration

### Command Line Options

```bash
swift-mcp-server --help

# Key options:
--transport <mode>        # http, stdio (default: http)
--workspace <path>        # Swift project path
--config <file>          # JSON configuration file
--port-min <min>         # Auto port selection range
--port-max <max>         # Auto port selection range
--log-level <level>      # Logging verbosity
--json-logs             # Structured JSON output
```

### Enterprise Configuration

Create `config.json` for advanced deployment:

```json
{
  "mcpServer": {
    "transport": {
      "type": "http",
      "host": "0.0.0.0", 
      "portRange": {"min": 9000, "max": 9010}
    }
  },
  "performance": {
    "maxConcurrentTasks": 10,
    "taskTimeoutSeconds": 30.0
  }
}
```

## API Documentation

### Available MCP Tools

#### Core Analysis
- `analyze_project` - Complete project analysis with metrics
- `find_symbols` - Advanced symbol search and filtering
- `find_references` - Symbol reference tracking
- `get_definition` - Symbol definition lookup

#### Architecture Analysis
- `analyze_architecture` - Pattern detection (MVC, MVVM, VIPER)
- `analyze_pop_usage` - Protocol-Oriented Programming assessment
- `generate_documentation` - Automatic API documentation

#### Development Tools
- `format_document` - Swift code formatting
- `get_hover_info` - Symbol information and documentation

### HTTP API Examples

```bash
# List available tools
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"method": "tools/list", "params": {}}'

# Analyze project structure
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "method": "tools/call",
    "params": {
      "name": "analyze_project",
      "arguments": {"project_path": "/path/to/project"}
    }
  }'
```

## Architecture

### Project Structure

```
Sources/
├── SwiftMCPServer/           # Main application entry point
│   └── SwiftMCPApp.swift     # CLI interface with dual transport
├── SwiftMCPCore/             # Core MCP server implementation
│   ├── MCPServer.swift       # HTTP transport server
│   ├── StdioTransport.swift  # STDIO transport for VS Code
│   ├── ServerConfiguration.swift # Enterprise configuration
│   └── SwiftLanguageServer.swift # Swift analysis engine
└── ModernConcurrency/        # Advanced concurrency features
    ├── FCITaskManager.swift  # Task management and coordination
    └── FCIModernThreadSafety.swift # Thread safety utilities
```

### Transport Architecture

- **HTTP Transport**: RESTful API server with intelligent port management
- **STDIO Transport**: Direct JSON-RPC communication for VS Code integration
- **Unified Core**: Shared analysis engine serving both transport modes

## Development

### Requirements

- Swift 5.9+ (Swift 6 compatible)
- macOS 13.0+ or Linux Ubuntu 18.04+
- Xcode 15.0+ (includes SourceKit-LSP)

### Building

```bash
# Debug build
swift build

# Release build with optimizations
swift build --configuration release

# Run tests
swift test
```

### Development Mode

```bash
# Enable development mode with enhanced debugging
swift-mcp-server --transport http --dev --log-level debug --workspace .
```

## Troubleshooting

### Server Configuration Issues

#### MCP Server Not Starting
```bash
# Check if server is running
ps aux | grep swift-mcp-server

# Test server health
curl http://localhost:8080/health

# Check logs for errors
swift-mcp-server --log-level debug --workspace .
```

#### STDIO Transport Issues
```bash
# Test STDIO communication
echo '{"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}}}' | \
  swift-mcp-server --transport stdio --workspace . --log-level debug

# Expected output: JSON response with server capabilities
```

#### Port Conflicts
```bash
# Check port availability
lsof -i :8080

# Use auto port selection
swift-mcp-server --port-min 8080 --port-max 8090

# Check which port was selected from logs
```

### Path Issues

#### Project Path Not Recognized
```bash
# Verify path exists and is accessible
ls -la /path/to/your/swift/project

# Check for Package.swift
find /path/to/project -name "Package.swift" -type f

# Use absolute paths
swift-mcp-server --workspace "$(pwd)/path/to/project"

# Check workspace permissions
chmod -R 755 /path/to/your/project
```

#### SourceKit-LSP Path Issues
```bash
# Verify SourceKit-LSP installation
which sourcekit-lsp

# Expected: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp

# If not found, install Xcode Command Line Tools
xcode-select --install

# Set correct Xcode path
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Dependencies Issues

#### Swift Package Dependencies
```bash
# Resolve package dependencies
swift package resolve

# Update dependencies
swift package update

# Clean and rebuild
swift package clean && swift build
```

#### VS Code MCP Extension Dependencies
```bash
# Install VS Code MCP extension
code --install-extension your-mcp-extension

# Check VS Code configuration
cat ~/.vscode/settings.json | grep mcp

# Restart VS Code after configuration changes
```

#### Serena Integration Dependencies
```bash
# Install UV package manager (required for Serena)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Serena MCP
uvx --from git+https://github.com/oraios/serena serena start-mcp-server

# Verify Serena installation
serena --version
```

### Common Configuration Fixes

#### Fix VS Code Configuration
```json
{
  "mcp.servers": {
    "swift-mcp-server": {
      "command": "/absolute/path/to/swift-mcp-server/.build/release/swift-mcp-server",
      "args": [
        "--transport", "stdio",
        "--workspace", "${workspaceFolder}",
        "--log-level", "info"
      ],
      "env": {
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/usr/bin"
      },
      "cwd": "${workspaceFolder}"
    }
  }
}
```

#### Fix Environment Variables
```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"
export SOURCEKIT_LSP_PATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"

# Reload shell
source ~/.zshrc
```

#### Debug Configuration
```bash
# Test with maximum verbosity
swift-mcp-server \
  --transport stdio \
  --workspace "$(pwd)" \
  --log-level trace \
  --dev \
  --json-logs

# Check server capabilities
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"method": "initialize", "params": {"protocolVersion": "2024-11-05"}}'
```

### Health Check & Quick Fixes

We provide automated scripts to help with setup and troubleshooting:

#### Health Check Script

Run the comprehensive health check:

```bash
./health-check.sh
```

This script verifies:
- Swift installation and version
- SourceKit-LSP availability  
- Xcode path configuration
- Server binary existence
- Package dependencies
- Transport modes functionality

#### Quick Fix Script

For automatic issue resolution:

```bash
# Run all fixes
./quick-fix.sh all

# Fix specific issues
./quick-fix.sh permissions    # Fix file permissions
./quick-fix.sh rebuild        # Clean rebuild  
./quick-fix.sh vscode         # Fix VS Code config
./quick-fix.sh sourcekit      # Fix SourceKit-LSP path
./quick-fix.sh test          # Test functionality
```

The quick fix script automatically:
- Fixes file permissions
- Rebuilds the server cleanly
- Creates proper VS Code MCP configuration
- Sets up SourceKit-LSP paths
- Tests server functionality
## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Swift 6 language mode requirements
- Add tests for new features
- Update documentation for API changes
- Ensure zero compiler warnings

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Swift 6 and modern concurrency patterns
- Integrates with SourceKit-LSP for accurate Swift analysis
- Compatible with VS Code MCP ecosystem and Serena coding agents
