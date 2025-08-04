import ArgumentParser
import Foundation
import Logging
import SwiftMCPCore

@main
struct SwiftMCPApp {
    static func main() async throws {
        await SwiftMCPServer.main()
    }
}

// Swift MCP Server Command - no @main needed, will be called directly
struct SwiftMCPServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-mcp-server",
        abstract: "Swift MCP Server for Serena MCP integration with SourceKit-LSP support",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = 8080
    
    @Option(name: .shortAndLong, help: "Host to bind to")
    var host: String = "127.0.0.1"
    
    @Option(name: .long, help: "Workspace path for Swift projects")
    var workspace: String?
    
    @Option(name: .long, help: "Log level (trace, debug, info, notice, warning, error, critical)")
    var logLevel: String = "info"
    
    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false
    
    mutating func run() async throws {
        // Setup logging
        var logger = Logger(label: "swift-mcp-server")
        logger.logLevel = parseLogLevel(logLevel)
        
        if verbose {
            logger.logLevel = .trace
        }
        
        logger.info("Starting Swift MCP Server")
        logger.info("Version: \(Self.configuration.version)")
        logger.info("Host: \(host)")
        logger.info("Port: \(port)")
        if let workspace = workspace {
            logger.info("Workspace: \(workspace)")
        }
        
        // Create workspace URL if provided
        let workspaceURL = workspace.map { URL(fileURLWithPath: $0) }
        
        // Create and start the MCP server
        let server = MCPServer(
            host: host,
            port: port,
            logger: logger,
            workspaceRoot: workspaceURL
        )
        
        try await server.start()
    }
    
    private func parseLogLevel(_ level: String) -> Logger.Level {
        switch level.lowercased() {
        case "trace": return .trace
        case "debug": return .debug
        case "info": return .info
        case "notice": return .notice
        case "warning": return .warning
        case "error": return .error
        case "critical": return .critical
        default: return .info
        }
    }
}
