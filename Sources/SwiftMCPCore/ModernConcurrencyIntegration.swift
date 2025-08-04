import Foundation
import Logging
import NIO
import ModernConcurrency

/// Modern Concurrency Integration for Swift MCP Server
/// Provides enhanced async operations, thread safety, and task management
public final class ModernConcurrencyIntegration: @unchecked Sendable {
    
    // MARK: - Core Components
    
    /// Task manager for coordinated async operations
    private let taskManager: FCITaskManager
    
    /// Thread-safe storage for shared state
    private let threadSafeStorage: FCIModernThreadSafety
    
    /// Continuation manager for complex async flows
    private let continuationManager: FCIModernContinuationManager
    
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init(logger: Logger) {
        self.logger = logger
        
        // Configure task manager with MCP-specific settings
        self.taskManager = FCITaskManager(
            maxConcurrentTasks: 10,  // Allow more concurrent Swift analysis tasks
            resourceLimits: ResourceLimits(
                maxMemoryMB: 200,    // Reasonable memory limit for Swift analysis
                maxCPUPercentage: 70.0,  // Don't overwhelm the system
                maxNetworkOperations: 5  // Limit concurrent file operations
            )
        )
        
        // Initialize thread-safe storage for project state
        self.threadSafeStorage = FCIModernThreadSafety()
        
        // Initialize continuation manager for complex async workflows
        self.continuationManager = FCIModernContinuationManager()
        
        logger.info("🚀 Modern Concurrency Integration initialized")
    }
    
    // MARK: - Task Management
    
    /// Execute a Swift analysis task with proper resource management
    public func executeAnalysisTask<T: Sendable>(
        id: String,
        priority: TaskPriority = .medium,
        timeout: TimeInterval? = 30.0,  // 30 second default timeout
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        
        logger.debug("🔄 Starting analysis task: \(id)")
        
        // Use a simple retry policy to avoid type annotation issues
        let retryPolicy = ModernConcurrency.RetryPolicy()
        
        do {
            let result = try await taskManager.execute(
                id: id,
                priority: priority,
                timeout: timeout,
                retryPolicy: retryPolicy,
                operation: operation
            )
            
            logger.debug("✅ Analysis task completed: \(id)")
            return result
            
        } catch {
            logger.error("❌ Analysis task failed: \(id) - \(error)")
            throw error
        }
    }
    
    /// Execute multiple analysis tasks in parallel with controlled concurrency
    public func executeParallelAnalysis<T: Sendable>(
        tasks: [(id: String, operation: @Sendable () async throws -> T)],
        maxConcurrency: Int = 3
    ) async throws -> [String: Result<T, Error>] {
        
        logger.info("🔄 Starting parallel analysis of \(tasks.count) tasks")
        
        let results = try await taskManager.executeParallelTasks(
            tasks: tasks,
            maxConcurrency: maxConcurrency
        )
        
        let successCount = results.values.compactMap { 
            if case .success = $0 { return true } else { return nil }
        }.count
        
        logger.info("✅ Parallel analysis completed: \(successCount)/\(tasks.count) successful")
        
        return results
    }
    
    // MARK: - Thread-Safe State Management
    
    /// Store project analysis results safely
    public func storeAnalysisResult<T: Sendable & Codable>(
        key: String,
        value: T,
        expirationTime: TimeInterval? = 3600  // 1 hour default
    ) async {
        await threadSafeStorage.setValue(value, forKey: key)
        logger.debug("💾 Stored analysis result: \(key)")
    }
    
    /// Retrieve cached analysis results safely
    public func getAnalysisResult<T: Sendable & Codable>(
        key: String,
        type: T.Type
    ) async -> T? {
        let result = await threadSafeStorage.getValue(forKey: key, as: type)
        
        if result != nil {
            logger.debug("🎯 Retrieved cached result: \(key)")
        } else {
            logger.debug("❌ No cached result found: \(key)")
        }
        
        return result
    }
    
    /// Add observer for analysis state changes
    public func observeAnalysisChanges(
        for key: String,
        observer: @escaping @Sendable (Any?, Any?) async -> Void
    ) async {
        let _ = await threadSafeStorage.addObserver(forKey: key, handler: observer)
        logger.debug("👁️ Added observer for: \(key)")
    }
    
