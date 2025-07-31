import Foundation
import Logging

public final class MCPProtocolHandler {
    private let swiftLanguageServer: SwiftLanguageServer
    private let projectAnalyzer: ProjectAnalyzer
    private let logger: Logger
    
    public init(swiftLanguageServer: SwiftLanguageServer, logger: Logger) {
        self.swiftLanguageServer = swiftLanguageServer
        self.logger = logger
        
        // Initialize project analyzer
        self.projectAnalyzer = ProjectAnalyzer(projectPath: swiftLanguageServer.workspaceURL, logger: logger)
    }
    
    public func handleRequest(_ request: MCPRequest) async throws -> MCPResponse {
        logger.debug("Handling MCP request: \(request.method)")
        
        switch request.method {
        case "initialize":
            return try await handleInitialize(request)
        case "tools/list":
            return try await handleToolsList(request)
        case "tools/call":
            return try await handleToolCall(request)
        case "resources/list":
            return try await handleResourcesList(request)
        case "resources/read":
            return try await handleResourceRead(request)
        default:
            throw MCPError.methodNotFound(request.method)
        }
    }
    
    // MARK: - Initialize
    
    private func handleInitialize(_ request: MCPRequest) async throws -> MCPResponse {
        let capabilities = ServerCapabilities(
            tools: ToolsCapability(listChanged: true),
            resources: ResourcesCapability(subscribe: true, listChanged: true)
        )
        
        let result = InitializeResult(
            protocolVersion: "2024-11-05",
            capabilities: capabilities,
            serverInfo: ServerInfo(
                name: "swift-mcp-server",
                version: "1.0.0"
            )
        )
        
        return MCPResponse(
            jsonrpc: "2.0",
            id: request.id,
            result: try JSONSerialization.data(withJSONObject: toDictionary(result))
        )
    }
    
    // MARK: - Tools
    
