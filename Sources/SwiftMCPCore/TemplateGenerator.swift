import Foundation
import Logging

/// Generic Swift/iOS Template Generator
public class TemplateGenerator {
    private let logger: Logger
    private let projectPath: URL
    private let fileManager = FileManager.default
    
    public init(projectPath: URL, logger: Logger) {
        self.projectPath = projectPath
        self.logger = logger
    }
    
    // MARK: - Public API
    
    public func generateTemplate(_ template: TemplateType, name: String, options: TemplateOptions = TemplateOptions()) async throws -> TemplateResult {
        logger.info("🛠️ Generating \(template.displayName) template: \(name)")
        
        let files = try generateTemplateFiles(template, name: name, options: options)
        
        for file in files {
            let fileURL = projectPath.appendingPathComponent(file.path)
            try createDirectoryIfNeeded(for: fileURL)
            try file.content.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.debug("📝 Created file: \(file.path)")
        }
        
        let result = TemplateResult(
            templateType: template,
            generatedFiles: files.map { $0.path },
            instructions: generateInstructions(for: template, name: name)
        )
        
        logger.info("✅ Template generation completed")
        return result
    }
    
    public func listAvailableTemplates() -> [TemplateType] {
        return TemplateType.allCases
    }
    
    // MARK: - Template File Generation
    
    private func generateTemplateFiles(_ template: TemplateType, name: String, options: TemplateOptions) throws -> [TemplateFile] {
        switch template {
        case .swiftPackage:
            return try generateSwiftPackageTemplate(name: name, options: options)
        case .uiKitViewController:
            return try generateUIKitViewControllerTemplate(name: name, options: options)
        case .swiftUIView:
            return try generateSwiftUIViewTemplate(name: name, options: options)
        case .mvvmModule:
            return try generateMVVMModuleTemplate(name: name, options: options)
        case .coordinatorPattern:
            return try generateCoordinatorTemplate(name: name, options: options)
        case .networkService:
            return try generateNetworkServiceTemplate(name: name, options: options)
        case .coreDataModel:
            return try generateCoreDataModelTemplate(name: name, options: options)
        case .unitTestSuite:
            return try generateUnitTestTemplate(name: name, options: options)
        }
    }
    
    // MARK: - Swift Package Template
    
    private func generateSwiftPackageTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let packageSwift = """
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "\(name)",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "\(name)",
            targets: ["\(name)"]
        ),
    ],
    dependencies: [
        // Add your dependencies here
    ],
    targets: [
        .target(
            name: "\(name)",
            dependencies: []
        ),
        .testTarget(
            name: "\(name)Tests",
            dependencies: ["\(name)"]
        ),
    ]
)
"""
        
        let mainSwift = """
/// \(name) - Main library interface
public struct \(name) {
    public init() {}
    
    /// Example public method
    public func hello() -> String {
        return "Hello from \(name)!"
    }
}
"""
        
        let testSwift = """
import XCTest
@testable import \(name)

final class \(name)Tests: XCTestCase {
    
    func testHelloMethod() {
        let library = \(name)()
        XCTAssertEqual(library.hello(), "Hello from \(name)!")
    }
}
"""
        
        let readme = """
# \(name)

\(options.description ?? "A Swift package")

## Installation

Add this package to your `Package.swift`:

```swift
.package(url: "https://github.com/your-username/\(name).git", from: "1.0.0")
```

## Usage

```swift
import \(name)

let library = \(name)()
print(library.hello())
```

## License

MIT License
"""
        
