import Foundation
import Logging

/// STDIO transport implementation for MCP protocol
/// Compatible with VS Code MCP and Serena integration
public final class StdioTransport: @unchecked Sendable {
    private let logger: Logger
    private let swiftLanguageServer: SwiftLanguageServer
    private let mcpProtocolHandler: MCPProtocolHandler
    private let modernConcurrency: ModernConcurrencyIntegration
    
    public init(logger: Logger, workspaceRoot: URL? = nil) {
        self.logger = logger
        
        // Initialize modern concurrency integration
        self.modernConcurrency = ModernConcurrencyIntegration(logger: logger)
        
        self.swiftLanguageServer = SwiftLanguageServer(logger: logger, workspaceRoot: workspaceRoot)
        self.mcpProtocolHandler = MCPProtocolHandler(
            swiftLanguageServer: swiftLanguageServer,
            logger: logger
        )
    }
    
    public func start() async throws {
        logger.info("🚀 Swift MCP Server started with STDIO transport")
        logger.info("📊 Modern concurrency enabled with enhanced task management")
        logger.info("🛠️ Server is ready to handle MCP requests via STDIO")
        
        // Log resource usage
        let resourceUsage = await modernConcurrency.getResourceUsage()
        logger.info("💾 Initial resource usage - Memory: \(resourceUsage.memoryMB)MB, CPU: \(resourceUsage.cpuPercentage)%, Network: \(resourceUsage.networkOperations)")
        
        // Main STDIO loop
        while true {
            guard let line = readLine() else {
                logger.debug("STDIO input closed, shutting down")
                break
            }
            
            // Skip empty lines
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            logger.trace("Received STDIO input: \(line)")
            
            // Process MCP request
            do {
                let response = try await processRequest(line)
                
                // Send response to stdout
                print(response)
                fflush(stdout)
                
                logger.trace("Sent STDIO response: \(response)")
            } catch {
                logger.error("Error processing request: \(error)")
                
                // Send error response
                let errorResponse = createErrorResponse(error: error)
                print(errorResponse)
                fflush(stdout)
            }
        }
        
        // Cleanup
        await shutdown()
    }
    
    private func processRequest(_ input: String) async throws -> String {
        // Parse JSON-RPC request
        guard let data = input.data(using: .utf8) else {
            throw StdioError.invalidInput
        }
        
        let decoder = JSONDecoder()
        let request = try decoder.decode(MCPRequest.self, from: data)
        
        // Process through MCP protocol handler
        let response = try await mcpProtocolHandler.handleRequest(request)
        
        // Encode response
        let encoder = JSONEncoder()
        let responseData = try encoder.encode(response)
        
        guard let responseString = String(data: responseData, encoding: .utf8) else {
            throw StdioError.encodingError
        }
        
        return responseString
    }
    
    private func createErrorResponse(error: Error) -> String {
        let mcpError: MCPError
        if let existingMCPError = error as? MCPError {
            mcpError = existingMCPError
        } else {
            mcpError = .internalError
        }
        
        let errorResponse = MCPResponse(
            id: nil,
            result: nil,
            error: mcpError
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(errorResponse)
            return String(data: data, encoding: .utf8) ?? "{\"error\": \"Unknown error\"}"
        } catch {
            return "{\"error\": \"Failed to encode error response\"}"
        }
    }
    
    private func shutdown() async {
        logger.info("🔄 Shutting down Swift MCP Server (STDIO)...")
        
        // Shutdown modern concurrency integration first
        await modernConcurrency.shutdown()
        
        await swiftLanguageServer.shutdown()
        
        logger.info("✅ Swift MCP Server (STDIO) stopped")
    }
    
    /// Public shutdown method for external calls
    public func gracefulShutdown() async {
        logger.info("Shutting down STDIO transport")
        
        // Shutdown modern concurrency integration first
        await modernConcurrency.shutdown()
        
        await swiftLanguageServer.shutdown()
        
        logger.info("✅ Swift MCP Server (STDIO) stopped")
    }
}

// MARK: - Error Types

enum StdioError: Error, LocalizedError {
    case invalidInput
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid STDIO input format"
        case .encodingError:
            return "Failed to encode response"
        }
    }
}
