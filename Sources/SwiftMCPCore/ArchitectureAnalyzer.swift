import Foundation
import Logging

/// Analyze Swift project architecture patterns
public class ArchitectureAnalyzer {
    private let projectPath: URL
    private let logger: Logger
    
    public init(projectPath: URL, logger: Logger) {
        self.projectPath = projectPath
        self.logger = logger
    }
    
    /// Detect the architecture pattern used in the project
    public func detectArchitecturePattern() async throws -> ArchitecturePattern {
        logger.debug("🏗️ Detecting architecture pattern in \(projectPath.path)")
        
        let structure = try await analyzeDirectoryStructure()
        
        // Check for features-based architecture
        if structure.contains("Features") && structure.contains("Core") {
            return .featuresBased
        }
        
        // Check for MVVM
        if hasPattern(in: structure, patterns: ["Models", "Views", "ViewModels"]) {
            return .mvvm
        }
        
        // Check for MVC
        if hasPattern(in: structure, patterns: ["Models", "Views", "Controllers"]) {
            return .mvc
        }
        
        // Check for VIPER
        if hasPattern(in: structure, patterns: ["View", "Interactor", "Presenter", "Entity", "Router"]) {
            return .viper
        }
        
        // Check for Clean Architecture
        if hasPattern(in: structure, patterns: ["Domain", "Data", "Presentation"]) {
            return .cleanArchitecture
        }
        
        // Check for Modular structure (Swift Package or similar)
        if structure.contains("Sources") && structure.contains("Tests") {
            return .modular
        }
        
        return .custom
    }
    
    /// Extract project modules and features
    public func extractModulesAndFeatures() async throws -> ProjectStructure {
        logger.debug("📦 Extracting modules and features")
        
        var modules: [Module] = []
        var features: [Feature] = []
        
        // Look for features directory
        let featuresPath = projectPath.appendingPathComponent("Features")
        if FileManager.default.fileExists(atPath: featuresPath.path) {
            features = try await extractFeatures(from: featuresPath)
        }
        
        // Look for modules
        let sourcesPath = projectPath.appendingPathComponent("Sources")
        if FileManager.default.fileExists(atPath: sourcesPath.path) {
            modules = try await extractModules(from: sourcesPath)
        }
        
        return ProjectStructure(modules: modules, features: features)
    }
    
    /// Analyze layer separation in the project
    public func analyzeLayerSeparation() async throws -> LayerAnalysis {
        logger.debug("🎯 Analyzing layer separation")
        
        let layers = LayerAnalysis()
        
        // Presentation layer
        layers.presentation = try await findFiles(withPatterns: [
            "**/Views/**/*.swift",
            "**/ViewControllers/**/*.swift", 
            "**/ViewModels/**/*.swift",
            "**/UI/**/*.swift"
        ])
        
        // Domain layer
        layers.domain = try await findFiles(withPatterns: [
            "**/Models/**/*.swift",
            "**/Entities/**/*.swift",
            "**/UseCases/**/*.swift",
            "**/Domain/**/*.swift"
        ])
        
        // Data layer
        layers.data = try await findFiles(withPatterns: [
            "**/Repositories/**/*.swift",
            "**/DataSources/**/*.swift",
            "**/Networking/**/*.swift",
            "**/Database/**/*.swift"
        ])
        
        // Infrastructure layer
        layers.infrastructure = try await findFiles(withPatterns: [
            "**/Utilities/**/*.swift",
            "**/Extensions/**/*.swift",
            "**/Core/**/*.swift",
            "**/Common/**/*.swift"
        ])
        
        return layers
    }
    
    // MARK: - Private Methods
    
    private func analyzeDirectoryStructure() async throws -> Set<String> {
        var directories = Set<String>()
        
        let enumerator = FileManager.default.enumerator(
            at: projectPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                directories.insert(url.lastPathComponent)
            }
        }
        
