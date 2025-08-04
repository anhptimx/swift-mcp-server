# Configuration Files Guide

## Available Configurations

### 1. VS Code MCP Configuration (`vscode-mcp-config.json`)
Complete VS Code MCP integration with troubleshooting guide.
- **Purpose**: Direct integration with VS Code MCP extension
- **Transport**: STDIO (required for VS Code)
- **Features**: Complete troubleshooting documentation, debugging steps, configuration variations

### 2. STDIO Configuration (`stdio-config.json`)
Basic STDIO transport configuration for direct integrations.
- **Purpose**: Serena MCP integration, direct STDIO communication
- **Transport**: STDIO with HTTP fallback
- **Port Range**: 8080-8090
- **Features**: Basic Swift language support, experimental features

### 3. HTTP Configuration (`http-config.json`)
Enterprise HTTP transport configuration for web integrations.
- **Purpose**: REST API access, web service integration
- **Transport**: HTTP only
- **Port Range**: 9000-9010
- **Features**: Enhanced capabilities, performance tuning, enterprise features

## Usage Examples

### VS Code Integration
```bash
# Use vscode-mcp-config.json settings in VS Code settings.json
cp vscode-mcp-config.json ~/.vscode/settings-template.json
```

### Serena Integration
```bash
swift-mcp-server --config stdio-config.json --transport stdio
```

### HTTP API Server
```bash
swift-mcp-server --config http-config.json --transport http --port 9000
```

## Quick Setup

For immediate setup, use the provided scripts:
```bash
./quick-start.sh     # Interactive setup with config selection
./quick-fix.sh all   # Fix common configuration issues
./health-check.sh    # Verify system configuration
```