        return [
            TemplateFile(path: "Package.swift", content: packageSwift),
            TemplateFile(path: "Sources/\(name)/\(name).swift", content: mainSwift),
            TemplateFile(path: "Tests/\(name)Tests/\(name)Tests.swift", content: testSwift),
            TemplateFile(path: "README.md", content: readme)
        ]
    }
    
    // MARK: - UIKit ViewController Template
    
    private func generateUIKitViewControllerTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let viewController = """
import UIKit

/// \(name) - UIKit View Controller
class \(name)ViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "\(name)"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(titleLabel)
        
        navigationItem.title = "\(name)"
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
"""
        
        return [
            TemplateFile(path: "\(name)ViewController.swift", content: viewController)
        ]
    }
    
    // MARK: - SwiftUI View Template
    
    private func generateSwiftUIViewTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let swiftUIView = """
import SwiftUI

/// \(name) - SwiftUI View
struct \(name)View: View {
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\(name)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Welcome to \(name)")
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("\(name)")
    }
}

#Preview {
    NavigationView {
        \(name)View()
    }
}
"""
        
        return [
            TemplateFile(path: "\(name)View.swift", content: swiftUIView)
        ]
    }
    
    // MARK: - MVVM Module Template
    
    private func generateMVVMModuleTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let model = """
import Foundation

/// \(name) - Data Model
struct \(name)Model {
    let id: UUID
    let title: String
    let description: String
    
    init(title: String, description: String) {
        self.id = UUID()
        self.title = title
        self.description = description
    }
}
"""
        
        let viewModel = """
import Foundation
import Combine

/// \(name) - View Model
class \(name)ViewModel: ObservableObject {
    
    @Published var items: [\(name)Model] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadData()
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        // Simulate async data loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.items = [
                \(name)Model(title: "Sample Item 1", description: "Description 1"),
                \(name)Model(title: "Sample Item 2", description: "Description 2")
            ]
            self.isLoading = false
        }
    }
    
    func addItem(title: String, description: String) {
        let newItem = \(name)Model(title: title, description: description)
        items.append(newItem)
    }
}
"""
        
        let view = """
import SwiftUI

/// \(name) - SwiftUI View
struct \(name)View: View {
    
    @StateObject private var viewModel = \(name)ViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.items, id: \\.id) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("\(name)")
            .refreshable {
                viewModel.loadData()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                }
            }
        }
    }
}

#Preview {
    \(name)View()
}
"""
        
        return [
            TemplateFile(path: "\(name)/Model/\(name)Model.swift", content: model),
            TemplateFile(path: "\(name)/ViewModel/\(name)ViewModel.swift", content: viewModel),
            TemplateFile(path: "\(name)/View/\(name)View.swift", content: view)
        ]
    }
    
    // MARK: - Additional Templates
    
    private func generateCoordinatorTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let coordinator = """
import UIKit

/// \(name) - Coordinator Pattern Implementation
protocol \(name)CoordinatorProtocol: AnyObject {
    func start()
    func showDetail(_ item: String)
}

class \(name)Coordinator: \(name)CoordinatorProtocol {
    
    private let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let viewController = \(name)ViewController()
        viewController.coordinator = self
        navigationController.pushViewController(viewController, animated: true)
    }
    
    func showDetail(_ item: String) {
        // Navigate to detail view
        let detailVC = UIViewController()
        detailVC.title = "Detail: \\(item)"
        navigationController.pushViewController(detailVC, animated: true)
    }
}
"""
        
        return [
            TemplateFile(path: "\(name)Coordinator.swift", content: coordinator)
        ]
    }
    
    private func generateNetworkServiceTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let networkService = """
import Foundation
import Combine

/// \(name) - Network Service
protocol \(name)ServiceProtocol {
    func fetchData() async throws -> [\(name)Model]
}

class \(name)Service: \(name)ServiceProtocol {
    
    private let session: URLSession
    private let baseURL: URL
    
    init(session: URLSession = .shared, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }
    
    func fetchData() async throws -> [\(name)Model] {
        let url = baseURL.appendingPathComponent("data")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([\(name)Model].self, from: data)
    }
}
"""
        
        return [
            TemplateFile(path: "\(name)Service.swift", content: networkService)
        ]
    }
    
    private func generateCoreDataModelTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let coreDataManager = """
import CoreData
import Foundation

/// \(name) - Core Data Manager
class \(name)CoreDataManager {
    
    static let shared = \(name)CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "\(name)DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \\(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        if context.hasChanges {
            try? context.save()
        }
    }
}
"""
        
        return [
            TemplateFile(path: "\(name)CoreDataManager.swift", content: coreDataManager)
        ]
    }
    
    private func generateUnitTestTemplate(name: String, options: TemplateOptions) throws -> [TemplateFile] {
        let testSuite = """
import XCTest
@testable import YourModule

/// \(name) - Unit Test Suite
class \(name)Tests: XCTestCase {
    
    var sut: \(name)ViewModel!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = \(name)ViewModel()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    func testInitialState() {
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoadData() {
        // Given
        let expectation = XCTestExpectation(description: "Data loaded")
        
        // When
        sut.loadData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(sut.items.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }
}
"""
        
        return [
            TemplateFile(path: "\(name)Tests.swift", content: testSuite)
        ]
    }
    
    // MARK: - Helper Methods
    
    private func createDirectoryIfNeeded(for fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    private func generateInstructions(for template: TemplateType, name: String) -> [String] {
        switch template {
        case .swiftPackage:
            return [
                "Swift Package created successfully!",
                "Run 'swift build' to build the package",
                "Run 'swift test' to run tests",
                "Update Package.swift to add dependencies"
            ]
        case .uiKitViewController:
            return [
                "UIKit ViewController created",
                "Add to your storyboard or present programmatically",
                "Customize the UI components as needed"
            ]
        case .swiftUIView:
            return [
                "SwiftUI View created",
                "Add to your app's navigation hierarchy",
                "Customize the layout and styling"
            ]
        case .mvvmModule:
            return [
                "MVVM Module created with Model, ViewModel, and View",
                "The ViewModel uses ObservableObject and @Published properties",
                "Customize the data model and business logic"
            ]
        case .coordinatorPattern:
            return [
                "Coordinator pattern implementation created",
                "Integrate with your view controllers",
                "Handle navigation logic in the coordinator"
            ]
        case .networkService:
            return [
                "Network service created with async/await",
                "Update the base URL and endpoints",
                "Add error handling and authentication as needed"
            ]
        case .coreDataModel:
            return [
                "Core Data manager created",
                "Create a .xcdatamodeld file for your data model",
                "Use the manager to save and fetch data"
            ]
        case .unitTestSuite:
            return [
                "Unit test suite created",
                "Add more test cases for your specific functionality",
                "Run tests with Cmd+U in Xcode"
            ]
        }
    }
}

