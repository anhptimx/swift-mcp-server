import Foundation
import Logging

/// Enhanced symbol search with regex fallback and caching
public class SymbolSearchEngine {
    private let projectPath: URL
    private let logger: Logger
    private var symbolCache: [String: [SymbolInfo]] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private var lastCacheUpdate: Date = Date.distantPast
    
    public init(projectPath: URL, logger: Logger) {
        self.projectPath = projectPath
        self.logger = logger
    }
    
    /// Find symbols with advanced filtering and regex support
    public func findSymbols(
        namePattern: String = "",
        symbolType: String = "",
        useRegex: Bool = false,
        includePrivate: Bool = false,
        includeInherited: Bool = false
    ) async throws -> [SymbolInfo] {
        
        // Check cache first
        let cacheKey = "\(namePattern)_\(symbolType)_\(useRegex)_\(includePrivate)"
        if let cached = getCachedSymbols(for: cacheKey) {
            return cached
        }
        
        logger.debug("🔍 Searching symbols with pattern: \(namePattern), type: \(symbolType)")
        
        var symbols: [SymbolInfo] = []
        
        // Use regex-based search
        symbols = try await searchWithRegex(
            namePattern: namePattern,
            symbolType: symbolType,
            useRegex: useRegex,
            includePrivate: includePrivate
        )
        
        // Filter inherited symbols if needed
        if !includeInherited {
            symbols = symbols.filter { !$0.isInherited }
        }
        
        // Cache results
        setCachedSymbols(symbols, for: cacheKey)
        
        return symbols
    }
    
    /// Find all references to a symbol
    public func findReferences(
        symbolName: String,
        symbolType: String = "",
        includeComments: Bool = false
    ) async throws -> [ReferenceInfo] {
        
        logger.debug("📍 Finding references for symbol: \(symbolName)")
        
        var references: [ReferenceInfo] = []
        let swiftFiles = try await findAllSwiftFiles()
        
        await withTaskGroup(of: [ReferenceInfo].self) { group in
            for file in swiftFiles {
                group.addTask {
                    await self.findReferencesInFile(
                        file: file,
                        symbolName: symbolName,
                        symbolType: symbolType,
                        includeComments: includeComments
                    )
                }
            }
            
            for await fileReferences in group {
                references.append(contentsOf: fileReferences)
            }
        }
        
        return references
    }
    
    /// Get symbol hierarchy (inheritance chain)
    public func getSymbolHierarchy(symbolName: String) async throws -> SymbolHierarchy {
        logger.debug("🏗️ Building hierarchy for symbol: \(symbolName)")
        
        let symbols = try await findSymbols(namePattern: symbolName, useRegex: false)
        guard let targetSymbol = symbols.first(where: { $0.name == symbolName }) else {
            throw SwiftMCPError.lspNotInitialized
        }
        
        let parents = try await findParentSymbols(for: targetSymbol)
        let children = try await findChildSymbols(for: targetSymbol)
        
        return SymbolHierarchy(
            symbol: targetSymbol,
            parents: parents,
            children: children
        )
    }
    
    /// Analyze symbol usage patterns
    public func analyzeSymbolUsage(symbolName: String) async throws -> SymbolUsageAnalysis {
        logger.debug("📊 Analyzing usage for symbol: \(symbolName)")
        
        let references = try await findReferences(symbolName: symbolName)
        
        var usagePatterns: [String: Int] = [:]
        var fileDistribution: [String: Int] = [:]
        
        for reference in references {
            // Count usage patterns
            let pattern = reference.context.trimmingCharacters(in: .whitespacesAndNewlines)
            usagePatterns[pattern, default: 0] += 1
            
            // Count file distribution
            fileDistribution[reference.file, default: 0] += 1
        }
        
        return SymbolUsageAnalysis(
            symbolName: symbolName,
            totalReferences: references.count,
            uniqueFiles: fileDistribution.count,
            usagePatterns: usagePatterns,
            fileDistribution: fileDistribution,
            mostUsedIn: fileDistribution.max(by: { $0.value < $1.value })?.key
        )
    }
    
    // MARK: - Private Methods
    
    private func searchWithRegex(
        namePattern: String,
        symbolType: String,
        useRegex: Bool,
        includePrivate: Bool
    ) async throws -> [SymbolInfo] {
        
        var symbols: [SymbolInfo] = []
        let swiftFiles = try await findAllSwiftFiles()
        
        let patterns = createSearchPatterns(for: symbolType, includePrivate: includePrivate)
        
        await withTaskGroup(of: [SymbolInfo].self) { group in
            for file in swiftFiles {
                group.addTask {
                    await self.searchSymbolsInFile(
                        file: file,
                        namePattern: namePattern,
                        patterns: patterns,
                        useRegex: useRegex
                    )
                }
            }
            
            for await fileSymbols in group {
                symbols.append(contentsOf: fileSymbols)
            }
        }
        
        return symbols
    }
    
