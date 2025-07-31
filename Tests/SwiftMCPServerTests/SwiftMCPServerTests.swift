import XCTest
import Logging
@testable import SwiftMCPCore

final class SwiftMCPServerTests: XCTestCase {
    
    func testMCPProtocolHandlerInitialization() throws {
        let logger = Logger(label: "test")
        let swiftLanguageServer = SwiftLanguageServer(logger: logger)
        let handler = MCPProtocolHandler(swiftLanguageServer: swiftLanguageServer, logger: logger)
        
        XCTAssertNotNil(handler)
    }
    
    func testMCPRequestDecoding() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "id": "test-id",
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(MCPRequest.self, from: data)
        
        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "initialize")
        
        if case .string(let id) = request.id {
            XCTAssertEqual(id, "test-id")
        } else {
            XCTFail("Expected string ID")
        }
    }
    
    func testMCPResponseEncoding() throws {
        let response = MCPResponse(
            jsonrpc: "2.0",
            id: .string("test-id"),
            result: "test result".data(using: .utf8)
        )
        
        let data = try JSONEncoder().encode(response)
        let json = String(data: data, encoding: .utf8)
        
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("test-id"))
       
    }
    
    func testToolDefinition() throws {
        let tool = Tool(
            name: "find_symbols",
            description: "Find Swift symbols",
            inputSchema: [
                "type": "object",
                "properties": [
                    "file_path": ["type": "string"]
                ]
            ]
        )
        
        XCTAssertEqual(tool.name, "find_symbols")
        XCTAssertEqual(tool.description, "Find Swift symbols")
    }
}
