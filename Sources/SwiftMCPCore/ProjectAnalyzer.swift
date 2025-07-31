import Foundation
import Logging

/// Comprehensive project analysis combining architecture detection and code metrics
public class ProjectAnalyzer {
    private let projectPath: URL
    private let logger: Logger
    private let architectureAnalyzer: ArchitectureAnalyzer
    private let symbolSearchEngine: SymbolSearchEngine
    
    public init(projectPath: URL, logger: Logger) {
        self.projectPath = projectPath
        self.logger = logger
        self.architectureAnalyzer = ArchitectureAnalyzer(projectPath: projectPath, logger: logger)
        self.symbolSearchEngine = SymbolSearchEngine(projectPath: projectPath, logger: logger)
    }
    
    /// Perform comprehensive project analysis
    public func analyzeProject() async throws -> ProjectAnalysisResult {
        logger.info("🔍 Starting comprehensive project analysis for \(projectPath.lastPathComponent)")
        
        async let architecturePattern = architectureAnalyzer.detectArchitecturePattern()
        async let projectStructure = architectureAnalyzer.extractModulesAndFeatures()
        async let layerAnalysis = architectureAnalyzer.analyzeLayerSeparation()
        async let dependencies = analyzeDependencies()
        async let codeMetrics = calculateCodeMetrics()
        async let testCoverage = analyzeTestStructure()
        
        let result = ProjectAnalysisResult(
            projectName: projectPath.lastPathComponent,
            projectType: try await determineProjectType(),
            architecturePattern: try await architecturePattern,
            structure: try await projectStructure,
            layers: try await layerAnalysis,
            dependencies: try await dependencies,
            metrics: try await codeMetrics,
            testStructure: try await testCoverage,
            recommendations: []
        )
        
        // Generate recommendations based on analysis
        let recommendations = try await generateRecommendations(for: result)
        
        return ProjectAnalysisResult(
            projectName: result.projectName,
            projectType: result.projectType,
            architecturePattern: result.architecturePattern,
            structure: result.structure,
            layers: result.layers,
            dependencies: result.dependencies,
            metrics: result.metrics,
            testStructure: result.testStructure,
            recommendations: recommendations
        )
    }
    
    /// Create project memory/documentation
    public func createProjectMemory() async throws -> ProjectMemory {
        logger.info("📝 Creating project memory")
        
        let analysis = try await analyzeProject()
        let keySymbols = try await findKeySymbols()
        let patterns = try await identifyCodePatterns()
        
        return ProjectMemory(
            analysis: analysis,
            keySymbols: keySymbols,
            codePatterns: patterns,
            lastUpdated: Date()
        )
    }
    
    /// Generate migration recommendations
    public func generateMigrationPlan(to targetArchitecture: ArchitecturePattern) async throws -> MigrationPlan {
        logger.info("🚀 Generating migration plan to \(targetArchitecture.rawValue)")
        
        let currentAnalysis = try await analyzeProject()
        let currentArchitecture = currentAnalysis.architecturePattern
        
        if currentArchitecture == targetArchitecture {
            return MigrationPlan(
                from: currentArchitecture,
                to: targetArchitecture,
                steps: [],
                estimatedEffort: .none,
                risks: [],
                benefits: ["Architecture already matches target pattern"]
            )
        }
        
        let steps = generateMigrationSteps(from: currentArchitecture, to: targetArchitecture)
        let effort = estimateMigrationEffort(steps: steps, currentStructure: currentAnalysis.structure)
        let risks = identifyMigrationRisks(from: currentArchitecture, to: targetArchitecture)
        let benefits = identifyMigrationBenefits(from: currentArchitecture, to: targetArchitecture)
        
        return MigrationPlan(
            from: currentArchitecture,
            to: targetArchitecture,
            steps: steps,
            estimatedEffort: effort,
            risks: risks,
            benefits: benefits
        )
    }
    
    // MARK: - Private Analysis Methods
    