        return directories
    }
    
    private func hasPattern(in structure: Set<String>, patterns: [String]) -> Bool {
        return patterns.allSatisfy { pattern in
            structure.contains { dir in
                dir.contains(pattern)
            }
        }
    }
    
    private func extractFeatures(from featuresPath: URL) async throws -> [Feature] {
        var features: [Feature] = []
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: featuresPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        
        for url in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                
                let components = try await analyzeFeatureComponents(in: url)
                let feature = Feature(
                    name: url.lastPathComponent,
                    path: url.path,
                    components: components
                )
                features.append(feature)
            }
        }
        
        return features
    }
    
    private func analyzeFeatureComponents(in featurePath: URL) async throws -> FeatureComponents {
        var components = FeatureComponents()
        
        let swiftFiles = try await findSwiftFiles(in: featurePath)
        
        for file in swiftFiles {
            let fileName = file.lastPathComponent
            
            if fileName.contains("View") && !fileName.contains("ViewModel") {
                components.views.append(fileName)
            } else if fileName.contains("ViewModel") {
                components.viewModels.append(fileName)
            } else if fileName.contains("Model") {
                components.models.append(fileName)
            } else if fileName.contains("Service") || fileName.contains("Manager") {
                components.services.append(fileName)
            } else if fileName.contains("Repository") {
                components.repositories.append(fileName)
            }
        }
        
        return components
    }
    
    private func extractModules(from sourcesPath: URL) async throws -> [Module] {
        var modules: [Module] = []
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: sourcesPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        
        for url in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                
                let swiftFiles = try await findSwiftFiles(in: url)
                let module = Module(
                    name: url.lastPathComponent,
                    path: url.path,
                    fileCount: swiftFiles.count
                )
                modules.append(module)
            }
        }
        
        return modules
    }
    
    private func findFiles(withPatterns patterns: [String]) async throws -> [String] {
        var foundFiles: [String] = []
        
        for pattern in patterns {
            // Simple glob pattern matching - can be enhanced with proper glob library
            let components = pattern.components(separatedBy: "/")
            if let lastComponent = components.last {
                let files = try await findSwiftFiles(in: projectPath)
                foundFiles.append(contentsOf: files.compactMap { url in
                    if url.path.contains(lastComponent.replacingOccurrences(of: "*.swift", with: "")) {
                        return url.path
                    }
                    return nil
                })
            }
        }
        
        return foundFiles
    }
    
    private func findSwiftFiles(in directory: URL) async throws -> [URL] {
        var swiftFiles: [URL] = []
        
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                swiftFiles.append(url)
            }
        }
        
        return swiftFiles
    }
    
    /// Analyze if project follows Protocol-Oriented Programming paradigm
    public func analyzePOPUsage() async throws -> POPAnalysisResult {
        logger.debug("🔍 Analyzing Protocol-Oriented Programming usage")
        
        var totalFiles = 0
        var protocolDefinitions = 0
        var protocolExtensions = 0
        var protocolConformances = 0
        var structUsage = 0
        var classUsage = 0
        var protocolAsTypeUsage = 0
        var popPatterns: [String] = []
        
        for file in try await findSwiftFiles(in: projectPath) {
            totalFiles += 1
            let content = try String(contentsOf: file)
            
            // Count protocol definitions using NSRegularExpression
            protocolDefinitions += countMatches(in: content, pattern: "protocol\\s+\\w+")
            
            // Count protocol extensions
            protocolExtensions += countMatches(in: content, pattern: "extension\\s+\\w+.*:.*\\w+")
            
            // Count protocol conformances
            protocolConformances += countMatches(in: content, pattern: ":\\s*\\w+Protocol|:\\s*\\w+able")
            
            // Count struct vs class usage
            structUsage += countMatches(in: content, pattern: "struct\\s+\\w+")
            classUsage += countMatches(in: content, pattern: "class\\s+\\w+")
            
            // Count protocol as type usage
            protocolAsTypeUsage += countMatches(in: content, pattern: "var\\s+\\w+:\\s*\\w+Protocol|let\\s+\\w+:\\s*\\w+Protocol")
            
            // Detect POP patterns
            if content.contains("protocol") && content.contains("extension") {
                popPatterns.append("Protocol with Extensions")
            }
            
            if content.contains("associatedtype") {
                popPatterns.append("Generic Protocols")
            }
            
            if content.contains("where") && content.contains("protocol") {
                popPatterns.append("Protocol Constraints")
            }
        }
        
        // Calculate POP score (0-100)
        let structToClassRatio = classUsage > 0 ? Double(structUsage) / Double(classUsage) : Double(structUsage)
        let protocolUsageScore = totalFiles > 0 ? Double(protocolDefinitions + protocolExtensions) / Double(totalFiles) : 0
        let conformanceScore = protocolDefinitions > 0 ? Double(protocolConformances) / Double(protocolDefinitions) : 0
        
        let popScore = min(100, Int((structToClassRatio * 30 + protocolUsageScore * 40 + conformanceScore * 30)))
        
        let level: POPAdoptionLevel
        switch popScore {
        case 80...:
            level = .high
        case 50..<80:
            level = .medium
        case 20..<50:
            level = .low
        default:
            level = .minimal
        }
        
        return POPAnalysisResult(
            totalFiles: totalFiles,
            protocolDefinitions: protocolDefinitions,
            protocolExtensions: protocolExtensions,
            protocolConformances: protocolConformances,
            structUsage: structUsage,
            classUsage: classUsage,
            protocolAsTypeUsage: protocolAsTypeUsage,
            popPatterns: Array(Set(popPatterns)),
            popScore: popScore,
            adoptionLevel: level,
            recommendations: generatePOPRecommendations(level: level, structToClassRatio: structToClassRatio)
        )
    }
    
    private func countMatches(in text: String, pattern: String) -> Int {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.numberOfMatches(in: text, options: [], range: range)
        } catch {
            logger.warning("Failed to create regex for pattern: \(pattern)")
            return 0
        }
    }
    
    private func generatePOPRecommendations(level: POPAdoptionLevel, structToClassRatio: Double) -> [String] {
        var recommendations: [String] = []
        
        switch level {
        case .minimal:
            recommendations.append("Consider defining protocols for common behaviors")
            recommendations.append("Use protocol extensions to provide default implementations")
            recommendations.append("Prefer structs over classes when inheritance is not needed")
            
        case .low:
            recommendations.append("Increase protocol usage for better abstraction")
            recommendations.append("Add more protocol extensions for code reuse")
            
        case .medium:
            recommendations.append("Good POP adoption! Consider using associated types for generic protocols")
            recommendations.append("Leverage protocol constraints for more type safety")
            
        case .high:
            recommendations.append("Excellent POP adoption! Your code follows Swift best practices")
        }
        
        if structToClassRatio < 1.0 {
            recommendations.append("Consider using more structs (value types) instead of classes")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public enum ArchitecturePattern: String, CaseIterable {
    case mvc                = "MVC"
    case mvvm               = "MVVM" 
    case viper              = "VIPER"
    case featuresBased      = "Features-based"
    case cleanArchitecture  = "Clean Architecture"
    case modular            = "Modular"
    case custom             = "Custom"
}

public struct ProjectStructure {
    public let modules: [Module]
    public let features: [Feature]
    
    public init(modules: [Module], features: [Feature]) {
        self.modules = modules
        self.features = features
    }
}

public struct Module {
    public let name: String
    public let path: String
    public let fileCount: Int
    
    public init(name: String, path: String, fileCount: Int) {
        self.name = name
        self.path = path
        self.fileCount = fileCount
    }
}

public struct Feature {
    public let name: String
    public let path: String
    public let components: FeatureComponents
    
    public init(name: String, path: String, components: FeatureComponents) {
        self.name = name
        self.path = path
        self.components = components
    }
}

public struct FeatureComponents {
    public var views: [String] = []
    public var viewModels: [String] = []
    public var models: [String] = []
    public var services: [String] = []
    public var repositories: [String] = []
    
    public init() {}
}

public class LayerAnalysis {
    public var presentation: [String] = []
    public var domain: [String] = []
    public var data: [String] = []
    public var infrastructure: [String] = []
    
    public init() {}
}

// MARK: - Protocol-Oriented Programming Analysis

public struct POPAnalysisResult {
    public let totalFiles: Int
    public let protocolDefinitions: Int
    public let protocolExtensions: Int
    public let protocolConformances: Int
    public let structUsage: Int
    public let classUsage: Int
    public let protocolAsTypeUsage: Int
    public let popPatterns: [String]
    public let popScore: Int
    public let adoptionLevel: POPAdoptionLevel
    public let recommendations: [String]
    
    public init(totalFiles: Int, protocolDefinitions: Int, protocolExtensions: Int, protocolConformances: Int, structUsage: Int, classUsage: Int, protocolAsTypeUsage: Int, popPatterns: [String], popScore: Int, adoptionLevel: POPAdoptionLevel, recommendations: [String]) {
        self.totalFiles = totalFiles
        self.protocolDefinitions = protocolDefinitions
        self.protocolExtensions = protocolExtensions
        self.protocolConformances = protocolConformances
        self.structUsage = structUsage
        self.classUsage = classUsage
        self.protocolAsTypeUsage = protocolAsTypeUsage
        self.popPatterns = popPatterns
        self.popScore = popScore
        self.adoptionLevel = adoptionLevel
        self.recommendations = recommendations
    }
}

public enum POPAdoptionLevel: String, CaseIterable {
    case minimal = "Minimal"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}
