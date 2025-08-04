import ArgumentParser
import Foundation
import Logging
import SwiftMCPCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

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
    
    @Option(name: .long, help: "Minimum port for auto-selection (e.g., --port-min 8080)")
    var portMin: Int?
    
    @Option(name: .long, help: "Maximum port for auto-selection (e.g., --port-max 8090)")
    var portMax: Int?
    
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
        
        // Determine the port to use
        let selectedPort = try selectPort()
        logger.info("Port: \(selectedPort)")
        
        if let workspace = workspace {
            logger.info("Workspace: \(workspace)")
        }
        
        // Create workspace URL if provided
        let workspaceURL = workspace.map { URL(fileURLWithPath: $0) }
        
        // Create and start the MCP server
        let server = MCPServer(
            host: host,
            port: selectedPort,
            logger: logger,
            workspaceRoot: workspaceURL
        )
        
        try await server.start()
    }
    
    private func selectPort() throws -> Int {
        // If port range is specified, find an available port in range
        if let minPort = portMin, let maxPort = portMax {
            guard minPort <= maxPort else {
                throw ValidationError("Port minimum (\(minPort)) cannot be greater than maximum (\(maxPort))")
            }
            
            for candidatePort in minPort...maxPort {
                if isPortAvailable(candidatePort) {
                    return candidatePort
                }
            }
            throw ValidationError("No available ports found in range \(minPort)-\(maxPort)")
        }
        
        // If only min or max is specified, use a default range
        if let minPort = portMin {
            for candidatePort in minPort...(minPort + 100) {
                if isPortAvailable(candidatePort) {
                    return candidatePort
                }
            }
            throw ValidationError("No available ports found starting from \(minPort)")
        }
        
        if let maxPort = portMax {
            let minPort = max(1024, maxPort - 100)
            for candidatePort in minPort...maxPort {
                if isPortAvailable(candidatePort) {
                    return candidatePort
                }
            }
            throw ValidationError("No available ports found up to \(maxPort)")
        }
        
        // Default: use specified port or check if it's available
        if isPortAvailable(port) {
            return port
        } else {
            // Auto-find from default port
            for candidatePort in port...(port + 100) {
                if isPortAvailable(candidatePort) {
                    return candidatePort
                }
            }
            throw ValidationError("No available ports found starting from \(port)")
        }
    }
    
    private func isPortAvailable(_ port: Int) -> Bool {
        let socket = socket(AF_INET, SOCK_STREAM, 0)
        guard socket != -1 else { return false }
        
        defer { close(socket) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
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
