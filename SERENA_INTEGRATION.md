# Swift MCP Server - Serena Integration Guide

## Overview

This Swift MCP Server provides seamless integration with [Serena MCP](https://github.com/oraios/serena), enabling semantic Swift code analysis and intelligent development workflows. The server implements the Model Context Protocol (MCP) to provide powerful Swift language support for Serena's coding agent capabilities.

## What is Serena?

Serena is a powerful coding agent toolkit that turns LLMs into fully-featured development agents. It provides:
- 🔧 Semantic code retrieval and editing tools (like IDE capabilities)
- 🚀 Symbol-level code understanding and manipulation
- 🆓 Free & open-source alternative to subscription-based coding agents
- 📱 MCP integration with Claude Desktop, Claude Code, VSCode, Cursor, and more

## Prerequisites

- macOS 13.0+ (required for SourceKit-LSP)
- Swift 5.9+
- Xcode Command Line Tools
- UV package manager (for Serena)

## Installation & Setup

### 1. Install Serena

First, install UV if you haven't already:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then install Serena:
```bash
# Using uvx (recommended)
uvx --from git+https://github.com/oraios/serena serena start-mcp-server

# Or clone locally
git clone https://github.com/oraios/serena
cd serena
uv run serena config edit  # Optional: edit configuration
```
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
## Usage Examples

### Basic Project Analysis

```bash
# Start a conversation in Claude Desktop
"Activate the Swift project at /Users/myuser/MySwiftApp and analyze its architecture"

# Serena will:
# 1. Activate the project using its tools
# 2. Call Swift MCP Server to analyze the project
# 3. Provide comprehensive analysis with architectural insights
```

### Code Refactoring Workflow

```bash
# In Claude Desktop or Claude Code
"Help me refactor the networking layer in my Swift app to use async/await"

# Combined workflow:
# 1. Serena finds relevant networking symbols
# 2. Swift MCP Server analyzes current patterns
# 3. Serena suggests and implements refactoring
# 4. Swift MCP Server validates changes
```

### Documentation Generation

```bash
"Generate comprehensive documentation for my Swift framework"

# Process:
# 1. Swift MCP Server analyzes all public APIs
# 2. Generates documentation with examples
# 3. Serena organizes and formats output
# 4. Creates proper DocC documentation structure
```

## Configuration Options

### Swift MCP Server Configuration

Environment variables:
```bash
export SWIFT_MCP_HOST=127.0.0.1
export SWIFT_MCP_PORT=8081
export SWIFT_MCP_LOG_LEVEL=info
export SOURCEKIT_LSP_PATH=/usr/bin/sourcekit-lsp
```

Command line options:
```bash
./.build/release/SwiftMCPServer \
  --host 127.0.0.1 \
  --port 8081 \
  --log-level info \
  --enable-cors \
  --project-root /path/to/project
```

### Serena Configuration

Create `.serena/project.yml` in your Swift project:
```yaml
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
```

## Advanced Features

### Project Memory & Learning

Serena can create persistent memories about your Swift projects:
```bash
"Learn about this Swift project and remember its patterns for future sessions"

# Creates memories about:
# - Architecture patterns used
# - Common naming conventions
# - Key frameworks and dependencies
# - Testing strategies
# - Build configurations
```

### Multi-Target Analysis

For complex Swift projects with multiple targets:
```bash
"Analyze all targets in this workspace and show their relationships"

# Provides:
# - Target dependency graph
# - Shared code analysis
# - Cross-target symbol usage
# - Build configuration differences
```

### iOS Framework Integration

Specialized analysis for iOS/macOS development:
```bash
"Analyze this iOS app for SwiftUI best practices and suggest improvements"

# Includes:
# - SwiftUI view hierarchy analysis
# - State management patterns
# - Performance optimization suggestions
# - Accessibility compliance checks
```

## Troubleshooting

### Common Issues

1. **SourceKit-LSP not found**
   ```bash
   # Install Xcode Command Line Tools
   xcode-select --install
   
   # Verify SourceKit-LSP installation
   which sourcekit-lsp
   ```

2. **Swift MCP Server not responding**
   ```bash
   # Check if server is running
   curl http://127.0.0.1:8081/health
   
   # Check logs
   tail -f swift-mcp-server.log
   ```

3. **Serena can't connect to Swift MCP Server**
   ```bash
   # Verify network connectivity
   nc -zv 127.0.0.1 8081
   
   # Check firewall settings
   sudo lsof -i :8081
   ```

4. **Claude Desktop not recognizing tools**
   - Fully quit Claude Desktop (check system tray)
   - Verify JSON configuration syntax
   - Check MCP server logs for errors

### Debug Mode

Enable debug logging:
```bash
# Swift MCP Server
./.build/debug/SwiftMCPServer --log-level debug

# Serena
uv run serena start-mcp-server --log-level debug
```

### Performance Optimization

For large Swift projects:
```bash
# Index project for faster analysis
cd /path/to/swift/project
serena project index

# Use build cache
swift build --enable-build-cache

# Exclude generated files
echo "/.build\n/DerivedData\n*.xcodeproj" >> .gitignore
```

## Best Practices

### Project Structure

Organize your Swift project for optimal analysis:
```
MySwiftApp/
├── Sources/
│   ├── Core/           # Core business logic
│   ├── UI/            # User interface components
│   ├── Data/          # Data layer
│   └── Utils/         # Utilities and extensions
├── Tests/
├── Documentation/
├── .serena/           # Serena project configuration
└── Package.swift      # Swift Package Manager
```

### Workflow Recommendations

1. **Start with Analysis**: Always begin sessions with project analysis
2. **Use Memories**: Let Serena learn your project patterns
3. **Iterative Development**: Make small, testable changes
4. **Documentation First**: Generate docs before major refactoring
5. **Test Integration**: Leverage Swift's testing frameworks

### Code Quality

Configure quality tools:
```yaml
# .serena/project.yml
quality_tools:
  linter: "swiftlint"
  formatter: "swift-format"
  analyzer: "swift-mcp-server"
  
checks:
  - "swift_conventions"
  - "memory_management"
  - "performance_patterns"
  - "security_practices"
```

## Examples & Templates

### SwiftUI App Template

```swift
// Template generated by Swift MCP Server + Serena
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationView {
            // Generated UI code
        }
        .environmentObject(viewModel)
    }
}
```

### Package.swift Template

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "MySwiftPackage", targets: ["MySwiftPackage"])
    ],
    dependencies: [
        // Add your dependencies here
    ],
    targets: [
        .target(name: "MySwiftPackage"),
        .testTarget(name: "MySwiftPackageTests", dependencies: ["MySwiftPackage"])
    ]
)
```

## Support & Community

### Getting Help

- 📖 [Serena Documentation](https://github.com/oraios/serena)
- 🚀 [Swift MCP Server Repository](https://github.com/your-username/swift-mcp-server)
- 🐛 [Report Issues](https://github.com/your-username/swift-mcp-server/issues)
- 💬 [Discussions](https://github.com/oraios/serena/discussions)
- 📧 Community Support: serena-mcp@oraios-ai.de

### Contributing

We welcome contributions! Areas where help is needed:
- Additional Swift-specific tools
- iOS/macOS framework integrations
- Performance optimizations
- Documentation improvements
- Testing and bug reports

### Community Projects

Join the growing community of Serena + Swift MCP users:
- Share your configurations and workflows
- Contribute Swift-specific templates
- Help test new features
- Translate documentation

## Conclusion

The Swift MCP Server + Serena integration provides a powerful, free alternative to subscription-based coding assistants. With semantic Swift understanding, intelligent code analysis, and seamless MCP integration, it enables productive Swift development workflows while keeping you in control of your tools and costs.

Start exploring by activating your first Swift project and letting Serena learn your codebase!
