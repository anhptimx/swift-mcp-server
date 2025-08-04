# Contributing to Swift MCP Server

Thank you for your interest in contributing to Swift MCP Server! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)

## Getting Started

### Prerequisites

- macOS 13.0+ or Linux Ubuntu 18.04+
- Swift 5.9+ with modern concurrency support
- Xcode 15.0+ (for macOS development)
- Git

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/yourusername/swift-mcp-server.git
   cd swift-mcp-server
   ```

2. **Build and Test**
   ```bash
   swift build
   swift test
   ./test-integration.sh
   ```

3. **Run Quick Start**
   ```bash
   ./quick-start.sh
   ```

## Code Style

### Swift Style Guidelines

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use Swift 6 concurrency patterns (async/await, actors)
- Prefer Protocol-Oriented Programming when appropriate
- Use meaningful variable and function names
- Add documentation for public APIs

### Example Code Style

```swift
/// Analyzes Swift project architecture patterns
actor ProjectAnalyzer {
    private let workspace: URL
    private var analysisCache: [String: AnalysisResult] = [:]
    
    /// Performs comprehensive project analysis
    /// - Parameter options: Analysis configuration options
    /// - Returns: Detailed analysis results
    func analyze(options: AnalysisOptions) async throws -> AnalysisResult {
        // Implementation
    }
}
```

### Concurrency Guidelines

- Use actors for shared mutable state
- Prefer structured concurrency (async/await) over completion handlers
- Use `@MainActor` for UI-related code
- Avoid mixing sync/async contexts inappropriately

## Testing

### Unit Tests

```bash
swift test
```

### Integration Tests

```bash
./test-integration.sh
```

### Test Guidelines

- Write tests for new features
- Ensure existing tests pass
- Test both success and failure scenarios
- Use descriptive test names

### Example Test

```swift
func testSymbolSearch() async throws {
    let server = try MCPServer(workspace: testWorkspace)
    let symbols = try await server.findSymbols(pattern: "TestClass")
    XCTAssertFalse(symbols.isEmpty)
    XCTAssertTrue(symbols.contains { $0.name == "TestClass" })
}
```

## Pull Request Process

### Before Submitting

1. **Update Documentation**: Ensure README.md and other docs are updated
2. **Run Tests**: All tests must pass
3. **Code Review**: Self-review your changes
4. **Clean History**: Squash commits if necessary

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

### Review Process

1. **Automated Checks**: CI must pass
2. **Code Review**: At least one maintainer review
3. **Testing**: Integration tests in target environment
4. **Merge**: Squash and merge when approved

## Issue Reporting

### Bug Reports

Include:
- Swift version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Error messages/logs

### Feature Requests

Include:
- Use case description
- Proposed solution
- Alternative solutions considered
- Additional context

### Template

```markdown
**Environment:**
- Swift Version: [e.g., 5.9]
- OS: [e.g., macOS 14.0]
- Xcode: [e.g., 15.0]

**Description:**
[Clear description]

**Steps to Reproduce:**
1. [First step]
2. [Second step]
3. [See error]

**Expected Behavior:**
[What you expected]

**Actual Behavior:**
[What actually happened]

**Additional Context:**
[Any other relevant information]
```

## Development Guidelines

### Architecture

- Follow MCP protocol specifications
- Use modular design patterns
- Implement proper error handling
- Ensure thread safety with actors

### Performance

- Use async/await for I/O operations
- Implement proper resource management
- Cache frequently accessed data
- Monitor memory usage

### Security

- Validate all inputs
- Sanitize file paths
- Handle sensitive data appropriately
- Follow secure coding practices

## Getting Help

- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Create issues for bugs/features
- **Documentation**: Check existing documentation first

## Recognition

Contributors will be acknowledged in:
- CHANGELOG.md
- GitHub contributors page
- Release notes (for significant contributions)

Thank you for contributing to Swift MCP Server! 🚀
