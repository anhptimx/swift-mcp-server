# Swift MCP Server

A professional Model Context Protocol (MCP) server implementation in Swift, providing advanced static analysis and architectural insights for Swift codebases with seamless [Serena MCP](https://github.com/oraios/serena) integration.

## Overview

This server extends the standard MCP protocol with specialized tools for Swift project analysis, offering deep insights into code architecture, design patterns, and Protocol-Oriented Programming adoption. Built with Swift 5.9+ and integrated with SourceKit-LSP for accurate source code analysis.

**🚀 Perfect for Serena MCP Integration**: Transform your development workflow with powerful Swift-specific tools that integrate seamlessly with Serena's coding agent capabilities.

## Key Features

### Advanced Analysis Capabilities
- **Protocol-Oriented Programming Assessment**: Quantitative analysis with 0-100 scoring system
- **Architecture Pattern Recognition**: Automated detection of MVC, MVVM, VIPER, Clean Architecture patterns
- **Symbol Intelligence**: Enhanced search and categorization of Swift symbols
- **Project Health Metrics**: Comprehensive codebase quality assessment
- **Real-time Diagnostics**: Live compilation feedback and error reporting

### Enhanced Development Tools
- **Modern Concurrency Integration**: Advanced task management with parallel processing and resource-aware execution
- **Intelligent Project Memory**: Pattern learning system with evolutionary tracking and thread-safe caching
- **Documentation Generator**: Automatic Swift API documentation with README generation
- **iOS Framework Analyzer**: Comprehensive analysis of iOS development patterns and Apple framework usage
- **Template Generator**: Professional Swift/iOS project templates for rapid development

### Professional Integration
- **Advanced Task Management**: 10x parallel processing with intelligent resource limits and retry mechanisms
- **Thread-Safe Operations**: Actor-based architecture ensuring safe concurrent analysis
- **Resource Monitoring**: Real-time tracking of memory, CPU, and network usage during analysis
- **SourceKit-LSP Integration**: Leverages Apple's official language server protocol
- **Swift Package Manager Support**: Native SPM compatibility and workspace analysis
- **HTTP API**: RESTful interface following MCP specification
- **Scalable Architecture**: Modular design supporting large codebases with modern concurrency patterns
- **Serena MCP Compatible**: Direct integration with Serena coding agents

## Requirements

- **macOS 13.0+** or **Linux Ubuntu 18.04+**
- **Swift 5.9+** with modern concurrency support  
- **Xcode 15.0+** (macOS development)
- **SourceKit-LSP** (bundled with Xcode)

## Quick Start Guide

### Automated Setup (Recommended)

Use our automated setup script for the fastest installation:

```bash
# Clone repository
git clone https://github.com/anhptimx/swift-mcp-server.git
cd swift-mcp-server

# Run automated setup
./quick-start.sh
```

The script will:
- ✅ Check all prerequisites (Swift, SourceKit-LSP)
- 🔨 Build the server with optimizations
- 🧪 Test functionality automatically
- ⚙️ Generate configuration examples
- 🚀 Create startup scripts
- 📖 Optionally install Serena MCP

### Manual Setup

If you prefer manual setup or need custom configuration:

#### Step 1: Install Prerequisites

**macOS:**
```bash
# Install Xcode Command Line Tools (includes Swift & SourceKit-LSP)
xcode-select --install

# Verify installation
swift --version
which sourcekit-lsp
```

**Linux:**
```bash
# Install Swift
curl -s https://swift.org/install.sh | bash

# Add to PATH
echo 'export PATH="/usr/local/swift/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Step 2: Clone and Build

```bash
# Clone repository
git clone https://github.com/anhptimx/swift-mcp-server.git
cd swift-mcp-server

# Build release version
swift build --configuration release

# Build time: ~30-60 seconds depending on system
```

#### Step 3: Start the Server

```bash
# Start with default settings
./.build/release/SwiftMCPServer

# Start with custom configuration
./.build/release/SwiftMCPServer \
  --host 127.0.0.1 \
  --port 8081 \
  --log-level info
```

#### Step 4: Verify Installation

```bash
# Test server health
curl http://127.0.0.1:8081/health

# Expected response: {"status": "healthy", "server": "SwiftMCPServer"}

# Test MCP tools
curl -X POST http://127.0.0.1:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "method": "tools/list",
    "params": {}
  }'