    private func determineProjectType() async throws -> ProjectType {
        let packageSwift = projectPath.appendingPathComponent("Package.swift")
        let xcodeProjectFiles = try FileManager.default.contentsOfDirectory(at: projectPath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xcodeproj" }
        let xcworkspaceFiles = try FileManager.default.contentsOfDirectory(at: projectPath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xcworkspace" }
        
        if !xcworkspaceFiles.isEmpty {
            return .xcworkspace
        } else if !xcodeProjectFiles.isEmpty {
            return .xcodeproj
        } else if FileManager.default.fileExists(atPath: packageSwift.path) {
            return .swiftPackage
        } else {
            return .unknown
        }
    }
    
    private func analyzeDependencies() async throws -> DependencyAnalysis {
        var analysis = DependencyAnalysis()
        
        // Analyze Package.swift
        let packageSwift = projectPath.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: packageSwift.path) {
            analysis.swiftPackages = try await parsePackageSwift(packageSwift)
        }
        
        // Analyze Podfile
        let podfile = projectPath.appendingPathComponent("Podfile")
        if FileManager.default.fileExists(atPath: podfile.path) {
            analysis.cocoapods = try await parsePodfile(podfile)
        }
        
        // Analyze Cartfile
        let cartfile = projectPath.appendingPathComponent("Cartfile")
        if FileManager.default.fileExists(atPath: cartfile.path) {
            analysis.carthage = try await parseCartfile(cartfile)
        }
        
        // Analyze import statements
        analysis.internalDependencies = try await analyzeImportStatements()
        
        return analysis
    }
    
    private func calculateCodeMetrics() async throws -> CodeMetrics {
        logger.debug("📊 Calculating code metrics")
        
        let swiftFiles = try await findAllSwiftFiles()
        
        var totalLines = 0
        let totalFiles = swiftFiles.count
        var longestFile: (path: String, lines: Int)?
        var complexityIndicators: [String] = []
        
        for file in swiftFiles {
            guard let content = try? String(contentsOf: file) else { continue }
            
            let lines = content.components(separatedBy: .newlines)
            let lineCount = lines.count
            totalLines += lineCount
            
            // Track longest file
            if longestFile == nil || lineCount > longestFile!.lines {
                longestFile = (file.path, lineCount)
            }
            
            // Check for complexity indicators
            let nestingLevel = calculateNestingLevel(in: lines)
            if nestingLevel > 4 {
                complexityIndicators.append("Deep nesting in \(file.lastPathComponent)")
            }
            
            if lineCount > 500 {
                complexityIndicators.append("Large file: \(file.lastPathComponent)")
            }
        }
        
        return CodeMetrics(
            totalLines: totalLines,
            totalFiles: totalFiles,
            averageFileLength: totalFiles > 0 ? totalLines / totalFiles : 0,
            longestFile: longestFile?.path,
            longestFileLines: longestFile?.lines,
            complexityIndicators: complexityIndicators
        )
    }
    
    private func analyzeTestStructure() async throws -> TestStructure {
        logger.debug("🧪 Analyzing test structure")
        
        let testFiles = try await findTestFiles()
        let testTargets = try await identifyTestTargets()
        
        var testTypes: [String] = []
        var coverage = TestCoverage()
        
        for file in testFiles {
            guard let content = try? String(contentsOf: file) else { continue }
            
            if content.contains("XCTestCase") {
                testTypes.append("Unit Tests")
            }
            if content.contains("XCUIApplication") {
                testTypes.append("UI Tests")
            }
            if content.contains("@testable import") {
                testTypes.append("Integration Tests")
            }
        }
        
        // Estimate coverage (basic heuristic)
        let sourceFiles = try await findAllSwiftFiles()
        let nonTestSourceFiles = sourceFiles.filter { !$0.path.contains("Test") }
        
        coverage.estimatedCoverage = testFiles.count > 0 ? 
            min(Double(testFiles.count) / Double(nonTestSourceFiles.count) * 100, 100) : 0
        coverage.hasTests = !testFiles.isEmpty
        
        return TestStructure(
            testFiles: testFiles.map { $0.path },
            testTargets: testTargets,
            testTypes: Array(Set(testTypes)),
            coverage: coverage
        )
    }
    
    private func findKeySymbols() async throws -> [SymbolInfo] {
        logger.debug("🔑 Finding key symbols")
        
        // Find important classes, protocols, and main entry points
        var keySymbols: [SymbolInfo] = []
        
        // Find main app classes
        let appDelegates = try await symbolSearchEngine.findSymbols(namePattern: "AppDelegate")
        let sceneDelegate = try await symbolSearchEngine.findSymbols(namePattern: "SceneDelegate")
        let mainViews = try await symbolSearchEngine.findSymbols(namePattern: "ContentView")
        
        keySymbols.append(contentsOf: appDelegates)
        keySymbols.append(contentsOf: sceneDelegate)
        keySymbols.append(contentsOf: mainViews)
        
        // Find key protocols
        let protocols = try await symbolSearchEngine.findSymbols(symbolType: "protocol")
        keySymbols.append(contentsOf: protocols.prefix(10)) // Top 10 protocols
        
        // Find main classes
        let classes = try await symbolSearchEngine.findSymbols(symbolType: "class")
        keySymbols.append(contentsOf: classes.prefix(20)) // Top 20 classes
        
        return keySymbols
    }
    
    private func identifyCodePatterns() async throws -> [CodePattern] {
        logger.debug("🎨 Identifying code patterns")
        
        var patterns: [CodePattern] = []
        
        // Look for common design patterns
        let singletons = try await findSingletonPattern()
        let observers = try await findObserverPattern()
        let factories = try await findFactoryPattern()
        let coordinators = try await findCoordinatorPattern()
        
        patterns.append(contentsOf: singletons)
        patterns.append(contentsOf: observers)
        patterns.append(contentsOf: factories)
        patterns.append(contentsOf: coordinators)
        
        return patterns
    }
    
    private func generateRecommendations(for analysis: ProjectAnalysisResult) async throws -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Architecture recommendations
        if analysis.architecturePattern == .custom {
            recommendations.append(Recommendation(
                type: .architecture,
                priority: .medium,
                title: "Consider adopting a standard architecture pattern",
                description: "The project uses a custom architecture. Consider migrating to MVVM or Features-based architecture for better maintainability.",
                actionItems: [
                    "Evaluate current code organization",
                    "Choose appropriate architecture pattern",
                    "Create migration plan"
                ]
            ))
        }
        
        // Code quality recommendations
        if analysis.metrics.averageFileLength > 300 {
            recommendations.append(Recommendation(
                type: .codeQuality,
                priority: .high,
                title: "Reduce file sizes",
                description: "Average file length is \(analysis.metrics.averageFileLength) lines. Consider breaking down large files.",
                actionItems: [
                    "Identify largest files",
                    "Extract reusable components",
                    "Split responsibilities"
                ]
            ))
        }
        
        // Test recommendations
        if analysis.testStructure.coverage.estimatedCoverage < 50 {
            recommendations.append(Recommendation(
                type: .testing,
                priority: .high,
                title: "Improve test coverage",
                description: "Estimated test coverage is \(Int(analysis.testStructure.coverage.estimatedCoverage))%. Aim for at least 70%.",
                actionItems: [
                    "Add unit tests for core functionality",
                    "Implement integration tests",
                    "Set up code coverage tracking"
                ]
            ))
        }
        
        // Dependency recommendations
        if analysis.dependencies.swiftPackages.count + analysis.dependencies.cocoapods.count > 20 {
            recommendations.append(Recommendation(
                type: .dependencies,
                priority: .medium,
                title: "Review dependency count",
                description: "Project has many external dependencies. Consider consolidating or removing unused ones.",
                actionItems: [
                    "Audit all dependencies",
                    "Remove unused packages",
                    "Consider alternatives to heavy dependencies"
                ]
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Migration Planning
    
    private func generateMigrationSteps(from: ArchitecturePattern, to: ArchitecturePattern) -> [MigrationStep] {
        switch (from, to) {
        case (.custom, .mvvm):
            return [
                MigrationStep(title: "Identify View Controllers", description: "List all view controllers in the project"),
                MigrationStep(title: "Create ViewModels", description: "Extract business logic into view models"),
                MigrationStep(title: "Update Data Binding", description: "Implement proper data binding between views and view models"),
                MigrationStep(title: "Refactor Models", description: "Ensure models are pure data containers"),
                MigrationStep(title: "Update Tests", description: "Add tests for view models and update existing tests")
            ]
        case (.mvc, .mvvm):
            return [
                MigrationStep(title: "Extract ViewModels", description: "Move business logic from controllers to view models"),
                MigrationStep(title: "Implement Data Binding", description: "Set up binding between views and view models"),
                MigrationStep(title: "Slim Controllers", description: "Reduce controller responsibilities to view lifecycle only"),
                MigrationStep(title: "Update Navigation", description: "Adjust navigation logic for MVVM pattern")
            ]
        case (_, .featuresBased):
            return [
                MigrationStep(title: "Identify Features", description: "Group related functionality into feature modules"),
                MigrationStep(title: "Create Feature Structure", description: "Set up directory structure for each feature"),
                MigrationStep(title: "Move Code to Features", description: "Relocate code files to appropriate feature folders"),
                MigrationStep(title: "Define Feature Interfaces", description: "Create clear interfaces between features"),
                MigrationStep(title: "Update Dependencies", description: "Ensure proper dependency direction between features")
            ]
        default:
            return [
                MigrationStep(title: "Custom Migration", description: "Define specific steps for this migration path")
            ]
        }
    }
    
    private func estimateMigrationEffort(steps: [MigrationStep], currentStructure: ProjectStructure) -> MigrationEffort {
        let fileCount = currentStructure.modules.reduce(0) { $0 + $1.fileCount }
        let featureCount = currentStructure.features.count
        
        if fileCount < 50 && featureCount < 5 {
            return .low
        } else if fileCount < 150 && featureCount < 15 {
            return .medium
        } else {
            return .high
        }
    }
    
    private func identifyMigrationRisks(from: ArchitecturePattern, to: ArchitecturePattern) -> [String] {
        var risks: [String] = []
        
        risks.append("Potential breaking changes during refactoring")
        risks.append("Temporary reduction in development velocity")
        risks.append("Need for team training on new architecture")
        
        if from == .custom {
            risks.append("Unclear current architecture may complicate migration")
        }
        
        return risks
    }
    
    private func identifyMigrationBenefits(from: ArchitecturePattern, to: ArchitecturePattern) -> [String] {
        var benefits: [String] = []
        
        switch to {
        case .mvvm:
            benefits.append("Better separation of concerns")
            benefits.append("Improved testability")
            benefits.append("Easier unit testing of business logic")
        case .featuresBased:
            benefits.append("Better code organization")
            benefits.append("Independent feature development")
            benefits.append("Easier team collaboration")
            benefits.append("Reduced merge conflicts")
        case .viper:
            benefits.append("Clear separation of responsibilities")
            benefits.append("High testability")
            benefits.append("Good for large teams")
        default:
            benefits.append("Standardized architecture approach")
            benefits.append("Better code maintainability")
        }
        
        return benefits
    }
    
    // MARK: - Helper Methods
    
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
    
    private func findTestFiles() async throws -> [URL] {
        let allFiles = try await findAllSwiftFiles()
        return allFiles.filter { url in
            url.path.contains("Test") || url.lastPathComponent.hasSuffix("Tests.swift")
        }
    }
    
    private func identifyTestTargets() async throws -> [String] {
        // This would typically parse the Xcode project file or Package.swift
        // For now, return common test target names
        return ["UnitTests", "IntegrationTests", "UITests"]
    }
    
    private func calculateNestingLevel(in lines: [String]) -> Int {
        var maxLevel = 0
        var currentLevel = 0
        
        for line in lines {
            currentLevel += line.filter { $0 == "{" }.count
            currentLevel -= line.filter { $0 == "}" }.count
            maxLevel = max(maxLevel, currentLevel)
        }
        
        return maxLevel
    }
    
    // MARK: - Dependency Parsing
    
    private func parsePackageSwift(_ file: URL) async throws -> [Dependency] {
        guard let content = try? String(contentsOf: file) else { return [] }
        
        var dependencies: [Dependency] = []
        
        // Simple regex to find package dependencies
        let pattern = #"\.package\((?:url|name):\s*"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(content.startIndex..., in: content)
        
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match = match,
                  match.numberOfRanges > 1 else { return }
            
            let nsRange = match.range(at: 1)
            guard nsRange.location != NSNotFound else { return }
            
            let startIndex = content.index(content.startIndex, offsetBy: nsRange.location)
            let endIndex = content.index(startIndex, offsetBy: nsRange.length)
            let url = String(content[startIndex..<endIndex])
            
            dependencies.append(Dependency(name: url, type: .swiftPackage, version: nil))
        }
        
        return dependencies
    }
    
    private func parsePodfile(_ file: URL) async throws -> [Dependency] {
        guard let content = try? String(contentsOf: file) else { return [] }
        
        var dependencies: [Dependency] = []
        
        let pattern = #"pod\s+['"]([^'"]+)['"]"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(content.startIndex..., in: content)
        
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match = match,
                  match.numberOfRanges > 1 else { return }
            
            let nsRange = match.range(at: 1)
            guard nsRange.location != NSNotFound else { return }
            
            let startIndex = content.index(content.startIndex, offsetBy: nsRange.location)
            let endIndex = content.index(startIndex, offsetBy: nsRange.length)
            let name = String(content[startIndex..<endIndex])
            
            dependencies.append(Dependency(name: name, type: .cocoapod, version: nil))
        }
        
        return dependencies
    }
    
    private func parseCartfile(_ file: URL) async throws -> [Dependency] {
        guard let content = try? String(contentsOf: file) else { return [] }
        
        var dependencies: [Dependency] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if parts.count >= 2 {
                    let name = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    dependencies.append(Dependency(name: name, type: .carthage, version: nil))
                }
            }
        }
        
        return dependencies
    }
    
