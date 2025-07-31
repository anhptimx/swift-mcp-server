import Foundation

// MARK: - MCP Protocol Types

public struct MCPRequest: Codable {
    public let jsonrpc: String
    public let id: RequestID?
    public let method: String
    public let params: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        method = try container.decode(String.self, forKey: .method)
        
        // Handle optional id that can be string or number
        if container.contains(.id) {
            if let stringId = try? container.decode(String.self, forKey: .id) {
                id = .string(stringId)
            } else if let numberId = try? container.decode(Int.self, forKey: .id) {
                id = .number(numberId)
            } else {
                id = nil
            }
        } else {
            id = nil
        }
        
        // Handle optional params
        if container.contains(.params) {
            let paramsContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .params)
            var paramsDict: [String: Any] = [:]
            
            for key in paramsContainer.allKeys {
                if let stringValue = try? paramsContainer.decode(String.self, forKey: key) {
                    paramsDict[key.stringValue] = stringValue
                } else if let intValue = try? paramsContainer.decode(Int.self, forKey: key) {
                    paramsDict[key.stringValue] = intValue
                } else if let boolValue = try? paramsContainer.decode(Bool.self, forKey: key) {
                    paramsDict[key.stringValue] = boolValue
                } else if let doubleValue = try? paramsContainer.decode(Double.self, forKey: key) {
                    paramsDict[key.stringValue] = doubleValue
                }
            }
            params = paramsDict
        } else {
            params = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(method, forKey: .method)
        
        if let params = params {
            // Encode params as nested JSON
            var paramsContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .params)
            for (key, value) in params {
                let codingKey = DynamicCodingKey(stringValue: key)!
                if let stringValue = value as? String {
                    try paramsContainer.encode(stringValue, forKey: codingKey)
                } else if let intValue = value as? Int {
                    try paramsContainer.encode(intValue, forKey: codingKey)
                } else if let boolValue = value as? Bool {
                    try paramsContainer.encode(boolValue, forKey: codingKey)
                } else if let doubleValue = value as? Double {
                    try paramsContainer.encode(doubleValue, forKey: codingKey)
                }
            }
        }
    }
}

public struct MCPResponse: Codable {
    public let jsonrpc: String
    public let id: RequestID?
    public let result: Data?
    public let error: MCPError?
    
    public init(jsonrpc: String = "2.0", id: RequestID?, result: Data? = nil, error: MCPError? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }
}

public enum RequestID: Codable {
    case string(String)
    case number(Int)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let numberValue = try? container.decode(Int.self) {
            self = .number(numberValue)
        } else {
            throw DecodingError.typeMismatch(RequestID.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        }
    }
}

public enum MCPError: Error, Codable {
    case parseError
    case invalidRequest
    case methodNotFound(String)
    case invalidParams
    case internalError
    case toolNotFound(String)
    case resourceNotFound(String)
    
    enum CodingKeys: String, CodingKey {
        case code, message, data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(Int.self, forKey: .code)
        let message = try container.decode(String.self, forKey: .message)
        
        switch code {
        case -32700:
            self = .parseError
        case -32600:
            self = .invalidRequest
        case -32601:
            self = .methodNotFound(message)
        case -32602:
            self = .invalidParams
        case -32603:
            self = .internalError
        case -32001:
            self = .toolNotFound(message)
        case -32002:
            self = .resourceNotFound(message)
        default:
            self = .internalError
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .parseError:
            try container.encode(-32700, forKey: .code)
            try container.encode("Parse error", forKey: .message)
        case .invalidRequest:
            try container.encode(-32600, forKey: .code)
            try container.encode("Invalid Request", forKey: .message)
        case .methodNotFound(let method):
            try container.encode(-32601, forKey: .code)
            try container.encode("Method not found: \(method)", forKey: .message)
        case .invalidParams:
            try container.encode(-32602, forKey: .code)
            try container.encode("Invalid params", forKey: .message)
        case .internalError:
            try container.encode(-32603, forKey: .code)
            try container.encode("Internal error", forKey: .message)
        case .toolNotFound(let tool):
            try container.encode(-32001, forKey: .code)
            try container.encode("Tool not found: \(tool)", forKey: .message)
        case .resourceNotFound(let resource):
            try container.encode(-32002, forKey: .code)
            try container.encode("Resource not found: \(resource)", forKey: .message)
        }
    }
}

// MARK: - Server Capabilities

public struct ServerCapabilities: Codable {
    public let tools: ToolsCapability?
    public let resources: ResourcesCapability?
    
    public init(tools: ToolsCapability? = nil, resources: ResourcesCapability? = nil) {
        self.tools = tools
        self.resources = resources
    }
}