```

#### Step 5: Test with Sample Project

```bash
# Test analyze_project tool
curl -X POST http://127.0.0.1:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "method": "tools/call",
    "params": {
      "name": "analyze_project",
      "arguments": {"project_path": "/path/to/your/swift/project"}
    }
  }'

# Should return base64-encoded JSON with project analysis
```

## Serena Integration Setup

### Install Serena MCP

```bash
# Install UV package manager
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Serena using uvx
uvx --from git+https://github.com/oraios/serena serena start-mcp-server
```

### Configure Claude Desktop

1. Open Claude Desktop: `File → Settings → Developer → MCP Servers → Edit Config`

2. Add configuration to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": [
        "--from", "git+https://github.com/oraios/serena",
        "serena", "start-mcp-server",
        "--context", "desktop-app",
        "--project", "/path/to/your/swift/project"
      ]
    },
    "swift-mcp": {
      "command": "/path/to/swift-mcp-server/.build/release/SwiftMCPServer",
      "args": ["--host", "127.0.0.1", "--port", "8081"],
      "env": {
        "SWIFT_MCP_SERVER": "http://127.0.0.1:8081"
      }
    }
  }
}
```

3. Restart Claude Desktop completely

### Usage Example

In Claude Desktop:
```
"Activate the Swift project at /path/to/MySwiftApp and analyze its architecture patterns"
```

Serena + Swift MCP Server will:
1. Activate and index your Swift project
2. Analyze architectural patterns (MVC, MVVM, etc.)
3. Provide detailed insights and suggestions
4. Enable intelligent code editing and navigation

## Configuration

### Server Configuration

Start the MCP server with production settings:

```bash
# Basic server start
./.build/release/SwiftMCPServer

# Production configuration  
./.build/release/SwiftMCPServer \
  --host 0.0.0.0 \
  --port 8081 \
  --log-level info \
  --enable-cors

# Development mode with verbose logging
./.build/release/SwiftMCPServer \
  --host 127.0.0.1 \
  --port 8081 \
  --log-level debug \
  --verbose
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--host, -h` | Server bind address | `127.0.0.1` |
| `--port, -p` | Server port | `8081` |  
| `--log-level` | Logging level (debug, info, warning, error) | `info` |
| `--log-level` | Logging level (trace, debug, info, notice, warning, error, critical) | `info` |
| `--verbose` | Enable verbose output | `false` |

### Advanced Usage

Start server with workspace analysis:
```bash
swift run swift-mcp-server --host 127.0.0.1 --port 8080 --workspace /path/to/your/swift/project
```

## Testing & Validation

### Automated Testing

Run the complete test suite:
```bash
# Execute all tests
swift test

# Run tests with verbose output
swift test --verbose

# Generate test coverage
swift test --enable-code-coverage
```

### Manual Validation

#### Quick POP Analysis Test
Create a test script to validate POP analysis on your project:

```swift
#!/usr/bin/env swift
import Foundation

// Extension for regex matching
extension String {
    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.compactMap {
                Range($0.range, in: self).map { String(self[$0]) }
            }
        } catch {
            return []
        }
    }
}

// Simple POP analysis validator
let projectPath = "/path/to/your/swift/project"
let fileManager = FileManager.default

var metrics = (swiftFiles: 0, protocols: 0, structs: 0, classes: 0)

let enumerator = fileManager.enumerator(atPath: projectPath)
while let element = enumerator?.nextObject() as? String {
    guard element.hasSuffix(".swift") else { continue }
    
    metrics.swiftFiles += 1
    let filePath = "\(projectPath)/\(element)"
    
    if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
        metrics.protocols += content.matches(for: "protocol\\s+\\w+").count
        metrics.structs += content.matches(for: "struct\\s+\\w+").count  
        metrics.classes += content.matches(for: "class\\s+\\w+").count
    }
}

let structClassRatio = metrics.classes > 0 ? Double(metrics.structs) / Double(metrics.classes) : Double(metrics.structs)
let protocolDensity = metrics.swiftFiles > 0 ? Double(metrics.protocols) / Double(metrics.swiftFiles) : 0
let popScore = min(100, Int(structClassRatio * 40 + protocolDensity * 60))

print("📊 Swift Analysis Results:")
print("   Files: \(metrics.swiftFiles)")
print("   Structs: \(metrics.structs) | Classes: \(metrics.classes)")  
print("   Protocols: \(metrics.protocols)")
print("🎯 POP Score: \(popScore)/100")
```