    private func analyzeImportStatements() async throws -> [String] {
        let swiftFiles = try await findAllSwiftFiles()
        var imports = Set<String>()
        
        for file in swiftFiles {
            guard let content = try? String(contentsOf: file) else { continue }
            
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("import ") {
                    let importName = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                    imports.insert(importName)
                }
            }
        }
        
        return Array(imports).sorted()
    }
    
    // MARK: - Pattern Detection
    
    private func findSingletonPattern() async throws -> [CodePattern] {
        let symbols = try await symbolSearchEngine.findSymbols(namePattern: "shared", useRegex: false)
        return symbols.map { symbol in
            CodePattern(
                name: "Singleton",
                description: "Singleton pattern detected in \(symbol.name)",
                location: symbol.location.uri,
                confidence: 0.8
            )
        }
    }
    
    private func findObserverPattern() async throws -> [CodePattern] {
        let notificationSymbols = try await symbolSearchEngine.findSymbols(namePattern: "Notification", useRegex: false)
        let delegateSymbols = try await symbolSearchEngine.findSymbols(namePattern: "Delegate", useRegex: false)
        
        var patterns: [CodePattern] = []
        
        patterns.append(contentsOf: notificationSymbols.map { symbol in
            CodePattern(
                name: "Observer (Notification)",
                description: "Observer pattern using notifications in \(symbol.name)",
                location: symbol.location.uri,
                confidence: 0.7
            )
        })
        
        patterns.append(contentsOf: delegateSymbols.map { symbol in
            CodePattern(
                name: "Observer (Delegate)",
                description: "Observer pattern using delegation in \(symbol.name)",
                location: symbol.location.uri,
                confidence: 0.9
            )
        })
        
        return patterns
    }
    
    private func findFactoryPattern() async throws -> [CodePattern] {
        let factorySymbols = try await symbolSearchEngine.findSymbols(namePattern: "Factory", useRegex: false)
        return factorySymbols.map { symbol in
            CodePattern(
                name: "Factory",
                description: "Factory pattern detected in \(symbol.name)",
                location: symbol.location.uri,
                confidence: 0.85
            )
        }
    }
    
    private func findCoordinatorPattern() async throws -> [CodePattern] {
        let coordinatorSymbols = try await symbolSearchEngine.findSymbols(namePattern: "Coordinator", useRegex: false)
        return coordinatorSymbols.map { symbol in
            CodePattern(
                name: "Coordinator",
                description: "Coordinator pattern detected in \(symbol.name)",
                location: symbol.location.uri,
                confidence: 0.9
            )
        }
    }
}

