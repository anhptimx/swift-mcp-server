import Foundation
import Logging

/// iOS Framework Analysis Tool
public class iOSFrameworkAnalysisEngine {
    private let logger: Logger
    private let projectPath: URL
    private let fileManager = FileManager.default
    
    public init(projectPath: URL, logger: Logger) {
        self.projectPath = projectPath
        self.logger = logger
    }
    
    // MARK: - Public API
    
    public func analyzeIOSPatterns() async throws -> iOSAnalysisResult {
        logger.info("📱 Starting iOS pattern analysis")
        
        let swiftFiles = try findSwiftFiles()
        let frameworkUsage = try await analyzeFrameworkUsage(in: swiftFiles)
        let uiPatterns = try await analyzeUIPatterns(in: swiftFiles)
        let architecturePatterns = try await analyzeArchitecturePatterns(in: swiftFiles)
        let modernFeatures = try await analyzeModernFeatures(in: swiftFiles)
        
        let result = iOSAnalysisResult(
            frameworkUsage: frameworkUsage,
            uiPatterns: uiPatterns,
            architecturePatterns: architecturePatterns,
            modernFeatures: modernFeatures,
            recommendations: generateRecommendations(
                framework: frameworkUsage,
                ui: uiPatterns,
                architecture: architecturePatterns,
                modern: modernFeatures
            )
        )
        
        logger.info("✅ iOS pattern analysis completed")
        return result
    }
    
    // MARK: - Apple Framework Detection
    
    /// Official Apple frameworks and APIs
    private let appleFrameworks: Set<String> = [
        // UI Frameworks
        "UIKit", "SwiftUI", "AppKit", "WatchKit", "CarPlay",
        
        // Foundation & Core
        "Foundation", "CoreFoundation", "CoreData", "CoreGraphics",
        "CoreAnimation", "CoreImage", "CoreText", "CoreVideo", "CoreAudio",
        
        // Networking & Web (Official Apple only)
        "Network", "NetworkExtension", "WebKit", "CFNetwork", "URLSession",
        
        // Media & Graphics
        "AVFoundation", "AVKit", "Photos", "PhotosUI", "ImageIO", "VideoToolbox",
        "Metal", "MetalKit", "SceneKit", "SpriteKit", "RealityKit", "ARKit",
        
        // System & Security
        "Security", "CryptoKit", "LocalAuthentication", "AuthenticationServices",
        "DeviceCheck", "SystemConfiguration", "OSLog", "os",
        
        // Location & Maps
        "CoreLocation", "MapKit", "Contacts", "ContactsUI",
        
        // Data & Storage
        "CloudKit", "CoreSpotlight", "CoreServices", "UniformTypeIdentifiers",
        "SwiftData", "Combine",
        
        // Communication
        "MessageUI", "Social", "EventKit", "EventKitUI", "CallKit",
        
        // Hardware & Sensors
        "CoreMotion", "CoreBluetooth", "ExternalAccessory", "HomeKit",
        "HealthKit", "ResearchKit", "CareKit",
        
        // App Services
        "StoreKit", "GameKit", "MultipeerConnectivity", "PassKit",
        "NotificationCenter", "UserNotifications", "BackgroundTasks",
        
        // Developer Tools
        "XCTest", "QuickLook", "SafariServices", "MobileCoreServices"
    ]
    
    /// Check if a framework is an official Apple framework
    private func isAppleFramework(_ framework: String) -> Bool {
        return appleFrameworks.contains(framework)
    }
    
    // MARK: - Framework Usage Analysis
    
    private func analyzeFrameworkUsage(in files: [URL]) async throws -> FrameworkUsage {
        var imports: [String: Int] = [:]
        var totalLines = 0
        
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            totalLines += lines.count
            
            for line in lines {
                if let framework = extractImport(from: line) {
                    imports[framework, default: 0] += 1
                }
            }
        }
        
        // Separate Apple frameworks from third-party libraries
        let coreFrameworks = ["UIKit", "SwiftUI", "Foundation", "Combine", "CoreData", "URLSession", "Network", "CFNetwork"]
        let appleFrameworksOnly = imports.filter { item in
            !coreFrameworks.contains(item.key) && isAppleFramework(item.key)
        }
        let thirdPartyLibraries = imports.filter { item in
            !coreFrameworks.contains(item.key) && !isAppleFramework(item.key)
        }
        
        // Combine Apple frameworks in "other", log third-party separately
        if !thirdPartyLibraries.isEmpty {
            logger.info("🔍 Third-party libraries detected: \(thirdPartyLibraries.keys.sorted().joined(separator: ", "))")
        }
        
