import Foundation
import Logging
import NIO
import NIOHTTP1
import NIOFoundationCompat

public final class MCPServer: @unchecked Sendable {
    private let host: String
    private let port: Int
    private let logger: Logger
    private let group: EventLoopGroup
    private var channel: Channel?
    
    private let swiftLanguageServer: SwiftLanguageServer
    private let mcpProtocolHandler: MCPProtocolHandler
    private let modernConcurrency: ModernConcurrencyIntegration
    
    public init(host: String, port: Int, logger: Logger, workspaceRoot: URL? = nil) {
        self.host = host
        self.port = port
        self.logger = logger
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // Initialize modern concurrency integration
        self.modernConcurrency = ModernConcurrencyIntegration(logger: logger)
        
        self.swiftLanguageServer = SwiftLanguageServer(logger: logger, workspaceRoot: workspaceRoot)
        self.mcpProtocolHandler = MCPProtocolHandler(
            swiftLanguageServer: swiftLanguageServer,
            logger: logger
        )
    }
    
    deinit {
        try? group.syncShutdownGracefully()
    }
    
    public func start() async throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let httpHandler = HTTPHandler(
                    mcpProtocolHandler: self.mcpProtocolHandler,
                    logger: self.logger
                )
                
                return channel.pipeline.configureHTTPServerPipeline(
                    withErrorHandling: true
                ).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        let channel = try await bootstrap.bind(host: host, port: port).get()
        self.channel = channel
        
        logger.info("🚀 Swift MCP Server started on \(host):\(port)")
        logger.info("📊 Modern concurrency enabled with enhanced task management")
        logger.info("🛠️ Server is ready to handle MCP requests")
        
        // Log resource usage
        let resourceUsage = await modernConcurrency.getResourceUsage()
        logger.info("💾 Initial resource usage - Memory: \(resourceUsage.memoryMB)MB, CPU: \(resourceUsage.cpuPercentage)%, Network: \(resourceUsage.networkOperations)")
        
        // Wait until the server is closed
        try await channel.closeFuture.get()
    }
    
    public func stop() async throws {
        logger.info("🔄 Shutting down Swift MCP Server...")
        
        // Shutdown modern concurrency integration first
        await modernConcurrency.shutdown()
        
        await swiftLanguageServer.shutdown()
        try await channel?.close()
        try await group.shutdownGracefully()
        
        logger.info("✅ Swift MCP Server stopped")
    }
    
    // MARK: - Modern Concurrency Access
    
    /// Provide access to modern concurrency features for advanced operations
    public var concurrencyManager: ModernConcurrencyIntegration {
        return modernConcurrency
    }
}