    // MARK: - Advanced Async Flows
    
    /// Execute a complex analysis workflow using continuation management
    public func executeWorkflow<T: Sendable>(
        workflowId: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        
        logger.info("🔄 Starting workflow: \(workflowId)")
        
        do {
            let result = try await operation()
            logger.info("✅ Workflow completed: \(workflowId)")
            return result
        } catch {
            logger.error("❌ Workflow failed: \(workflowId) - \(error)")
            throw error
        }
    }
    
    /// Execute a batch of Swift file analyses with intelligent batching
    public func batchAnalyzeSwiftFiles(
        files: [URL],
        analysisType: String,
        operation: @escaping @Sendable (URL) async throws -> Any
    ) async throws -> [String: Result<Any, Error>] {
        
        let batchId = "batch_\(analysisType)_\(UUID().uuidString.prefix(8))"
        logger.info("🔄 Starting batch analysis: \(batchId) - \(files.count) files")
        
        // Create tasks for each file
        let tasks = files.enumerated().map { (index, file) in
            let capturedFile = file // Capture to make it sendable
            return (
                id: "\(batchId)_file_\(index)",
                operation: { @Sendable in try await operation(capturedFile) }
            )
        }
        
        // Execute with controlled concurrency to avoid overwhelming the system
        let results = try await executeParallelAnalysis(
            tasks: tasks,
            maxConcurrency: min(3, files.count)  // Max 3 concurrent file analyses
        )
        
        logger.info("✅ Batch analysis completed: \(batchId)")
        return results
    }
    
    // MARK: - Resource Management
    
    /// Get current system resource usage
    public func getResourceUsage() async -> ResourceUsage {
        return await taskManager.currentUsage
    }
    
    /// Get active task count
    public func getActiveTaskCount() async -> Int {
        return await taskManager.activeTaskCount
    }
    
    /// Cancel all running tasks (emergency stop)
    public func cancelAllTasks() async {
        await taskManager.cancelAll()
        logger.warning("⚠️ All tasks cancelled")
    }
    
    /// Cancel specific task
    public func cancelTask(id: String) async {
        await taskManager.cancel(taskId: id)
        logger.debug("❌ Task cancelled: \(id)")
    }
    
    // MARK: - Cleanup
    
    /// Cleanup resources and save state
    public func shutdown() async {
        logger.info("🔄 Shutting down modern concurrency integration...")
        
        // Cancel all running tasks
        await cancelAllTasks()
        
        // Clear any cached state
        await threadSafeStorage.clear()
        
        logger.info("✅ Modern concurrency integration shutdown complete")
    }
}

// MARK: - Error Extensions

extension TaskError {
    static let resourceUnavailable = TaskError.custom("Resource unavailable")
    static let unknown = TaskError.custom("Unknown error")
    static let timeout = TaskError.custom("Operation timed out")
    static let noResult = TaskError.custom("No result available")
}

// MARK: - Convenience Extensions

extension ModernConcurrencyIntegration {
    
    /// Quick helper for simple Swift analysis tasks
    public func quickAnalysis<T: Sendable>(
        taskName: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await executeAnalysisTask(
            id: "quick_\(taskName)_\(UUID().uuidString.prefix(8))",
            priority: .medium,
            timeout: 15.0,
            operation: operation
        )
    }
    
    /// Helper for caching analysis results with automatic key generation
    public func cacheResult<T: Sendable & Codable>(
        _ result: T,
        for filePath: String,
        analysisType: String
    ) async {
        let key = "analysis_\(analysisType)_\(filePath.hashValue)"
        await storeAnalysisResult(
            key: key,
            value: result,
            expirationTime: 1800  // 30 minutes
        )
    }
    
    /// Helper for retrieving cached analysis results
    public func getCachedResult<T: Sendable & Codable>(
        for filePath: String,
        analysisType: String,
        type: T.Type
    ) async -> T? {
        let key = "analysis_\(analysisType)_\(filePath.hashValue)"
        return await getAnalysisResult(key: key, type: type)
    }
}
