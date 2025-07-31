import Foundation
import Logging

/// Swift Documentation Generator
public class DocumentationGenerator {
    private let projectPath: URL
    private let logger: Logger
    private let fileManager = FileManager.default
    
    public init(projectPath: URL, logger: Logger) {
        self.projectPath = projectPath
        self.logger = logger
    }
    
    // MARK: - Public API
    
    public func generateProjectDocumentation() async throws -> DocumentationResult {
        logger.info("📚 Starting documentation generation for project")
        
        let swiftFiles = try findSwiftFiles()
        let projectStructure = try analyzeProjectStructure()
        let apiDocumentation = try await generateAPIDocumentation(from: swiftFiles)
        let readme = generateReadmeContent(structure: projectStructure, apiDocs: apiDocumentation)
        
        // Save generated documentation
        let readmePath = projectPath.appendingPathComponent("README.md")
        try readme.write(to: readmePath, atomically: true, encoding: String.Encoding.utf8)
        
        let result = DocumentationResult(
            readme: readme,
            apiDocumentation: apiDocumentation,
            projectStructure: projectStructure,
            generatedFiles: ["README.md"]
        )
        
        logger.info("✅ Documentation generation completed")
        return result
    }
    
    // MARK: - Private Methods
    
    private func findSwiftFiles() throws -> [URL] {
        var swiftFiles: [URL] = []
        
        let enumerator = fileManager.enumerator(at: projectPath, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "swift" && !file.path.contains(".build") {
                swiftFiles.append(file)
            }
        }
        
        return swiftFiles
    }
    