    private func createSearchPatterns(for symbolType: String, includePrivate: Bool) -> [String: String] {
        var patterns: [String: String] = [:]
        
        let accessModifiers = includePrivate ? 
            "(?:public\\s+|private\\s+|internal\\s+|fileprivate\\s+)?" :
            "(?:public\\s+|internal\\s+)?"
        
        if symbolType.isEmpty || symbolType == "class" {
            patterns["class"] = "\(accessModifiers)class\\s+(\\w+)(?:\\s*:\\s*([^{]+))?"
        }
        
        if symbolType.isEmpty || symbolType == "struct" {
            patterns["struct"] = "\(accessModifiers)struct\\s+(\\w+)(?:\\s*:\\s*([^{]+))?"
        }
        
        if symbolType.isEmpty || symbolType == "enum" {
            patterns["enum"] = "\(accessModifiers)enum\\s+(\\w+)(?:\\s*:\\s*([^{]+))?"
        }
        
        if symbolType.isEmpty || symbolType == "protocol" {
            patterns["protocol"] = "\(accessModifiers)protocol\\s+(\\w+)(?:\\s*:\\s*([^{]+))?"
        }
        
        if symbolType.isEmpty || symbolType == "function" {
            patterns["function"] = "\(accessModifiers)func\\s+(\\w+)\\s*\\("
        }
        
        if symbolType.isEmpty || symbolType == "property" {
            patterns["property"] = "\(accessModifiers)(?:var|let)\\s+(\\w+)\\s*:"
        }
        
        if symbolType.isEmpty || symbolType == "typealias" {
            patterns["typealias"] = "\(accessModifiers)typealias\\s+(\\w+)\\s*="
        }
        
        return patterns
    }
    
    private func searchSymbolsInFile(
        file: URL,
        namePattern: String,
        patterns: [String: String],
        useRegex: Bool
    ) async -> [SymbolInfo] {
        
        var symbols: [SymbolInfo] = []
        
        guard let content = try? String(contentsOf: file) else {
            return symbols
        }
        
        for (symbolType, pattern) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
                let range = NSRange(content.startIndex..., in: content)
                
                regex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
                    guard let match = match,
                          match.numberOfRanges > 1 else {
                        return
                    }
                    
                    let nsRange = match.range(at: 1)
                    guard nsRange.location != NSNotFound else {
                        return
                    }
                    
                    let startIndex = content.index(content.startIndex, offsetBy: nsRange.location)
                    let endIndex = content.index(startIndex, offsetBy: nsRange.length)
                    let symbolName = String(content[startIndex..<endIndex])
                    
                    // Filter by name pattern
                    if !namePattern.isEmpty {
                        if useRegex {
                            guard symbolName.range(of: namePattern, options: .regularExpression) != nil else {
                                return
                            }
                        } else {
                            guard symbolName.localizedCaseInsensitiveContains(namePattern) else {
                                return
                            }
                        }
                    }
                    
                    // Get inheritance/conformance info
                    var inheritance: String?
                    if match.numberOfRanges > 2 {
                        let inheritanceRange = match.range(at: 2)
                        if inheritanceRange.location != NSNotFound {
                            let startIndex = content.index(content.startIndex, offsetBy: inheritanceRange.location)
                            let endIndex = content.index(startIndex, offsetBy: inheritanceRange.length)
                            inheritance = String(content[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    
                    // Find line number
                    let location = match.range(at: 0).location
                    let lineNumber = content.prefix(location).components(separatedBy: .newlines).count
                    
                    let symbol = SymbolInfo(
                        name: symbolName,
                        kind: symbolType,
                        location: Location(
                            uri: "file://\(file.path)",
                            line: lineNumber,
                            character: 0
                        ),
                        containerName: inheritance,
                        detail: symbolType + " " + symbolName
                    )
                    
                    symbols.append(symbol)
                }
            } catch {
                logger.error("Regex error for pattern \(pattern): \(error)")
            }
        }
        
        return symbols
    }
    
    private func findReferencesInFile(
        file: URL,
        symbolName: String,
        symbolType: String,
        includeComments: Bool
    ) async -> [ReferenceInfo] {
        
        var references: [ReferenceInfo] = []
        
        guard let content = try? String(contentsOf: file) else {
            return references
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip comments unless explicitly requested
            if !includeComments && (trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*")) {
                continue
            }
            
            // Find all occurrences of the symbol name in this line
            var searchRange = line.startIndex..<line.endIndex
            
            while let range = line.range(of: symbolName, range: searchRange) {
                // Check if it's a whole word (not part of another identifier)
                let isWholeWord = isWholeWordMatch(in: line, range: range)
                
                if isWholeWord {
                    // Get context (surrounding lines)
                    let contextStart = max(0, lineIndex - 1)
                    let contextEnd = min(lines.count - 1, lineIndex + 1)
                    let context = lines[contextStart...contextEnd].joined(separator: "\n")
                    
                    let reference = ReferenceInfo(
                        symbolName: symbolName,
                        file: file.path,
                        line: lineIndex + 1,
                        character: line.distance(from: line.startIndex, to: range.lowerBound),
                        context: context,
                        usageType: determineUsageType(line: line, symbolName: symbolName)
                    )
                    
                    references.append(reference)
                }
                
                searchRange = range.upperBound..<line.endIndex
            }
        }
        
        return references
    }
    
    private func findParentSymbols(for symbol: SymbolInfo) async throws -> [SymbolInfo] {
        // Implementation for finding parent classes/protocols
        // This would analyze inheritance chains
        return []
    }
    
    private func findChildSymbols(for symbol: SymbolInfo) async throws -> [SymbolInfo] {
        // Implementation for finding child classes/conforming types
        // This would analyze classes that inherit from the target symbol
        return []
    }
    
    private func findAllSwiftFiles() async throws -> [URL] {
        var swiftFiles: [URL] = []
        
        let enumerator = FileManager.default.enumerator(
            at: projectPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                swiftFiles.append(url)
            }
        }
        
        return swiftFiles
    }
    