// MARK: - Data Structures

public enum TemplateType: String, CaseIterable {
    case swiftPackage = "swift-package"
    case uiKitViewController = "uikit-viewcontroller"
    case swiftUIView = "swiftui-view"
    case mvvmModule = "mvvm-module"
    case coordinatorPattern = "coordinator"
    case networkService = "network-service"
    case coreDataModel = "coredata-model"
    case unitTestSuite = "unit-tests"
    
    var displayName: String {
        switch self {
        case .swiftPackage: return "Swift Package"
        case .uiKitViewController: return "UIKit ViewController"
        case .swiftUIView: return "SwiftUI View"
        case .mvvmModule: return "MVVM Module"
        case .coordinatorPattern: return "Coordinator Pattern"
        case .networkService: return "Network Service"
        case .coreDataModel: return "Core Data Model"
        case .unitTestSuite: return "Unit Test Suite"
        }
    }
}

public struct TemplateOptions {
    public let description: String?
    public let author: String?
    public let includeTests: Bool
    
    public init(description: String? = nil, author: String? = nil, includeTests: Bool = true) {
        self.description = description
        self.author = author
        self.includeTests = includeTests
    }
}

public struct TemplateFile {
    public let path: String
    public let content: String
}

public struct TemplateResult {
    public let templateType: TemplateType
    public let generatedFiles: [String]
    public let instructions: [String]
}