    private func analyzeProjectStructure() throws -> DocProjectStructure {
        let packageSwift = projectPath.appendingPathComponent("Package.swift")
        let hasPackageSwift = fileManager.fileExists(atPath: packageSwift.path)
        
        // Find Xcode project files
        let contents = try fileManager.contentsOfDirectory(at: projectPath, includingPropertiesForKeys: nil)
        let xcodeProject = contents.first { $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace" }
        
        let swiftFiles = try findSwiftFiles()
        let mainDirectories = try getMainDirectories()
        
        return DocProjectStructure(
            name: projectPath.lastPathComponent,
            type: determineProjectType(hasPackageSwift: hasPackageSwift, xcodeProject: xcodeProject),
            swiftFileCount: swiftFiles.count,
            hasPackageSwift: hasPackageSwift,
            hasXcodeProject: xcodeProject != nil,
            mainDirectories: mainDirectories
        )
    }
    
    private func determineProjectType(hasPackageSwift: Bool, xcodeProject: URL?) -> DocProjectType {
        if hasPackageSwift {
            return .swiftPackage
        } else if xcodeProject != nil {
            return .xcodeProject
        } else {
            return .xcodeProject
        }
    }
    
    private func getMainDirectories() throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(at: projectPath, includingPropertiesForKeys: [.isDirectoryKey])
        let directories = contents.compactMap { url -> String? in
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                let name = url.lastPathComponent
                // Skip hidden and build directories
                if !name.hasPrefix(".") && name != "build" && name != ".build" {
                    return name
                }
            }
            return nil
        }
        return directories.sorted()
    }
    
    private func generateAPIDocumentation(from files: [URL]) async throws -> [APIDocumentationItem] {
        var apiItems: [APIDocumentationItem] = []
        
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Simple parsing for classes, structs, functions
                if let classInfo = parseSimple(line: trimmed, keyword: "class") {
                    apiItems.append(APIDocumentationItem(
                        name: classInfo.name,
                        type: .classType,
                        accessLevel: classInfo.access,
                        filePath: file.path,
                        line: index + 1,
                        documentation: extractDocumentation(from: lines, at: index)
                    ))
                } else if let structInfo = parseSimple(line: trimmed, keyword: "struct") {
                    apiItems.append(APIDocumentationItem(
                        name: structInfo.name,
                        type: .structType,
                        accessLevel: structInfo.access,
                        filePath: file.path,
                        line: index + 1,
                        documentation: extractDocumentation(from: lines, at: index)
                    ))
                } else if let funcInfo = parseSimple(line: trimmed, keyword: "func") {
                    apiItems.append(APIDocumentationItem(
                        name: funcInfo.name,
                        type: .function,
                        accessLevel: funcInfo.access,
                        filePath: file.path,
                        line: index + 1,
                        documentation: extractDocumentation(from: lines, at: index)
                    ))
                }
            }
        }
        
        return apiItems
    }
    
    private func parseSimple(line: String, keyword: String) -> (name: String, access: AccessLevel)? {
        if line.contains("\(keyword) ") {
            let components = line.components(separatedBy: " ")
            if let keywordIndex = components.firstIndex(of: keyword),
               keywordIndex + 1 < components.count {
                let nameWithExtras = components[keywordIndex + 1]
                let name = String(nameWithExtras.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" }))
                let access: AccessLevel = line.contains("public") ? .public : 
                                        line.contains("private") ? .private : .internal
                return (name: name, access: access)
            }
        }
        return nil
    }
    
    private func extractDocumentation(from lines: [String], at index: Int) -> String? {
        // Look for documentation comments above the declaration
        var docLines: [String] = []
        var currentIndex = index - 1
        
        while currentIndex >= 0 {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("///") {
                docLines.insert(String(line.dropFirst(3).trimmingCharacters(in: .whitespaces)), at: 0)
                currentIndex -= 1
            } else if line.isEmpty {
                currentIndex -= 1
            } else {
                break
            }
        }
        
        return docLines.isEmpty ? nil : docLines.joined(separator: "\n")
    }
    
    private func generateReadmeContent(structure: DocProjectStructure, apiDocs: [APIDocumentationItem]) -> String {
        var content = """
# \(structure.name)

A Swift project with \(structure.swiftFileCount) Swift files.

## Project Structure

"""
        
        // Add directories
        for directory in structure.mainDirectories {
            content += "- \(directory)/\n"
        }
        
        content += "\n## API Documentation\n\n"
        
        // Group API items by type
        let classes = apiDocs.filter { $0.type == .classType }
        let structs = apiDocs.filter { $0.type == .structType }
        let functions = apiDocs.filter { $0.type == .function }
        
        if !classes.isEmpty {
            content += "### Classes\n\n"
            for item in classes {
                content += "- **\(item.name)** (\(item.accessLevel.rawValue))\n"
                if let doc = item.documentation {
                    content += "  \(doc)\n"
                }
            }
            content += "\n"
        }
        
        if !structs.isEmpty {
            content += "### Structs\n\n"
            for item in structs {
                content += "- **\(item.name)** (\(item.accessLevel.rawValue))\n"
                if let doc = item.documentation {
                    content += "  \(doc)\n"
                }
            }
            content += "\n"
        }
        
        if !functions.isEmpty {
            content += "### Functions\n\n"
            for item in functions.prefix(10) { // Limit to first 10 functions
                content += "- **\(item.name)** (\(item.accessLevel.rawValue))\n"
                if let doc = item.documentation {
                    content += "  \(doc)\n"
                }
            }
            content += "\n"
        }
        
        // Add installation section for Swift Package
        if structure.type == .swiftPackage {
            content += """

## Installation

Add this package to your `Package.swift`:

```swift
.package(url: "https://github.com/your-username/\(structure.name).git", from: "1.0.0")
```

## Usage

```swift
import \(structure.name)
```

"""
        }
        
        content += "## License\n\nMIT License"
        
        return content
    }
}

// MARK: - Data Structures

public struct DocumentationResult {
    public let readme: String
    public let apiDocumentation: [APIDocumentationItem]
    public let projectStructure: DocProjectStructure
    public let generatedFiles: [String]
}

public struct DocProjectStructure {
    public let name: String
    public let type: DocProjectType
    public let swiftFileCount: Int
    public let hasPackageSwift: Bool
    public let hasXcodeProject: Bool
    public let mainDirectories: [String]
}

public enum DocProjectType {
    case swiftPackage
    case xcodeProject
}

public struct APIDocumentationItem {
    public let name: String
    public let type: APIType
    public let accessLevel: AccessLevel
    public let filePath: String
    public let line: Int
    public let documentation: String?
}

public enum APIType {
    case classType
    case structType
    case protocolType
    case function
    case variable
}

public enum AccessLevel: String {
    case `public` = "public"
    case `internal` = "internal"
    case `private` = "private"
}