    private func isWholeWordMatch(in line: String, range: Swift.Range<String.Index>) -> Bool {
        let beforeIndex = line.index(before: range.lowerBound)
        let afterIndex = range.upperBound
        
        let beforeChar = range.lowerBound > line.startIndex ? line[beforeIndex] : " "
        let afterChar = afterIndex < line.endIndex ? line[afterIndex] : " "
        
        let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        
        return !wordCharacters.contains(beforeChar.unicodeScalars.first!) &&
               !wordCharacters.contains(afterChar.unicodeScalars.first!)
    }
    
    private func determineUsageType(line: String, symbolName: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.contains("func") && trimmedLine.contains(symbolName) {
            return "function_declaration"
        } else if trimmedLine.contains("class") || trimmedLine.contains("struct") {
            return "type_declaration"
        } else if trimmedLine.contains("import") {
            return "import"
        } else if trimmedLine.contains("=") {
            return "assignment"
        } else if trimmedLine.contains("(") && trimmedLine.contains(")") {
            return "function_call"
        } else {
            return "reference"
        }
    }
    
    private func extractAccessLevel(from content: String, at range: NSRange) -> String {
        let prefix = String(content.prefix(range.location))
        
        if prefix.hasSuffix("public ") {
            return "public"
        } else if prefix.hasSuffix("private ") {
            return "private"
        } else if prefix.hasSuffix("fileprivate ") {
            return "fileprivate"
        } else if prefix.hasSuffix("internal ") {
            return "internal"
        } else {
            return "internal" // Default in Swift
        }
    }
    
    // MARK: - Caching
    
    private func getCachedSymbols(for key: String) -> [SymbolInfo]? {
        if Date().timeIntervalSince(lastCacheUpdate) > cacheTimeout {
            symbolCache.removeAll()
            return nil
        }
        return symbolCache[key]
    }
    
    private func setCachedSymbols(_ symbols: [SymbolInfo], for key: String) {
        symbolCache[key] = symbols
        lastCacheUpdate = Date()
    }
}

// MARK: - Supporting Types

public struct ReferenceInfo {
    public let symbolName: String
    public let file: String
    public let line: Int
    public let character: Int
    public let context: String
    public let usageType: String
    
    public init(symbolName: String, file: String, line: Int, character: Int, context: String, usageType: String) {
        self.symbolName = symbolName
        self.file = file
        self.line = line
        self.character = character
        self.context = context
        self.usageType = usageType
    }
}

public struct SymbolHierarchy {
    public let symbol: SymbolInfo
    public let parents: [SymbolInfo]
    public let children: [SymbolInfo]
    
    public init(symbol: SymbolInfo, parents: [SymbolInfo], children: [SymbolInfo]) {
        self.symbol = symbol
        self.parents = parents
        self.children = children
    }
}

public struct SymbolUsageAnalysis {
    public let symbolName: String
    public let totalReferences: Int
    public let uniqueFiles: Int
    public let usagePatterns: [String: Int]
    public let fileDistribution: [String: Int]
    public let mostUsedIn: String?
    
    public init(symbolName: String, totalReferences: Int, uniqueFiles: Int, usagePatterns: [String: Int], fileDistribution: [String: Int], mostUsedIn: String?) {
        self.symbolName = symbolName
        self.totalReferences = totalReferences
        self.uniqueFiles = uniqueFiles
        self.usagePatterns = usagePatterns
        self.fileDistribution = fileDistribution
        self.mostUsedIn = mostUsedIn
    }
}

// Enhanced SymbolInfo with additional computed properties
extension SymbolInfo {
    public var isInherited: Bool { 
        return containerName != nil && !containerName!.isEmpty
    }
}