    private func handleToolsList(_ request: MCPRequest) async throws -> MCPResponse {
        let tools = [
            Tool(
                name: "find_symbols",
                description: "Find Swift symbols in a file by name pattern",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": [
                            "type": "string",
                            "description": "Path to the Swift file"
                        ],
                        "name_pattern": [
                            "type": "string",
                            "description": "Pattern to match symbol names"
                        ]
                    ],
                    "required": ["file_path", "name_pattern"]
                ]
            ),
            Tool(
                name: "find_references",
                description: "Find all references to a symbol at a specific position",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": [
                            "type": "string",
                            "description": "Path to the Swift file"
                        ],
                        "line": [
                            "type": "integer",
                            "description": "Line number (0-based)"
                        ],
                        "character": [
                            "type": "integer",
                            "description": "Character position (0-based)"
                        ]
                    ],
                    "required": ["file_path", "line", "character"]
                ]
            ),
            Tool(
                name: "get_definition",
                description: "Get definition location for a symbol at a specific position",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": [
                            "type": "string",
                            "description": "Path to the Swift file"
                        ],
                        "line": [
                            "type": "integer",
                            "description": "Line number (0-based)"
                        ],
                        "character": [
                            "type": "integer",
                            "description": "Character position (0-based)"
                        ]
                    ],
                    "required": ["file_path", "line", "character"]
                ]
            ),
            Tool(
                name: "get_hover_info",
                description: "Get hover information for a symbol at a specific position",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": [
                            "type": "string",
                            "description": "Path to the Swift file"
                        ],
                        "line": [
                            "type": "integer",
                            "description": "Line number (0-based)"
                        ],
                        "character": [
                            "type": "integer",
                            "description": "Character position (0-based)"
                        ]
                    ],
                    "required": ["file_path", "line", "character"]
                ]
            ),
            Tool(
                name: "format_document",
                description: "Format a Swift document",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": [
                            "type": "string",
                            "description": "Path to the Swift file to format"
                        ]
                    ],
                    "required": ["file_path"]
                ]
            ),
            Tool(
                name: "analyze_project",
                description: "Perform comprehensive project analysis including architecture detection",
                inputSchema: [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            ),
            Tool(
                name: "detect_architecture",
                description: "Detect the architecture pattern used in the project",
                inputSchema: [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            ),
            Tool(
                name: "analyze_symbol_usage",
                description: "Analyze how a symbol is used throughout the project",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "symbol_name": [
                            "type": "string",
                            "description": "Name of the symbol to analyze"
                        ]
                    ],
                    "required": ["symbol_name"]
                ]
            ),
            Tool(
                name: "create_project_memory",
                description: "Create comprehensive project documentation and memory",
                inputSchema: [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            ),
            Tool(
                name: "generate_migration_plan", 
                description: "Generate a plan to migrate to a different architecture pattern",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "target_architecture": [
                            "type": "string",
                            "description": "Target architecture pattern (mvvm, features_based, viper, clean_architecture)"
                        ]
                    ],
                    "required": ["target_architecture"]
                ]
            ),
            Tool(
                name: "analyze_pop_usage",
                description: "Analyze project's Protocol-Oriented Programming (POP) adoption",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "project_path": [
                            "type": "string",
                            "description": "Path to the project to analyze"
                        ]
                    ],
                    "required": ["project_path"]
                ]
            )
        ]
        
        let result = ToolsListResult(tools: tools)
        return MCPResponse(
            jsonrpc: "2.0",
            id: request.id,
            result: try JSONSerialization.data(withJSONObject: toDictionary(result))
        )
    }
    
    private func handleToolCall(_ request: MCPRequest) async throws -> MCPResponse {
        guard let params = request.params,
              let paramsData = try? JSONSerialization.data(withJSONObject: params),
              let toolCall = try? JSONDecoder().decode(ToolCallParams.self, from: paramsData) else {
            throw MCPError.invalidParams
        }
        
        let result: Any
        
        switch toolCall.name {
        case "find_symbols":
            result = try await handleFindSymbols(toolCall.arguments)
        case "find_references":
            result = try await handleFindReferences(toolCall.arguments)
        case "get_definition":
            result = try await handleGetDefinition(toolCall.arguments)
        case "get_hover_info":
            result = try await handleGetHoverInfo(toolCall.arguments)
        case "format_document":
            result = try await handleFormatDocument(toolCall.arguments)
        case "analyze_project":
            result = try await handleAnalyzeProject(toolCall.arguments)
        case "detect_architecture":
            result = try await handleDetectArchitecture(toolCall.arguments)
        case "analyze_symbol_usage":
            result = try await handleAnalyzeSymbolUsage(toolCall.arguments)
        case "create_project_memory":
            result = try await handleCreateProjectMemory(toolCall.arguments)
        case "generate_migration_plan":
            result = try await handleGenerateMigrationPlan(toolCall.arguments)
        case "analyze_pop_usage":
            result = try await handleAnalyzePOPUsage(toolCall.arguments)
        default:
            throw MCPError.toolNotFound(toolCall.name)
        }
        
        let toolResult = ToolCallResult(
            content: [
                ToolContent(type: "text", text: String(describing: result))
            ]
        )
        
        return MCPResponse(
            jsonrpc: "2.0",
            id: request.id,
            result: try JSONSerialization.data(withJSONObject: toDictionary(toolResult))
        )
    }
    
    // MARK: - Tool Implementations
    
    private func handleFindSymbols(_ arguments: [String: Any]) async throws -> [SymbolInfo] {
        guard let filePath = arguments["file_path"] as? String,
              let namePattern = arguments["name_pattern"] as? String else {
            throw MCPError.invalidParams
        }
        
        return try await swiftLanguageServer.findSymbols(in: filePath, namePattern: namePattern)
    }
    
    private func handleFindReferences(_ arguments: [String: Any]) async throws -> [String] {
        guard let filePath = arguments["file_path"] as? String,
              let line = arguments["line"] as? Int,
              let character = arguments["character"] as? Int else {
            throw MCPError.invalidParams
        }
        
        let position = Position(line: line, character: character)
        let locations = try await swiftLanguageServer.findReferences(at: position, in: filePath)
        
        return locations.map { "\($0.uri):\($0.line):\($0.character)" }
    }
    
    private func handleGetDefinition(_ arguments: [String: Any]) async throws -> [String] {
        guard let filePath = arguments["file_path"] as? String,
              let line = arguments["line"] as? Int,
              let character = arguments["character"] as? Int else {
            throw MCPError.invalidParams
        }
        
        let position = Position(line: line, character: character)
        let locations = try await swiftLanguageServer.getDefinition(at: position, in: filePath)
        
        return locations.map { "\($0.targetUri):\($0.targetRange.start.line):\($0.targetRange.start.character)" }
    }
    
    private func handleGetHoverInfo(_ arguments: [String: Any]) async throws -> String {
        guard let filePath = arguments["file_path"] as? String,
              let line = arguments["line"] as? Int,
              let character = arguments["character"] as? Int else {
            throw MCPError.invalidParams
        }
        
        let position = Position(line: line, character: character)
        let hover = try await swiftLanguageServer.getHover(at: position, in: filePath)
        
        if case .markupContent(let content) = hover?.contents {
            return content.value
        } else if case .markedString(let string) = hover?.contents {
            return string.value
        }
        
        return "No hover information available"
    }
    
    private func handleFormatDocument(_ arguments: [String: Any]) async throws -> [String] {
        guard let filePath = arguments["file_path"] as? String else {
            throw MCPError.invalidParams
        }
        
        let edits = try await swiftLanguageServer.formatDocument(at: filePath)
        return edits.map { "Line \($0.range.start.line): \($0.newText)" }
    }
    
    // MARK: - Resources
    
    private func handleResourcesList(_ request: MCPRequest) async throws -> MCPResponse {
        let resources = [
            Resource(
                uri: "swift://workspace",
                name: "Swift Workspace",
                description: "Current Swift workspace information",
                mimeType: "application/json"
            )
        ]
        
        let result = ResourcesListResult(resources: resources)
        return MCPResponse(
            jsonrpc: "2.0",
            id: request.id,
            result: try JSONSerialization.data(withJSONObject: toDictionary(result))
        )
    }
    
    private func handleResourceRead(_ request: MCPRequest) async throws -> MCPResponse {
        guard let params = request.params,
              let uri = params["uri"] as? String else {
            throw MCPError.invalidParams
        }
        
        let content: String
        
        switch uri {
        case "swift://workspace":
            content = """
            {
                "type": "swift_workspace",
                "capabilities": ["symbol_search", "references", "definitions", "hover", "formatting"],
                "sourcekit_lsp": "available"
            }
            """
        default:
            throw MCPError.resourceNotFound(uri)
        }
        
        let result = ResourceReadResult(
            contents: [
                ResourceContent(
                    uri: uri,
                    mimeType: "application/json",
                    text: content
                )
            ]
        )
        
        return MCPResponse(
            jsonrpc: "2.0",
            id: request.id,
            result: try JSONSerialization.data(withJSONObject: toDictionary(result))
        )
    }
    
    // MARK: - Enhanced Analysis Tools
    
    private func handleAnalyzeProject(_ arguments: [String: Any]) async throws -> String {
        guard let projectPath = arguments["project_path"] as? String else {
            throw MCPError.invalidParams
        }
        
        let projectURL = URL(fileURLWithPath: projectPath)
        let analyzer = ProjectAnalyzer(projectPath: projectURL, logger: logger)
        let analysis = try await analyzer.analyzeProject()
        
        return """
        Project Analysis for: \(projectPath)
        Architecture: \(analysis.architecturePattern.rawValue)
        Modules: \(analysis.structure.modules.count)
        Features: \(analysis.structure.features.count)
        Metrics: \(analysis.metrics.totalFiles) files, \(analysis.metrics.totalLines) lines
        """
    }
    
    private func handleDetectArchitecture(_ arguments: [String: Any]) async throws -> String {
        guard let projectPath = arguments["project_path"] as? String else {
            throw MCPError.invalidParams
        }
        
        let projectURL = URL(fileURLWithPath: projectPath)
        let analyzer = ArchitectureAnalyzer(projectPath: projectURL, logger: logger)
        let pattern = try await analyzer.detectArchitecturePattern()
        
        return pattern.rawValue
    }
    
    private func handleAnalyzeSymbolUsage(_ arguments: [String: Any]) async throws -> String {
        guard let projectPath = arguments["project_path"] as? String,
              let symbolName = arguments["symbol_name"] as? String else {
            throw MCPError.invalidParams
        }
        
        let projectURL = URL(fileURLWithPath: projectPath)
        let symbolEngine = SymbolSearchEngine(projectPath: projectURL, logger: logger)
        let usage = try await symbolEngine.analyzeSymbolUsage(symbolName: symbolName)
        
        return """
        Symbol Usage Analysis for: \(symbolName)
        Total occurrences: \(usage.totalReferences)
        Files containing symbol: \(usage.uniqueFiles)
        Usage patterns: \(usage.usagePatterns.keys.joined(separator: ", "))
        """
    }
    
    private func handleCreateProjectMemory(_ arguments: [String: Any]) async throws -> String {
        guard let projectPath = arguments["project_path"] as? String else {
            throw MCPError.invalidParams
        }
        
        let projectURL = URL(fileURLWithPath: projectPath)
        let analyzer = ProjectAnalyzer(projectPath: projectURL, logger: logger)
        let memory = try await analyzer.createProjectMemory()
        
        return """
        Project Memory Created:
        Project: \(memory.analysis.projectName)
        Architecture: \(memory.analysis.architecturePattern.rawValue)
        Key Symbols: \(memory.keySymbols.count) symbols captured
        Code Patterns: \(memory.codePatterns.count) patterns identified
        Last Updated: \(memory.lastUpdated)
        """
    }
    
    private func handleGenerateMigrationPlan(_ arguments: [String: Any]) async throws -> String {
        guard let projectPath = arguments["project_path"] as? String,
              let targetArchitecture = arguments["target_architecture"] as? String else {
            throw MCPError.invalidParams
        }
        
        guard let targetPattern = ArchitecturePattern(rawValue: targetArchitecture) else {
            throw MCPError.invalidParams
        }
        
        let projectURL = URL(fileURLWithPath: projectPath)
        let analyzer = ProjectAnalyzer(projectPath: projectURL, logger: logger)
        let plan = try await analyzer.generateMigrationPlan(to: targetPattern)
        
        return """
        Migration Plan from \(plan.from.rawValue) to \(plan.to.rawValue):
        
        Steps: \(plan.steps.count) migration steps
        Estimated effort: \(plan.estimatedEffort)
        Risks: \(plan.risks.count) identified
        Benefits: \(plan.benefits.count) expected benefits
        
        First Steps:
        \(plan.steps.prefix(3).map { "• \($0.title): \($0.description)" }.joined(separator: "\n"))
        """
    }
    
    private func handleAnalyzePOPUsage(_ arguments: [String: Any]) async throws -> String {
        guard let projectPath = arguments["project_path"] as? String else {
            throw MCPError.invalidParams
        }
        
        let projectURL = URL(fileURLWithPath: projectPath)
        let analyzer = ArchitectureAnalyzer(projectPath: projectURL, logger: logger)
        let analysis = try await analyzer.analyzePOPUsage()
        
        return """
        🔍 Protocol-Oriented Programming Analysis for: \(projectPath)
        
        📊 Overview:
        • Total Swift files: \(analysis.totalFiles)
        • POP Score: \(analysis.popScore)/100 (\(analysis.adoptionLevel.rawValue))
        • Struct vs Class ratio: \(analysis.structUsage):\(analysis.classUsage)
        
        📈 Protocol Usage:
        • Protocol definitions: \(analysis.protocolDefinitions)
        • Protocol extensions: \(analysis.protocolExtensions)  
        • Protocol conformances: \(analysis.protocolConformances)
        • Protocol as types: \(analysis.protocolAsTypeUsage)
        
        🎯 POP Patterns Found:
        \(analysis.popPatterns.isEmpty ? "None detected" : analysis.popPatterns.map { "• \($0)" }.joined(separator: "\n"))
        
        💡 Recommendations:
        \(analysis.recommendations.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}
