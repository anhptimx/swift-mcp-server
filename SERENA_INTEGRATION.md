# Serena MCP Integration Guide

This guide explains how to integrate the Swift MCP Server with Serena MCP for comprehensive Swift language support.

## Prerequisites

1. **Swift MCP Server**: Ensure the Swift MCP Server is built and running
2. **Serena MCP**: Have Serena MCP installed and configured
3. **SourceKit-LSP**: Available through Xcode installation

## Configuration

### 1. Start Swift MCP Server

```bash
# Build the server
swift build -c release

# Start the server
.build/release/swift-mcp-server --host 127.0.0.1 --port 8080 --verbose
```

### 2. Configure Serena MCP

Add the Swift MCP server to your Serena MCP configuration:

```json
{
  "mcpServers": {
    "swift-language-server": {
      "command": "/path/to/swift-mcp-server/.build/release/swift-mcp-server",
      "args": ["--host", "127.0.0.1", "--port", "8080"],
      "env": {
        "SOURCEKIT_LSP_SERVER_PATH": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"
      },
      "transport": {
        "type": "http",
        "host": "127.0.0.1",
        "port": 8080
      }
    }
  }
}
```

### 3. Verify Integration

Test the integration by calling the Swift tools through Serena:

```bash
# Test symbol search
serena-mcp call swift-language-server find_symbols --file-path "/path/to/MyClass.swift" --name-pattern "MyClass"

# Test reference finding
serena-mcp call swift-language-server find_references --file-path "/path/to/MyClass.swift" --line 10 --character 15
```

## Available Serena MCP Mappings

The Swift MCP Server provides tools that map to Serena MCP's expected functionality:

### Symbol Operations

| Serena MCP Function | Swift MCP Tool | Description |
|-------------------|---------------|-------------|
| `find_symbol` | `find_symbols` | Find Swift symbols by name pattern |
| `find_referencing_symbols` | `find_references` | Find all references to a symbol |
| `get_symbols_overview` | `find_symbols` | Get overview of symbols in a file |

### Code Navigation

| Serena MCP Function | Swift MCP Tool | Description |
|-------------------|---------------|-------------|
| Go to Definition | `get_definition` | Jump to symbol definition |
| Hover Information | `get_hover_info` | Get detailed symbol information |

### Code Formatting

| Serena MCP Function | Swift MCP Tool | Description |
|-------------------|---------------|-------------|
| Format Document | `format_document` | Format Swift code |

## Example Serena MCP Workflow

Here's an example of how Serena MCP can use the Swift MCP Server for Swift development:

### 1. Project Exploration
```python
# Serena MCP can find all classes in a Swift file
symbols = serena.call_tool("swift-language-server", "find_symbols", {
    "file_path": "/project/Sources/MyApp/Models/User.swift",
    "name_pattern": "class"
})

# Get detailed information about a specific symbol
hover_info = serena.call_tool("swift-language-server", "get_hover_info", {
    "file_path": "/project/Sources/MyApp/Models/User.swift",
    "line": 5,
    "character": 10
})
```

### 2. Code Analysis
```python
# Find all references to a method
references = serena.call_tool("swift-language-server", "find_references", {
    "file_path": "/project/Sources/MyApp/Models/User.swift",
    "line": 15,
    "character": 8
})

# Navigate to definition
definition = serena.call_tool("swift-language-server", "get_definition", {
    "file_path": "/project/Sources/MyApp/ViewModels/UserViewModel.swift",
    "line": 20,
    "character": 12
})
```

### 3. Code Formatting
```python
# Format a Swift file
formatted = serena.call_tool("swift-language-server", "format_document", {
    "file_path": "/project/Sources/MyApp/Views/UserView.swift"
})
```

## Advanced Configuration

### Custom SourceKit-LSP Path

If you have a custom SourceKit-LSP installation:

```json
{
  "mcpServers": {
    "swift-language-server": {
      "command": "/path/to/swift-mcp-server/.build/release/swift-mcp-server",
      "args": ["--host", "127.0.0.1", "--port", "8080"],
      "env": {
        "SOURCEKIT_LSP_SERVER_PATH": "/usr/local/bin/sourcekit-lsp",
        "TOOLCHAIN_PATH": "/usr/local/swift"
      }
    }
  }
}
```

### Multiple Swift Projects

For multiple Swift projects, you can run multiple instances:

```json
{
  "mcpServers": {
    "swift-project-a": {
      "command": "/path/to/swift-mcp-server/.build/release/swift-mcp-server",
      "args": ["--host", "127.0.0.1", "--port", "8080"],
      "env": {
        "WORKSPACE_ROOT": "/path/to/project-a"
      }
    },
    "swift-project-b": {
      "command": "/path/to/swift-mcp-server/.build/release/swift-mcp-server",
      "args": ["--host", "127.0.0.1", "--port", "8081"],
      "env": {
        "WORKSPACE_ROOT": "/path/to/project-b"
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Server not starting**: Check that the port is not in use
2. **SourceKit-LSP not found**: Ensure Xcode is installed or set `SOURCEKIT_LSP_SERVER_PATH`
3. **Permission denied**: Make sure the executable has proper permissions

### Debug Mode

Run with verbose logging to troubleshoot issues:

```bash
.build/release/swift-mcp-server --verbose --log-level debug
```

### Logs

Monitor Serena MCP logs for integration issues:

```bash
tail -f ~/.serena-mcp/logs/swift-language-server.log
```

## Performance Considerations

- The Swift MCP Server uses SourceKit-LSP which may take time to index large projects
- Consider warming up the server by accessing a few symbols after startup
- For large codebases, the initial symbol search may be slower

## Security

- The server only accepts connections from localhost by default
- For remote access, use SSH tunneling or VPN
- Consider firewall rules for production deployments

## Support

For issues specific to Serena MCP integration:
1. Check both Swift MCP Server and Serena MCP logs
2. Verify the configuration matches the expected format
3. Test tools individually before debugging the integration
