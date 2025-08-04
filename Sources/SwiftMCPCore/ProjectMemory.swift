import Foundation
import Logging

/// Enhanced Intelligent Project Memory System with Modern Concurrency
public actor IntelligentProjectMemory {
    private let logger: Logger
    private let projectPath: URL
    private let memoryDirectory: URL
    private var analysisCache: [String: IntelligentAnalysisResult] = [:]
    private var patternHistory: [ProjectPattern] = []
    
    // Modern concurrency integration
    private var modernConcurrency: ModernConcurrencyIntegration?
    
    public init(projectPath: URL, logger: Logger, modernConcurrency: ModernConcurrencyIntegration? = nil) {
        self.projectPath = projectPath
        self.logger = logger
        self.modernConcurrency = modernConcurrency
        self.memoryDirectory = projectPath.appendingPathComponent(".swift-mcp-memory", isDirectory: true)
        
        // Do setup asynchronously without blocking initialization
        Task.detached {
            await self.setupMemoryDirectory()
            await self.loadExistingMemory()
        }
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryDirectory() {
        do {
            try FileManager.default.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)
            logger.info("📁 Enhanced project memory directory created at: \(memoryDirectory.path)")
        } catch {
            logger.error("❌ Failed to create memory directory: \(error)")
        }
    }
    
    private func loadExistingMemory() {
        let memoryFile = memoryDirectory.appendingPathComponent("project-memory.json")
        
        guard FileManager.default.fileExists(atPath: memoryFile.path) else {
            logger.info("🆕 No existing project memory found, starting fresh with modern concurrency")
            return
        }
        
        do {
            let data = try Data(contentsOf: memoryFile)
            let memory = try JSONDecoder().decode(ProjectMemoryData.self, from: data)
            
            self.analysisCache = memory.analysisCache
            self.patternHistory = memory.patternHistory
            
            logger.info("🧠 Loaded enhanced project memory with \(analysisCache.count) cached analyses")
        } catch {
            logger.error("❌ Failed to load project memory: \(error)")
        }
    }
    
    public func saveMemory() async {
        let memoryFile = memoryDirectory.appendingPathComponent("project-memory.json")
        
        let memoryData = ProjectMemoryData(
            analysisCache: analysisCache,
            patternHistory: patternHistory,
            lastUpdated: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(memoryData)
            try data.write(to: memoryFile)
            logger.info("💾 Project memory saved successfully")
        } catch {
            logger.error("❌ Failed to save project memory: \(error)")
        }
    }
    
    // MARK: - Analysis Caching
    
    public func getCachedAnalysis(for key: String) -> IntelligentAnalysisResult? {
        return analysisCache[key]
    }
    
    public func cacheAnalysis(_ result: IntelligentAnalysisResult, for key: String) {
        analysisCache[key] = result
        logger.debug("🔄 Cached analysis for key: \(key)")
    }
    
    public func invalidateCache(for key: String? = nil) {
        if let key = key {
            analysisCache.removeValue(forKey: key)
            logger.info("🗑️ Invalidated cache for key: \(key)")
        } else {
            analysisCache.removeAll()
            logger.info("🗑️ Invalidated all cached analyses")
        }
    }
    
    // MARK: - Pattern Learning
    
    public func recordPattern(_ pattern: ProjectPattern) {
        patternHistory.append(pattern)
        
        // Keep only last 100 patterns to avoid memory bloat
        if patternHistory.count > 100 {
            patternHistory.removeFirst(patternHistory.count - 100)
        }
        
        logger.debug("📈 Recorded new pattern: \(pattern.type)")
    }
    
    public func getPatternFrequency(for type: PatternType) -> Int {
        return patternHistory.filter { $0.type == type }.count
    }
    
    public func getMostCommonPatterns() -> [PatternType: Int] {
        var frequency: [PatternType: Int] = [:]
        
        for pattern in patternHistory {
            frequency[pattern.type, default: 0] += 1
        }
        
        return frequency
    }
    
    public func getRecommendations() -> [String] {
        let commonPatterns = getMostCommonPatterns()
        var recommendations: [String] = []
        
        // Analyze patterns and provide recommendations
        if let mvvmCount = commonPatterns[.mvvm], mvvmCount > 5 {
            recommendations.append("Strong MVVM pattern usage detected. Consider creating MVVM templates.")
        }
        
        if let protocolCount = commonPatterns[.protocolOriented], protocolCount > 10 {
            recommendations.append("High protocol-oriented programming adoption. Excellent Swift practices!")
        }
        
        if let swiftuiCount = commonPatterns[.swiftUI], swiftuiCount > 3 {
            recommendations.append("SwiftUI usage detected. Consider modern iOS architecture patterns.")
        }
        
        return recommendations
    }
    
    // MARK: - Project Evolution Tracking
    
    public func trackProjectEvolution() -> ProjectEvolution {
        let currentTime = Date()
        let recentPatterns = patternHistory.filter { 
            currentTime.timeIntervalSince($0.timestamp) < 30 * 24 * 3600 // Last 30 days
        }
        
        return ProjectEvolution(
            totalPatterns: patternHistory.count,
            recentPatterns: recentPatterns.count,
            evolutionTrend: calculateEvolutionTrend(),
            architecturalMaturity: calculateArchitecturalMaturity()
        )
    }
    
    private func calculateEvolutionTrend() -> String {
        let recent = patternHistory.suffix(10)
        let protocolCount = recent.filter { $0.type == .protocolOriented }.count
        let modernPatternCount = recent.filter { [.swiftUI, .async, .actor].contains($0.type) }.count
        
        if modernPatternCount > 3 {
            return "Modernizing"
        } else if protocolCount > 5 {
            return "Maturing"
        } else {
            return "Stable"
        }
    }
    
    private func calculateArchitecturalMaturity() -> Double {
        let patterns = getMostCommonPatterns()
        let totalPatterns = patterns.values.reduce(0, +)
        
        guard totalPatterns > 0 else { return 0.0 }
        
        let maturePatterns = [PatternType.protocolOriented, .mvvm, .viper, .cleanArchitecture]
        let matureCount = maturePatterns.compactMap { patterns[$0] }.reduce(0, +)
        
        return Double(matureCount) / Double(totalPatterns) * 100
    }
}

// MARK: - Data Structures

public struct ProjectMemoryData: Codable {
    let analysisCache: [String: IntelligentAnalysisResult]
    let patternHistory: [ProjectPattern]
    let lastUpdated: Date
}

public struct IntelligentAnalysisResult: Codable {
    let timestamp: Date
    let analysisType: String
    let result: Data // Encoded analysis result
    let checksum: String // For invalidation detection
}

public struct ProjectPattern: Codable {
    let type: PatternType
    let confidence: Double
    let timestamp: Date
    let context: [String: String]
}

public enum PatternType: String, Codable, CaseIterable {
    case mvc = "MVC"
    case mvvm = "MVVM"
    case viper = "VIPER"
    case cleanArchitecture = "Clean Architecture"
    case protocolOriented = "Protocol-Oriented"
    case swiftUI = "SwiftUI"
    case uiKit = "UIKit"
    case async = "Async/Await"
    case actor = "Actor Model"
    case singleton = "Singleton"
    case factory = "Factory"
    case observer = "Observer"
    case delegate = "Delegate"
}

public struct ProjectEvolution: Codable {
    let totalPatterns: Int
    let recentPatterns: Int
    let evolutionTrend: String
    let architecturalMaturity: Double
}
