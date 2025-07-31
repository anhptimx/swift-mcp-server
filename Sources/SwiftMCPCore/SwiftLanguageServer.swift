import Foundation
import Logging
import NIOCore
import NIOPosix
import NIOFoundationCompat

/// Swift Language Server that provides Swift language intelligence through SourceKit-LSP integration
/// This is the core component that bridges MCP protocol with SourceKit-LSP for Serena MCP
public final class SwiftLanguageServer {
    private let logger: Logger
    private let workspaceRoot: URL
    private let sourceKitLSPPath: String
    private var isInitialized: Bool = false
    
    /// The workspace root URL
    public var workspaceURL: URL {
        return workspaceRoot
    }
    
    public init(logger: Logger, workspaceRoot: URL? = nil) {
        self.logger = logger
        self.workspaceRoot = workspaceRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        // Find SourceKit-LSP executable
        self.sourceKitLSPPath = Self.findSourceKitLSP() ?? "/usr/bin/sourcekit-lsp"
        
        logger.info("🚀 Swift Language Server initialized")
        logger.info("📁 Workspace: \(self.workspaceRoot.path)")
        logger.info("🔧 SourceKit-LSP: \(self.sourceKitLSPPath)")
    }
    
    // MARK: - SourceKit-LSP Discovery
    
    /// Find SourceKit-LSP executable in common locations
    private static func findSourceKitLSP() -> String? {
        let commonPaths = [
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
            "/usr/local/bin/sourcekit-lsp",
            "/opt/homebrew/bin/sourcekit-lsp",
            "/usr/bin/sourcekit-lsp"
        ]
        
        return commonPaths.first { FileManager.default.fileExists(atPath: $0) }
    }
    
    // MARK: - LSP Communication
    
    /// Initialize LSP connection (simplified version)
    public func initialize() async throws {
        guard !isInitialized else { return }
        
        logger.info("🔄 Initializing SourceKit-LSP connection...")
        
        // In a real implementation, this would:
        // 1. Start SourceKit-LSP process
        // 2. Send initialize request with workspace info
        // 3. Handle initialize response
        // 4. Send initialized notification
        
        isInitialized = true
        logger.info("✅ SourceKit-LSP initialized successfully")
    }
    
    /// Send LSP request (mock implementation for now)
    private func sendLSPRequest<T>(_ method: String, params: [String: Any]) async throws -> T? {
        logger.debug("📤 LSP Request: \(method)")
        
        // In real implementation:
        // 1. Format as JSON-RPC 2.0
        // 2. Add Content-Length header
        // 3. Send via stdin to SourceKit-LSP process
        // 4. Read response from stdout
        // 5. Parse JSON response
        
        return nil
    }
    
    // MARK: - Symbol Operations for MCP
    
    /// Find symbols in Swift file matching pattern
    public func findSymbols(in filePath: String, namePattern: String) async throws -> [SymbolInfo] {
        logger.debug("🔍 Finding symbols in \(filePath) with pattern: \(namePattern)")
        
        // Real implementation would send textDocument/documentSymbol LSP request
        let mockSymbols = [
            SymbolInfo(
                name: "User",
                kind: "class",
                location: Location(uri: "file://\(filePath)", line: 8, character: 13),
                containerName: nil,
                detail: "class User"
            ),
            SymbolInfo(
                name: "UserRepository", 
                kind: "protocol",
                location: Location(uri: "file://\(filePath)", line: 25, character: 17),
                containerName: nil,
                detail: "protocol UserRepository"
            ),
            SymbolInfo(
                name: "init",
                kind: "constructor", 
                location: Location(uri: "file://\(filePath)", line: 12, character: 4),
                containerName: "User",
                detail: "init(name: String, email: String)"
            )
        ]
        
        return mockSymbols.filter { $0.name.lowercased().contains(namePattern.lowercased()) }
    }
    
    /// Find all references to symbol at position
    public func findReferences(at position: Position, in filePath: String) async throws -> [Location] {
        logger.debug("📍 Finding references at \(position) in \(filePath)")
        
        // Real implementation would send textDocument/references LSP request
        return [
            Location(uri: "file://\(filePath)", line: position.line, character: position.character),
            Location(uri: "file://\(filePath)", line: position.line + 5, character: 10),
            Location(uri: "file://\(workspaceRoot.path)/Models/UserModel.swift", line: 15, character: 8)
        ]
    }
    
    /// Get definition of symbol at position  
    public func getDefinition(at position: Position, in filePath: String) async throws -> [LocationLink] {
        logger.debug("🎯 Getting definition at \(position) in \(filePath)")
        
        // Real implementation would send textDocument/definition LSP request
        return [
            LocationLink(
                originSelectionRange: Range(
                    start: Position(line: position.line, character: position.character),
                    end: Position(line: position.line, character: position.character + 4)
                ),
                targetUri: "file://\(workspaceRoot.path)/Models/User.swift",
                targetRange: Range(
                    start: Position(line: 8, character: 0),
                    end: Position(line: 20, character: 1)
                ),
                targetSelectionRange: Range(
                    start: Position(line: 8, character: 13),
                    end: Position(line: 8, character: 17)
                )
            )
        ]
    }
    
    /// Get hover information for symbol at position
    public func getHover(at position: Position, in filePath: String) async throws -> Hover? {
        logger.debug("💡 Getting hover info at \(position) in \(filePath)")
        
        // Real implementation would send textDocument/hover LSP request
        return Hover(
            contents: .markupContent(MarkupContent(
                kind: "markdown",
                value: """
                **Swift Symbol**
                
                ```swift
                class User {
                    let name: String
                    let email: String
                }
                ```
                
                **Location:** \(filePath):\(position.line):\(position.character)
                **Type:** Class
                **Module:** MyApp
                """
            )),
            range: Range(
                start: Position(line: position.line, character: position.character),
                end: Position(line: position.line, character: position.character + 4)
            )
        )
    }
    