#### HTTP API Testing
```bash
# Test server health
curl -X GET http://localhost:8080/health

# Test tools listing
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": "1", "method": "tools/list"}'
```

## Integration Examples

### MCP Client Integration

Configure your MCP client to connect with the Swift server:

```json
{
  "mcpServers": {
    "swift-analyzer": {
      "command": "/path/to/swift-mcp-server",
      "args": ["--host", "127.0.0.1", "--port", "8080"],
      "env": {
        "WORKSPACE_PATH": "/path/to/swift/project"
      }
    }
  }
}
```

### API Usage Examples

#### Protocol-Oriented Programming Analysis
```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "tools/call", 
    "params": {
      "name": "analyze_pop_usage",
      "arguments": {
        "workspace_path": "/Users/developer/MySwiftApp"
      }
    }
  }'
```

#### Architecture Detection
```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "2", 
    "method": "tools/call",
    "params": {
      "name": "detect_architecture",
      "arguments": {
        "workspace_path": "/Users/developer/MySwiftApp"
      }
    }
  }'
```

## MCP Tools Reference

The server implements comprehensive MCP tools for Swift project analysis and development:

### Core Analysis Tools

#### `analyze_pop_usage`
**Purpose**: Evaluates Protocol-Oriented Programming adoption and provides quantitative metrics.

**Parameters**:
- `workspace_path` (string): Path to Swift project root

**Returns**: Detailed POP score (0-100), file statistics, and optimization recommendations.

#### `detect_architecture` 
**Purpose**: Identifies architectural patterns used in the codebase.

**Parameters**:
- `workspace_path` (string): Path to Swift project root

**Returns**: Detected pattern (MVC, MVVM, VIPER, Clean Architecture) with confidence score.

#### `search_symbols`
**Purpose**: Advanced symbol search with filtering and categorization capabilities.

**Parameters**:
- `query` (string): Search term for symbols
- `symbol_type` (string, optional): Filter by type (class, struct, protocol, etc.)

**Returns**: Categorized list of matching symbols with metadata.

### Enhanced Development Tools

#### `intelligent_project_memory`
**Purpose**: Manage intelligent project memory with pattern learning and caching.

**Parameters**:
- `action` (string): Action to perform (`cache`, `retrieve`, `learn_patterns`, `get_evolution`)
- `key` (string, optional): Cache key for store/retrieve operations

**Returns**: Analysis results, cached data, or learned pattern insights.

#### `generate_documentation`
**Purpose**: Generate comprehensive Swift API documentation automatically.

**Parameters**: None (analyzes current workspace)

**Returns**: Generated documentation files, project structure analysis, and API inventory.

#### `analyze_ios_frameworks`
**Purpose**: Analyze iOS development patterns and Apple framework usage.

**Parameters**: None (analyzes current workspace)

**Returns**: Framework usage statistics, UI patterns, architecture scores, and modernization recommendations.

#### `generate_template`
**Purpose**: Generate professional Swift/iOS project templates.

**Parameters**:
- `template_type` (string): Template type (`swift-package`, `uikit-viewcontroller`, `swiftui-view`, `mvvm-module`, etc.)
- `name` (string): Project/component name
- `description` (string, optional): Project description

**Returns**: Generated files list and setup instructions.

**Parameters**:
- `workspace_path` (string): Project path
- `query` (string): Symbol name or pattern
- `type` (string, optional): Filter by symbol type (class, struct, protocol, function, etc.)