// MARK: - Supporting Types

public struct ProjectAnalysisResult {
    public let projectName: String
    public let projectType: ProjectType
    public let architecturePattern: ArchitecturePattern
    public let structure: ProjectStructure
    public let layers: LayerAnalysis
    public let dependencies: DependencyAnalysis
    public let metrics: CodeMetrics
    public let testStructure: TestStructure
    public let recommendations: [Recommendation]
    
    public init(projectName: String, projectType: ProjectType, architecturePattern: ArchitecturePattern, structure: ProjectStructure, layers: LayerAnalysis, dependencies: DependencyAnalysis, metrics: CodeMetrics, testStructure: TestStructure, recommendations: [Recommendation]) {
        self.projectName = projectName
        self.projectType = projectType
        self.architecturePattern = architecturePattern
        self.structure = structure
        self.layers = layers
        self.dependencies = dependencies
        self.metrics = metrics
        self.testStructure = testStructure
        self.recommendations = recommendations
    }
}

public enum ProjectType: String {
    case xcodeproj = "Xcode Project"
    case xcworkspace = "Xcode Workspace"
    case swiftPackage = "Swift Package"
    case unknown = "Unknown"
}

public struct DependencyAnalysis {
    public var swiftPackages: [Dependency] = []
    public var cocoapods: [Dependency] = []
    public var carthage: [Dependency] = []
    public var internalDependencies: [String] = []
    