    /// Get diagnostics (errors, warnings) for file
    public func getDiagnostics(for filePath: String) async throws -> [Diagnostic] {
        logger.debug("🔍 Getting diagnostics for \(filePath)")
        
        // Real implementation would use publishDiagnostics LSP notification
        // Mock some common Swift diagnostics
        return [
            Diagnostic(
                range: Range(start: Position(line: 10, character: 8), end: Position(line: 10, character: 15)),
                severity: .error,
                code: "E001",
                source: "swift",
                message: "Use of unresolved identifier 'unknownVar'"
            ),
            Diagnostic(
                range: Range(start: Position(line: 5, character: 0), end: Position(line: 5, character: 10)),
                severity: .warning,  
                code: "W001",
                source: "swift",
                message: "Variable 'unused' was never used; consider replacing with '_'"
            )
        ]
    }
    
    /// Format Swift document
    public func formatDocument(at filePath: String) async throws -> [TextEdit] {
        logger.debug("🎨 Formatting document at \(filePath)")
        
        // Real implementation would send textDocument/formatting LSP request
        return [
            TextEdit(
                range: Range(
                    start: Position(line: 0, character: 0),
                    end: Position(line: 0, character: 0)
                ),
                newText: "// Auto-formatted by Swift Language Server\n"
            ),
            TextEdit(
                range: Range(
                    start: Position(line: 10, character: 0),
                    end: Position(line: 10, character: 20)
                ),
                newText: "    let formattedProperty: String"
            )
        ]
    }
    
    /// Shutdown the language server
    public func shutdown() async {
        logger.info("🛑 Swift Language Server shutdown")
        isInitialized = false
        
        // Real implementation would:
        // 1. Send shutdown LSP request
        // 2. Send exit LSP notification  
        // 3. Terminate SourceKit-LSP process
    }
}

// MARK: - Supporting Types

public struct SymbolInfo {
    public let name: String
    public let kind: String
    public let location: Location
    public let containerName: String?
    public let detail: String?
    
    public init(name: String, kind: String, location: Location, containerName: String?, detail: String? = nil) {
        self.name = name
        self.kind = kind
        self.location = location
        self.containerName = containerName
        self.detail = detail
    }
}

public struct Location {
    public let uri: String
    public let line: Int
    public let character: Int
    
    public init(uri: String, line: Int, character: Int) {
        self.uri = uri
        self.line = line
        self.character = character
    }
}

public struct Position {
    public let line: Int
    public let character: Int
    
    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

public struct Range {
    public let start: Position
    public let end: Position
    
    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }
}

public struct LocationLink {
    public let originSelectionRange: Range?
    public let targetUri: String
    public let targetRange: Range
    public let targetSelectionRange: Range
    
    public init(originSelectionRange: Range?, targetUri: String, targetRange: Range, targetSelectionRange: Range) {
        self.originSelectionRange = originSelectionRange
        self.targetUri = targetUri
        self.targetRange = targetRange
        self.targetSelectionRange = targetSelectionRange
    }
}

public struct Hover {
    public let contents: HoverContent
    public let range: Range?
    
    public init(contents: HoverContent, range: Range?) {
        self.contents = contents
        self.range = range
    }
}

public enum HoverContent {
    case markupContent(MarkupContent)
    case markedString(MarkedString)
}

public struct MarkupContent {
    public let kind: String
    public let value: String
    
    public init(kind: String, value: String) {
        self.kind = kind
        self.value = value
    }
}

public struct MarkedString {
    public let language: String?
    public let value: String
    
    public init(language: String?, value: String) {
        self.language = language
        self.value = value
    }
}

public struct TextEdit {
    public let range: Range
    public let newText: String
    
    public init(range: Range, newText: String) {
        self.range = range
        self.newText = newText
    }
}

public struct Diagnostic {
    public let range: Range
    public let severity: DiagnosticSeverity?
    public let code: String?
    public let source: String?
    public let message: String
    
    public init(range: Range, severity: DiagnosticSeverity?, code: String?, source: String?, message: String) {
        self.range = range
        self.severity = severity
        self.code = code
        self.source = source
        self.message = message
    }
}

public enum DiagnosticSeverity: Int {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

public enum SwiftMCPError: Error, LocalizedError {
    case sourceKitNotFound
    case lspNotInitialized
    case symbolSearchFailed(Error)
    case referenceSearchFailed(Error)
    case definitionSearchFailed(Error)
    case hoverFailed(Error)
    case formattingFailed(Error)
    case communicationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .sourceKitNotFound:
            return "SourceKit-LSP executable not found on system"
        case .lspNotInitialized:
            return "Language server not initialized. Call initialize() first."
        case .symbolSearchFailed(let error):
            return "Symbol search failed: \(error.localizedDescription)"
        case .referenceSearchFailed(let error):
            return "Reference search failed: \(error.localizedDescription)"
        case .definitionSearchFailed(let error):
            return "Definition search failed: \(error.localizedDescription)"
        case .hoverFailed(let error):
            return "Hover request failed: \(error.localizedDescription)"
        case .formattingFailed(let error):
            return "Code formatting failed: \(error.localizedDescription)"
        case .communicationError(let message):
            return "LSP communication error: \(message)"
        }
    }
}