#### `get_symbol_info`
**Purpose**: Detailed analysis of specific symbols including usage patterns and relationships.

**Parameters**:
- `workspace_path` (string): Project path  
- `symbol_name` (string): Target symbol name

#### `analyze_project`
**Purpose**: Comprehensive project analysis combining all available metrics.

**Parameters**:
- `workspace_path` (string): Project path

#### `get_diagnostics`
**Purpose**: Real-time compilation diagnostics and health metrics.

**Parameters**:
- `workspace_path` (string): Project path

## Available Resources

### swift://workspace
Provides information about the current Swift workspace and server capabilities.

## API Examples

### Analyze Protocol-Oriented Programming
```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "tools/call",
  "params": {
    "name": "analyze_pop_usage",
    "arguments": {
      "workspace_path": "/path/to/your/swift/project"
    }
  }
}
```

### Detect Architecture Pattern
```json
{
  "jsonrpc": "2.0", 
  "id": "2",
  "method": "tools/call",
  "params": {
    "name": "detect_architecture",
    "arguments": {
      "workspace_path": "/path/to/your/swift/project"
    }
  }
}
```

### Search for Symbols
```json
{
  "jsonrpc": "2.0",
  "id": "3", 
  "method": "tools/call",
  "params": {
    "name": "search_symbols",
    "arguments": {
      "workspace_path": "/path/to/your/swift/project",
      "query": "NetworkManager",
      "type": "class"
    }
  }
}
```

### Comprehensive Project Analysis
```json
{
  "jsonrpc": "2.0",
  "id": "4",
  "method": "tools/call", 
  "params": {
    "name": "analyze_project",
    "arguments": {
      "workspace_path": "/path/to/your/swift/project"
    }
  }
}
```

## Architecture & Implementation

### System Design

The Swift MCP Server follows a professional modular architecture optimized for performance and maintainability:

```
SwiftMCPServer/
├── Core Framework (SwiftMCPCore)
│   ├── MCPServer          # HTTP server with concurrent request handling
│   ├── MCPProtocolHandler # MCP 2.0 protocol implementation  
│   ├── SwiftLanguageServer # SourceKit-LSP integration layer
│   ├── Analysis Engine
│   │   ├── ArchitectureAnalyzer    # Pattern detection & POP analysis
│   │   ├── SymbolSearchEngine      # Advanced symbol search
│   │   └── ProjectAnalyzer         # Comprehensive project metrics
│   ├── HTTPHandler        # RESTful API request routing
│   └── MCPTypes          # Protocol type definitions & serialization
└── CLI Interface (SwiftMCPServer)
    └── main.swift        # Command-line interface & configuration
```

### Technical Features

- **Concurrency**: Built with Swift's modern async/await concurrency model
- **Performance**: Optimized for large codebases with efficient symbol caching  
- **Reliability**: Comprehensive error handling and graceful degradation
- **Extensibility**: Plugin architecture for custom analysis tools
- **Standards Compliance**: Full MCP 2.0 protocol implementation

### Key Components

#### ArchitectureAnalyzer
- **Pattern Recognition**: Uses regex-based analysis to identify architectural patterns
- **POP Scoring**: Quantitative analysis of Protocol-Oriented Programming adoption
- **Metrics Calculation**: Advanced algorithms for code quality assessment

#### SymbolSearchEngine  
- **SourceKit Integration**: Leverages Apple's official language server
- **Smart Filtering**: Context-aware symbol categorization and search
- **Performance Optimization**: Efficient indexing for large projects

#### ProjectAnalyzer
- **Holistic Analysis**: Combines multiple analysis engines for comprehensive insights
- **Memory Management**: Project state caching and incremental analysis
- **Migration Planning**: Automated recommendations for architectural improvements

## Contributing

We welcome contributions to the Swift MCP Server project. Please follow these guidelines:

### Development Process

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Implement** your changes with appropriate tests
4. **Ensure** all tests pass: `swift test`
5. **Verify** code builds without warnings: `swift build`
6. **Submit** a pull request with detailed description

### Code Standards

