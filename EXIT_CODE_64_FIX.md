# Fix for "MCP server could not be started: Process exited with code 64"

## ✅ Problem Analysis

The server binary is working correctly:
- ✅ Build successful
- ✅ Binary exists and has correct permissions  
- ✅ HTTP mode works fine
- ✅ STDIO mode works with manual testing

Exit code 64 typically indicates **argument parsing errors** or **incorrect configuration**.

## 🛠️ Solutions

### 1. **Fix VS Code Configuration**

Copy this configuration to your VS Code `settings.json`:

```json
{
  "mcp": {
    "servers": {
      "swift-mcp-server": {
        "command": "/path/to/swift-mcp-server/.build/release/swift-mcp-server",
        "args": [
          "--transport", "stdio",
          "--workspace", "${workspaceFolder}",
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
```

### 2. **Use Absolute Paths**

❌ **Wrong**: `"command": "swift-mcp-server"`
✅ **Correct**: `"command": "/full/path/to/.build/release/swift-mcp-server"`

### 3. **Verify Working Directory**

Make sure VS Code is opening the workspace that contains your Swift MCP Server binary.

### 4. **Check Permissions**

```bash
# Ensure binary is executable
chmod +x /path/to/swift-mcp-server/.build/release/swift-mcp-server

# Test manually
/path/to/swift-mcp-server/.build/release/swift-mcp-server --help
```

### 5. **Test STDIO Mode**

```bash
# Manual test
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}' | \
  /path/to/swift-mcp-server/.build/release/swift-mcp-server \
  --transport stdio \
  --workspace /path/to/your/project
```

## 🎯 Quick Commands

```bash
# Rebuild everything
./quick-fix.sh all

# Just fix VS Code config  
./quick-fix.sh vscode

# Test functionality
./health-check.sh
```

## ✅ Verification

If working correctly, you should see:
1. VS Code loads the server without errors
2. MCP extension shows "swift-mcp-server" as connected
3. You can use Swift analysis features in VS Code

## 📋 Common Issues

- **Path issues**: Use absolute paths, not relative
- **Workspace mismatch**: Ensure VS Code workspace matches server workspace
- **Missing arguments**: Don't forget `--transport stdio` and `--workspace`
- **Environment**: Make sure PATH includes necessary directories