    public init() {}
}

public struct Dependency {
    public let name: String
    public let type: DependencyType
    public let version: String?
    
    public init(name: String, type: DependencyType, version: String?) {
        self.name = name
        self.type = type
        self.version = version
    }
}

public enum DependencyType {
    case swiftPackage
    case cocoapod
    case carthage
    case framework
}

public struct CodeMetrics {
    public let totalLines: Int
    public let totalFiles: Int
    public let averageFileLength: Int
    public let longestFile: String?
    public let longestFileLines: Int?
    public let complexityIndicators: [String]
    
    public init(totalLines: Int, totalFiles: Int, averageFileLength: Int, longestFile: String?, longestFileLines: Int?, complexityIndicators: [String]) {
        self.totalLines = totalLines
        self.totalFiles = totalFiles
        self.averageFileLength = averageFileLength
        self.longestFile = longestFile
        self.longestFileLines = longestFileLines
        self.complexityIndicators = complexityIndicators
    }
}

public struct TestStructure {
    public let testFiles: [String]
    public let testTargets: [String]
    public let testTypes: [String]
    public let coverage: TestCoverage
    
    public init(testFiles: [String], testTargets: [String], testTypes: [String], coverage: TestCoverage) {
        self.testFiles = testFiles
        self.testTargets = testTargets
        self.testTypes = testTypes
        self.coverage = coverage
    }
}