public struct ToolsCapability: Codable {
    public let listChanged: Bool?
    
    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

public struct ResourcesCapability: Codable {
    public let subscribe: Bool?
    public let listChanged: Bool?
    
    public init(subscribe: Bool? = nil, listChanged: Bool? = nil) {
        self.subscribe = subscribe
        self.listChanged = listChanged
    }
}

// MARK: - Initialize Types

public struct InitializeResult: Codable {
    public let protocolVersion: String
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo
    
    public init(protocolVersion: String, capabilities: ServerCapabilities, serverInfo: ServerInfo) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

public struct ServerInfo: Codable {
    public let name: String
    public let version: String
    
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

// MARK: - Tool Types

public struct Tool: Codable {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema
    }
    
    public init(name: String, description: String, inputSchema: [String: Any]) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle inputSchema as JSON object
        let schemaContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .inputSchema)
        var schema: [String: Any] = [:]
        
        for key in schemaContainer.allKeys {
            if let stringValue = try? schemaContainer.decode(String.self, forKey: key) {
                schema[key.stringValue] = stringValue
            } else if let intValue = try? schemaContainer.decode(Int.self, forKey: key) {
                schema[key.stringValue] = intValue
            } else if let boolValue = try? schemaContainer.decode(Bool.self, forKey: key) {
                schema[key.stringValue] = boolValue
            } else if let doubleValue = try? schemaContainer.decode(Double.self, forKey: key) {
                schema[key.stringValue] = doubleValue
            }
        }
        inputSchema = schema
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        
        // Encode inputSchema as nested JSON
        var schemaContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .inputSchema)
        for (key, value) in inputSchema {
            let codingKey = DynamicCodingKey(stringValue: key)!
            if let stringValue = value as? String {
                try schemaContainer.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try schemaContainer.encode(intValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try schemaContainer.encode(boolValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try schemaContainer.encode(doubleValue, forKey: codingKey)
            }
        }
    }
}

public struct ToolsListResult: Codable {
    public let tools: [Tool]
    
    public init(tools: [Tool]) {
        self.tools = tools
    }
}

public struct ToolCallParams: Codable {
    public let name: String
    public let arguments: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case name, arguments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        
        // Handle arguments as JSON object
        let argsContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .arguments)
        var args: [String: Any] = [:]
        
        for key in argsContainer.allKeys {
            if let stringValue = try? argsContainer.decode(String.self, forKey: key) {
                args[key.stringValue] = stringValue
            } else if let intValue = try? argsContainer.decode(Int.self, forKey: key) {
                args[key.stringValue] = intValue
            } else if let boolValue = try? argsContainer.decode(Bool.self, forKey: key) {
                args[key.stringValue] = boolValue
            } else if let doubleValue = try? argsContainer.decode(Double.self, forKey: key) {
                args[key.stringValue] = doubleValue
            }
        }
        arguments = args
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        
        // Encode arguments as nested JSON
        var argsContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .arguments)
        for (key, value) in arguments {
            let codingKey = DynamicCodingKey(stringValue: key)!
            if let stringValue = value as? String {
                try argsContainer.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try argsContainer.encode(intValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try argsContainer.encode(boolValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try argsContainer.encode(doubleValue, forKey: codingKey)
            }
        }
    }
}

public struct ToolCallResult: Codable {
    public let content: [ToolContent]
    
    public init(content: [ToolContent]) {
        self.content = content
    }
}

public struct ToolContent: Codable {
    public let type: String
    public let text: String
    
    public init(type: String, text: String) {
        self.type = type
        self.text = text
    }
}

// MARK: - Resource Types

public struct Resource: Codable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
    
    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

public struct ResourcesListResult: Codable {
    public let resources: [Resource]
    
    public init(resources: [Resource]) {
        self.resources = resources
    }
}

public struct ResourceReadResult: Codable {
    public let contents: [ResourceContent]
    
    public init(contents: [ResourceContent]) {
        self.contents = contents
    }
}

public struct ResourceContent: Codable {
    public let uri: String
    public let mimeType: String?
    public let text: String?
    public let blob: Data?
    
    public init(uri: String, mimeType: String? = nil, text: String? = nil, blob: Data? = nil) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
        self.blob = blob
    }
}

// MARK: - Helper Types

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Extensions

extension Dictionary where Key == String, Value == Any {
    var jsonSerializableValue: [String: Any] {
        return self.compactMapValues { value in
            if let dict = value as? [String: Any] {
                return dict.jsonSerializableValue
            } else if let array = value as? [Any] {
                return array.compactMap { $0 as? Codable }
            }
            return value as? Codable
        }
    }
}

// Helper function for converting Codable objects to dictionary
func toDictionary<T: Codable>(_ object: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(object)
    let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return dict ?? [:]
}
