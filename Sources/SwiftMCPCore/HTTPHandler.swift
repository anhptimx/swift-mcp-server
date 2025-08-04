import Foundation
import NIO
import NIOHTTP1
import Logging

final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let mcpProtocolHandler: MCPProtocolHandler
    private let logger: Logger
    private var requestBody: ByteBuffer?
    private var responseReceived = false
    
    init(mcpProtocolHandler: MCPProtocolHandler, logger: Logger) {
        self.mcpProtocolHandler = mcpProtocolHandler
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let requestHead):
            // Reset state for new request
            requestBody = nil
            responseReceived = false
            
            logger.debug("Received HTTP request: \(requestHead.method) \(requestHead.uri)")
            
            // Handle CORS preflight
            if requestHead.method == .OPTIONS {
                handleOptionsRequest(context: context)
                return
            }
            
            // Handle health check
            if requestHead.method == .GET && requestHead.uri == "/health" {
                handleHealthCheck(context: context)
                return
            }
            
            // Handle root path for general info
            if requestHead.method == .GET && requestHead.uri == "/" {
                handleInfo(context: context)
                return
            }
            
            // Only accept POST requests to / or /mcp
            guard requestHead.method == .POST && (requestHead.uri == "/" || requestHead.uri == "/mcp") else {
                sendErrorResponse(context: context, status: .notFound, message: "Not Found")
                return
            }
            
        case .body(var byteBuffer):
            if requestBody == nil {
                requestBody = byteBuffer
            } else {
                requestBody!.writeBuffer(&byteBuffer)
            }
            
        case .end:
            // Don't send response if we already sent one
            guard !responseReceived else { return }
            
            guard let body = requestBody else {
                sendErrorResponse(context: context, status: .badRequest, message: "Empty request body")
                return
            }
            
            handleMCPRequest(context: context, body: body)
        }
    }
    
    private func handleOptionsRequest(context: ChannelHandlerContext) {
        guard !responseReceived else { return }
        responseReceived = true
        
        let headers = HTTPHeaders([
            ("Access-Control-Allow-Origin", "*"),
            ("Access-Control-Allow-Methods", "POST, OPTIONS"),
            ("Access-Control-Allow-Headers", "Content-Type"),
            ("Access-Control-Max-Age", "86400")
        ])


        let head = HTTPResponseHead(
            version: .http1_1,
            status: .ok,
            headers: headers
        )
        
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    private func handleMCPRequest(context: ChannelHandlerContext, body: ByteBuffer) {
        let data = Data(buffer: body)
        
        // Use EventLoopFuture to handle async work in a more Sendable-safe way
        let promise = context.eventLoop.makePromise(of: MCPResponse.self)
        
        Task {
            do {
                let mcpRequest = try JSONDecoder().decode(MCPRequest.self, from: data)
                let response = try await self.mcpProtocolHandler.handleRequest(mcpRequest)
                promise.succeed(response)
            } catch {
                self.logger.error("Failed to handle MCP request: \(error)")
                promise.fail(error)
            }
        }
        
        promise.futureResult.whenComplete { result in
            switch result {
            case .success(let response):
                self.sendMCPResponse(context: context, response: response)
            case .failure:
                self.sendErrorResponse(context: context, status: .internalServerError, message: "Internal Server Error")
            }
        }
    }
    
    private func sendMCPResponse(context: ChannelHandlerContext, response: MCPResponse) {
        guard !responseReceived else { return }
        responseReceived = true
        
        do {
            let data = try JSONEncoder().encode(response)
            let buffer = context.channel.allocator.buffer(data: data)
            
            let headers = HTTPHeaders([
                ("Content-Type", "application/json"),
                ("Content-Length", "\(data.count)"),
                ("Access-Control-Allow-Origin", "*")
            ])
            
            let head = HTTPResponseHead(
                version: .http1_1,
                status: .ok,
                headers: headers
            )
            
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            
        } catch {
            logger.error("Failed to encode MCP response: \(error)")
            sendErrorResponse(context: context, status: .internalServerError, message: "Failed to encode response")
        }
    }
    
    private func sendErrorResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, message: String) {
        guard !responseReceived else { return }
        responseReceived = true
        
        let errorResponse = """
        {
            "jsonrpc": "2.0",
            "error": {
                "code": \(status.code),
                "message": "\(message)"
            }
        }
        """
        
        let data = errorResponse.data(using: .utf8)!
        let buffer = context.channel.allocator.buffer(data: data)
        
        let headers = HTTPHeaders([
            ("Content-Type", "application/json"),
            ("Content-Length", "\(data.count)"),
            ("Access-Control-Allow-Origin", "*")
        ])
        
        let head = HTTPResponseHead(
            version: .http1_1,
            status: status,
            headers: headers
        )
        
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    private func handleHealthCheck(context: ChannelHandlerContext) {
        guard !responseReceived else { return }
        
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": [
                "status": "healthy",
                "server": "Swift MCP Server",
                "version": "1.0.0",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        
        sendJSONResponse(context: context, response: response)
    }
    
    private func handleInfo(context: ChannelHandlerContext) {
        guard !responseReceived else { return }
        
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": [
                "name": "Swift MCP Server",
                "version": "1.0.0",
                "description": "Swift MCP Server for Serena MCP integration with SourceKit-LSP support",
                "capabilities": [
                    "roots": ["listChanged": true],
                    "sampling": [:]
                ],
                "serverInfo": [
                    "name": "swift-mcp-server", 
                    "version": "1.0.0"
                ]
            ]
        ]
        
        sendJSONResponse(context: context, response: response)
    }
    
    private func sendJSONResponse(context: ChannelHandlerContext, response: [String: Any]) {
        guard !responseReceived else { return }
        responseReceived = true
        
        do {
            let data = try JSONSerialization.data(withJSONObject: response, options: [])
            let buffer = context.channel.allocator.buffer(data: data)
            
            let headers = HTTPHeaders([
                ("Content-Type", "application/json"),
                ("Content-Length", "\(data.count)"),
                ("Access-Control-Allow-Origin", "*")
            ])
            
            let head = HTTPResponseHead(
                version: .http1_1,
                status: .ok,
                headers: headers
            )
            
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            
        } catch {
            logger.error("Failed to encode JSON response: \(error)")
            sendErrorResponse(context: context, status: .internalServerError, message: "Failed to encode response")
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("HTTP handler error: \(error)")
        context.close(promise: nil)
    }
}