public struct TestCoverage {
    public var estimatedCoverage: Double = 0
    public var hasTests: Bool = false
    
    public init() {}
}

public struct ProjectMemory {
    public let analysis: ProjectAnalysisResult
    public let keySymbols: [SymbolInfo]
    public let codePatterns: [CodePattern]
    public let lastUpdated: Date
    
    public init(analysis: ProjectAnalysisResult, keySymbols: [SymbolInfo], codePatterns: [CodePattern], lastUpdated: Date) {
        self.analysis = analysis
        self.keySymbols = keySymbols
        self.codePatterns = codePatterns
        self.lastUpdated = lastUpdated
    }
}

public struct CodePattern {
    public let name: String
    public let description: String
    public let location: String
    public let confidence: Double
    
    public init(name: String, description: String, location: String, confidence: Double) {
        self.name = name
        self.description = description
        self.location = location
        self.confidence = confidence
    }
}

public struct Recommendation {
    public let type: RecommendationType
    public let priority: Priority
    public let title: String
    public let description: String
    public let actionItems: [String]
    
    public init(type: RecommendationType, priority: Priority, title: String, description: String, actionItems: [String]) {
        self.type = type
        self.priority = priority
        self.title = title
        self.description = description
        self.actionItems = actionItems
    }
}

public enum RecommendationType {
    case architecture
    case codeQuality
    case testing
    case dependencies
    case performance
    case security
}

public enum Priority {
    case low
    case medium
    case high
    case critical
}

public struct MigrationPlan {
    public let from: ArchitecturePattern
    public let to: ArchitecturePattern
    public let steps: [MigrationStep]
    public let estimatedEffort: MigrationEffort
    public let risks: [String]
    public let benefits: [String]
    
    public init(from: ArchitecturePattern, to: ArchitecturePattern, steps: [MigrationStep], estimatedEffort: MigrationEffort, risks: [String], benefits: [String]) {
        self.from = from
        self.to = to
        self.steps = steps
        self.estimatedEffort = estimatedEffort
        self.risks = risks
        self.benefits = benefits
    }
}

public struct MigrationStep {
    public let title: String
    public let description: String
    
    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }
}

public enum MigrationEffort {
    case none
    case low
    case medium
    case high
}
