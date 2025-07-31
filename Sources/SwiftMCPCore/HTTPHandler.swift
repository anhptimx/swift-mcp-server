import Foundation
import NIO
import NIOHTTP1
import Logging

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let mcpProtocolHandler: MCPProtocolHandler
    private let logger: Logger
    private var requestBody: ByteBuffer?
    
    init(mcpProtocolHandler: MCPProtocolHandler, logger: Logger) {
        self.mcpProtocolHandler = mcpProtocolHandler
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let requestHead):
            logger.debug("Received HTTP request: \(requestHead.method) \(requestHead.uri)")
            
            // Handle CORS preflight
            if requestHead.method == .OPTIONS {
                handleOptionsRequest(context: context)
                return
            }
            
            // Only accept POST requests to /mcp
            guard requestHead.method == .POST && requestHead.uri == "/mcp" else {
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
            guard let body = requestBody else {
                sendErrorResponse(context: context, status: .badRequest, message: "Empty request body")
                return
            }
            
            handleMCPRequest(context: context, body: body)
        }
    }
    
    private func handleOptionsRequest(context: ChannelHandlerContext) {
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
        Task {
            do {
                let data = Data(buffer: body)
                let mcpRequest = try JSONDecoder().decode(MCPRequest.self, from: data)
                
                let response = try await mcpProtocolHandler.handleRequest(mcpRequest)
                sendMCPResponse(context: context, response: response)
                
            } catch {
                logger.error("Failed to handle MCP request: \(error)")
                sendErrorResponse(context: context, status: .internalServerError, message: "Internal Server Error")
            }
        }
    }
    
    private func sendMCPResponse(context: ChannelHandlerContext, response: MCPResponse) {
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
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("HTTP handler error: \(error)")
        context.close(promise: nil)
    }
}