- Follow Swift API Design Guidelines
- Maintain test coverage above 80%
- Include documentation for public APIs
- Use SwiftLint for code style consistency

### Bug Reports

Please include:
- Swift version and platform details
- Minimal reproduction case
- Expected vs actual behavior
- Relevant log output (use `--verbose` flag)

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) file for details.

## Support & Community

### Getting Help

- 📚 **Documentation**: [Complete Integration Guide](SERENA_INTEGRATION.md)
- 🚀 **Quick Start**: [Getting Started Tutorial](https://github.com/anhptimx/swift-mcp-server/wiki/Getting-Started)
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/anhptimx/swift-mcp-server/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/anhptimx/swift-mcp-server/discussions)
- 📧 **Email Support**: swift-mcp-support@gmail.com

### Community Resources

- 🌟 **Serena MCP Integration**: [Serena Documentation](https://github.com/oraios/serena)
- 🎯 **Example Projects**: [swift-mcp-examples](https://github.com/anhptimx/swift-mcp-examples)
- 🔧 **Configuration Templates**: [mcp-configs](https://github.com/anhptimx/mcp-configs)
- 📝 **Best Practices Guide**: [Swift MCP Best Practices](https://github.com/anhptimx/swift-mcp-server/wiki/Best-Practices)

### Contributing

We welcome contributions! Areas where help is needed:

#### 🛠️ Development Areas
- **Swift 6.0 Compatibility**: Prepare for next Swift version
- **Additional iOS Frameworks**: Support for more Apple frameworks
- **Performance Optimizations**: Large project analysis improvements
- **Linux Support**: Enhanced Linux compatibility
- **Testing Infrastructure**: More comprehensive test coverage

#### 📖 Documentation & Content
- **Tutorial Videos**: Step-by-step integration guides
- **Example Projects**: Real-world usage examples
- **Translation**: Documentation in other languages
- **Blog Posts**: Technical deep-dives and case studies

#### 🤝 Community Building
- **Discord/Slack Channel**: Real-time community support
- **Conference Talks**: Presentations at Swift/iOS conferences
- **Workshops**: Training materials and workshops
- **Mentorship**: Help new contributors get started

### Development Process

1. **Fork** the repository and create a feature branch
2. **Follow** our [Contributing Guidelines](CONTRIBUTING.md)
3. **Ensure** tests pass and code follows Swift standards
4. **Submit** a detailed pull request

### Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

### Sponsorship & Support

If you find this project valuable:

- ⭐ **Star** the repository to show your support
- 🐦 **Share** on social media to help others discover it
- 💝 **Sponsor** development through [GitHub Sponsors](https://github.com/sponsors/anhptimx)
- 🏢 **Enterprise Support**: Contact us for commercial support options

### Roadmap & Future Plans

#### Q1 2025
- [ ] Swift 6.0 compatibility
- [ ] Enhanced Serena integration features
- [ ] Performance optimizations for large projects
- [ ] Comprehensive documentation update

#### Q2 2025
- [ ] Linux distribution packages
- [ ] Visual Studio Code extension
- [ ] Advanced project templates
- [ ] Real-time collaboration features

#### Community Goals
- [ ] 1000+ GitHub stars
- [ ] Active community of 100+ contributors
- [ ] Integration with major Swift IDEs
- [ ] Conference presentations and workshops

### Related Projects & Ecosystem

- 🎯 **[Serena MCP](https://github.com/oraios/serena)** - Powerful coding agent toolkit
- 📝 **[SourceKit-LSP](https://github.com/swiftlang/sourcekit-lsp)** - Official Swift Language Server
- 🔧 **[Model Context Protocol](https://modelcontextprotocol.io/)** - MCP specification
- 📦 **[Swift Package Manager](https://github.com/apple/swift-package-manager)** - Swift's build system
- 🛠️ **[Claude Desktop](https://claude.ai/download)** - AI assistant with MCP support

---

**Swift MCP Server** - Professional static analysis for Swift projects with seamless Serena MCP integration  
Copyright © 2025 [anhptimx](https://github.com/anhptimx) | MIT License | Made with ❤️ for the Swift community