        return FrameworkUsage(
            uiKit: imports["UIKit"] ?? 0,
            swiftUI: imports["SwiftUI"] ?? 0,
            foundation: imports["Foundation"] ?? 0,
            combine: imports["Combine"] ?? 0,
            coreData: imports["CoreData"] ?? 0,
            networking: (imports["URLSession"] ?? 0) + (imports["Network"] ?? 0) + (imports["CFNetwork"] ?? 0),
            other: appleFrameworksOnly, // Only Apple frameworks in "other"
            dominantFramework: determineDominantFramework(imports.filter { isAppleFramework($0.key) }) // Only consider Apple frameworks
        )
    }
    
    private func extractImport(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("import ") {
            let framework = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            return framework
        }
        return nil
    }
    
    private func determineDominantFramework(_ imports: [String: Int]) -> String {
        let relevantImports = imports.filter { ["UIKit", "SwiftUI"].contains($0.key) }
        guard let dominant = relevantImports.max(by: { $0.value < $1.value }) else {
            return "Foundation"
        }
        return dominant.key
    }
    
    // MARK: - UI Pattern Analysis
    
    private func analyzeUIPatterns(in files: [URL]) async throws -> UIPatterns {
        var viewControllers = 0
        var swiftUIViews = 0
        var storyboardUsage = 0
        var autolayoutUsage = 0
        var delegatePatterns = 0
        
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            
            viewControllers += countPattern(pattern: "UIViewController", in: content)
            swiftUIViews += countPattern(pattern: "View\\s*{", in: content, isRegex: true)
            storyboardUsage += countPattern(pattern: "storyboard", in: content)
            autolayoutUsage += countPattern(pattern: "constraint|NSLayoutConstraint", in: content, isRegex: true)
            delegatePatterns += countPattern(pattern: "delegate", in: content)
        }
        
        return UIPatterns(
            viewControllers: viewControllers,
            swiftUIViews: swiftUIViews,
            storyboardUsage: storyboardUsage,
            autolayoutUsage: autolayoutUsage,
            delegatePatterns: delegatePatterns,
            primaryUIFramework: swiftUIViews > viewControllers ? "SwiftUI" : "UIKit"
        )
    }
    
    // MARK: - Architecture Pattern Analysis
    
    private func analyzeArchitecturePatterns(in files: [URL]) async throws -> ArchitecturePatterns {
        var mvvmScore = 0
        var mvpScore = 0
        var viperScore = 0
        var coordinatorScore = 0
        
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            
            // MVVM Detection
            mvvmScore += countPattern(pattern: "ViewModel|ObservableObject", in: content, isRegex: true)
            
            // MVP Detection  
            mvpScore += countPattern(pattern: "Presenter", in: content)
            
            // VIPER Detection
            viperScore += countPattern(pattern: "Interactor|Router|Entity", in: content, isRegex: true)
            
            // Coordinator Detection
            coordinatorScore += countPattern(pattern: "Coordinator", in: content)
        }
        
        return ArchitecturePatterns(
            mvvmScore: mvvmScore,
            mvpScore: mvpScore,
            viperScore: viperScore,
            coordinatorScore: coordinatorScore,
            dominantPattern: determineDominantArchitecture(
                mvvm: mvvmScore,
                mvp: mvpScore,
                viper: viperScore,
                coordinator: coordinatorScore
            )
        )
    }
    
    private func determineDominantArchitecture(mvvm: Int, mvp: Int, viper: Int, coordinator: Int) -> String {
        let scores = [
            ("MVVM", mvvm),
            ("MVP", mvp),
            ("VIPER", viper),
            ("Coordinator", coordinator)
        ]
        
        guard let dominant = scores.max(by: { $0.1 < $1.1 }), dominant.1 > 0 else {
            return "MVC (Default)"
        }
        
        return dominant.0
    }
    
    // MARK: - Modern Features Analysis
    
    private func analyzeModernFeatures(in files: [URL]) async throws -> ModernFeatures {
        var asyncAwaitUsage = 0
        var actorUsage = 0
        var combineUsage = 0
        var swiftUIModifiers = 0
        var propertyWrappers = 0
        
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            
            asyncAwaitUsage += countPattern(pattern: "async|await", in: content, isRegex: true)
            actorUsage += countPattern(pattern: "actor\\s+", in: content, isRegex: true)
            combineUsage += countPattern(pattern: "@Published|Publisher|PassthroughSubject", in: content, isRegex: true)
            swiftUIModifiers += countPattern(pattern: "\\.onAppear|\\.onDisappear|\\.onChange", in: content, isRegex: true)
            propertyWrappers += countPattern(pattern: "@State|@Binding|@ObservedObject|@EnvironmentObject", in: content, isRegex: true)
        }
        
        return ModernFeatures(
            asyncAwaitUsage: asyncAwaitUsage,
            actorUsage: actorUsage,
            combineUsage: combineUsage,
            swiftUIModifiers: swiftUIModifiers,
            propertyWrappers: propertyWrappers,
            modernityScore: calculateModernityScore(
                async: asyncAwaitUsage,
                actor: actorUsage,
                combine: combineUsage,
                swiftUI: swiftUIModifiers,
                wrappers: propertyWrappers
            )
        )
    }
    
    private func calculateModernityScore(async: Int, actor: Int, combine: Int, swiftUI: Int, wrappers: Int) -> Double {
        let total = async + actor + combine + swiftUI + wrappers
        let maxPossible = 100 // Arbitrary baseline
        return min(100.0, Double(total) / Double(maxPossible) * 100)
    }
    
    // MARK: - Helper Methods
    
    private func findSwiftFiles() throws -> [URL] {
        let enumerator = fileManager.enumerator(
            at: projectPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        var swiftFiles: [URL] = []
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "swift" &&
               !fileURL.path.contains(".build") {
                swiftFiles.append(fileURL)
            }
        }
        
        return swiftFiles
    }
    
    private func countPattern(pattern: String, in content: String, isRegex: Bool = false) -> Int {
        if isRegex {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(content.startIndex..., in: content)
                return regex.numberOfMatches(in: content, range: range)
            } catch {
                logger.error("❌ Invalid regex pattern: \(pattern)")
                return 0
            }
        } else {
            return content.lowercased().components(separatedBy: pattern.lowercased()).count - 1
        }
    }
    
    // MARK: - Recommendations
    
    private func generateRecommendations(
        framework: FrameworkUsage,
        ui: UIPatterns,
        architecture: ArchitecturePatterns,
        modern: ModernFeatures
    ) -> [String] {
        var recommendations: [String] = []
        
        // Framework recommendations
        if framework.swiftUI > 0 && framework.uiKit > framework.swiftUI {
            recommendations.append("Consider migrating more components to SwiftUI for modern iOS development")
        }
        
        if framework.combine == 0 && framework.swiftUI > 0 {
            recommendations.append("Consider using Combine for reactive programming with SwiftUI")
        }
        
        // Architecture recommendations
        if architecture.dominantPattern == "MVC (Default)" && (framework.swiftUI > 0 || ui.viewControllers > 5) {
            recommendations.append("Consider implementing MVVM pattern for better separation of concerns")
        }
        
        if architecture.coordinatorScore == 0 && ui.viewControllers > 3 {
            recommendations.append("Consider implementing Coordinator pattern for navigation management")
        }
        
        // Modern features recommendations
        if modern.asyncAwaitUsage == 0 {
            recommendations.append("Consider adopting async/await for cleaner asynchronous code")
        }
        
        if modern.modernityScore < 30 {
            recommendations.append("Project could benefit from adopting more modern Swift features")
        }
        
        if ui.storyboardUsage > ui.swiftUIViews && framework.swiftUI > 0 {
            recommendations.append("Consider reducing storyboard usage in favor of SwiftUI")
        }
        
        return recommendations
    }
}

// MARK: - Data Structures

public struct iOSAnalysisResult {
    public let frameworkUsage: FrameworkUsage
    public let uiPatterns: UIPatterns
    public let architecturePatterns: ArchitecturePatterns
    public let modernFeatures: ModernFeatures
    public let recommendations: [String]
}

public struct FrameworkUsage {
    public let uiKit: Int
    public let swiftUI: Int
    public let foundation: Int
    public let combine: Int
    public let coreData: Int
    public let networking: Int
    public let other: [String: Int]
    public let dominantFramework: String
}

public struct UIPatterns {
    public let viewControllers: Int
    public let swiftUIViews: Int
    public let storyboardUsage: Int
    public let autolayoutUsage: Int
    public let delegatePatterns: Int
    public let primaryUIFramework: String
}

public struct ArchitecturePatterns {
    public let mvvmScore: Int
    public let mvpScore: Int
    public let viperScore: Int
    public let coordinatorScore: Int
    public let dominantPattern: String
}

public struct ModernFeatures {
    public let asyncAwaitUsage: Int
    public let actorUsage: Int
    public let combineUsage: Int
    public let swiftUIModifiers: Int
    public let propertyWrappers: Int
    public let modernityScore: Double
}
