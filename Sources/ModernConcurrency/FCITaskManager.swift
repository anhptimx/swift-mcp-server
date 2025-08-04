import Foundation
import Logging

// MARK: - Task Error Types

public enum TaskError: Error, Sendable, Hashable {
    case timeout
    case resourceUnavailable
    case cancelled
    case unknown
    case noResult
    case custom(String)
    
    public static func == (lhs: TaskError, rhs: TaskError) -> Bool {
        switch (lhs, rhs) {
        case (.timeout, .timeout),
             (.resourceUnavailable, .resourceUnavailable),
             (.cancelled, .cancelled),
             (.unknown, .unknown),
             (.noResult, .noResult):
            return true
        case (.custom(let lhsMessage), .custom(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .timeout:
            hasher.combine(0)
        case .resourceUnavailable:
            hasher.combine(1)
        case .cancelled:
            hasher.combine(2)
        case .unknown:
            hasher.combine(3)
        case .noResult:
            hasher.combine(4)
        case .custom(let message):
            hasher.combine(5)
            hasher.combine(message)
        }
    }
}

// MARK: - Protocols

public protocol TaskExecutor: Actor {
    func execute<T: Sendable>(
        id: String,
        priority: TaskPriority,
        timeout: TimeInterval?,
        retryPolicy: RetryPolicy?,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T

    func cancel(taskId: String) async
    func cancelAll() async
    var activeTaskCount: Int { get async }
}

public protocol ResourceManager: Actor {
    func requestResources(_ resources: ResourceRequirement) async throws
    func releaseResources(_ resources: ResourceRequirement) async
    var currentUsage: ResourceUsage { get async }
}

// MARK: - Resource Management

public struct ResourceRequirement: Sendable {
    public let memory: Int  // MB
    public let cpu: Double  // Percentage
    public let network: Int  // Concurrent operations
    public let priority: TaskPriority

    public init(
        memory: Int = 0,
        cpu: Double = 0,
        network: Int = 0,
        priority: TaskPriority = .medium
    ) {
        self.memory = memory
        self.cpu = cpu
        self.network = network
        self.priority = priority
    }
}

public struct ResourceUsage: Sendable {
    public var memoryMB: Int = 0
    public var cpuPercentage: Double = 0.0
    public var networkOperations: Int = 0

    mutating func add(_ requirement: ResourceRequirement) {
        memoryMB += requirement.memory
        cpuPercentage += requirement.cpu
        networkOperations += requirement.network
    }

    mutating func subtract(_ requirement: ResourceRequirement) {
        memoryMB = max(0, memoryMB - requirement.memory)
        cpuPercentage = max(0, cpuPercentage - requirement.cpu)
        networkOperations = max(0, networkOperations - requirement.network)
    }
}

public struct ResourceLimits: Sendable {
    public let maxMemoryMB: Int
    public let maxCPUPercentage: Double
    public let maxNetworkOperations: Int

    public init(
        maxMemoryMB: Int = 100,
        maxCPUPercentage: Double = 80.0,
        maxNetworkOperations: Int = 10
    ) {
        self.maxMemoryMB = maxMemoryMB
        self.maxCPUPercentage = maxCPUPercentage
        self.maxNetworkOperations = maxNetworkOperations
    }

    func canAccommodate(_ requirement: ResourceRequirement, currentUsage: ResourceUsage) -> Bool {
        return (currentUsage.memoryMB + requirement.memory) <= maxMemoryMB
            && (currentUsage.cpuPercentage + requirement.cpu) <= maxCPUPercentage
            && (currentUsage.networkOperations + requirement.network) <= maxNetworkOperations
    }
}

// MARK: - Retry Policy

public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    public let retryableErrors: Set<TaskError>

    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0,
        retryableErrors: Set<TaskError> = [.timeout, .resourceUnavailable]
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.retryableErrors = retryableErrors
    }

    func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(multiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }

    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }

        if let taskError = error as? TaskError {
            return retryableErrors.contains(taskError)
        }

        return false
    }
}

// MARK: - Task Manager

public actor FCITaskManager: TaskExecutor, ResourceManager {

    // MARK: - Properties

    private var activeTasks: [String: TaskHandle] = [:]
    private let maxConcurrentTasks: Int
    private let resourceLimits: ResourceLimits
    private var resourceUsage = ResourceUsage()
    private let taskQueue = TaskQueue()

    // MARK: - Initialization

    public init(
        maxConcurrentTasks: Int = 5,
        resourceLimits: ResourceLimits = ResourceLimits()
    ) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.resourceLimits = resourceLimits
    }

    // MARK: - Task Execution

    @discardableResult
    public func execute<T: Sendable>(
        id: String = UUID().uuidString,
        priority: TaskPriority = .medium,
        timeout: TimeInterval? = nil,
        retryPolicy: RetryPolicy? = nil,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Create task item
        let taskItem = TaskItem(
            id: id,
            priority: priority,
            timeout: timeout,
            retryPolicy: retryPolicy,
            operation: operation
        )

        // Add to queue if needed
        if activeTasks.count >= maxConcurrentTasks {
            return try await taskQueue.enqueue(taskItem)
        }

        return try await executeTaskItem(taskItem)
    }

    private func executeTaskItem<T: Sendable>(_ item: TaskItem<T>) async throws -> T {
        let handle = TaskHandle(id: item.id)
        activeTasks[item.id] = handle

        defer {
            Task { [weak self] in
                await self?.taskCompleted(id: item.id)
            }
        }

        // Execute with retry
        var lastError: Error?
        let retryPolicy = item.retryPolicy ?? RetryPolicy(maxAttempts: 1)

        for attempt in 1...retryPolicy.maxAttempts {
            do {
                if let timeout = item.timeout {
                    return try await withTimeout(timeout) {
                        try await item.operation()
                    }
                } else {
                    return try await item.operation()
                }
            } catch {
                lastError = error

                if retryPolicy.shouldRetry(error: error, attempt: attempt) {
                    let delay = retryPolicy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    throw error
                }
            }
        }

        throw lastError ?? TaskError.unknown
    }

    // MARK: - Parallel Execution

    public func executeParallelTasks<T: Sendable>(
        tasks: [(id: String, operation: @Sendable () async throws -> T)],
        maxConcurrency: Int? = nil
    ) async throws -> [String: Result<T, Error>] {

        let concurrency = min(maxConcurrency ?? maxConcurrentTasks, tasks.count)
        var results: [String: Result<T, Error>] = [:]

        try await withThrowingTaskGroup(of: (String, Result<T, Error>).self) { group in
            var taskIterator = tasks.makeIterator()

            // Start initial tasks up to concurrency limit
            for _ in 0..<concurrency {
                if let task = taskIterator.next() {
                    let taskId = task.id
                    let operation = task.operation
                    group.addTask {
                        let result = await self.executeTaskSafely(id: taskId, operation: operation)
                        return (taskId, result)
                    }
                }
            }

            // Process results and start new tasks
            while let (taskId, result) = try await group.next() {
                results[taskId] = result

                // Start next task if available
                if let nextTask = taskIterator.next() {
                    let nextTaskId = nextTask.id
                    let nextOperation = nextTask.operation
                    group.addTask {
                        let result = await self.executeTaskSafely(
                            id: nextTaskId, operation: nextOperation)
                        return (nextTaskId, result)
                    }
                }
            }
        }

        return results
    }

    public func executeTaskSafely<T: Sendable>(
        id: String,
        operation: @escaping @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do {
            let result = try await execute(id: id, operation: operation)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Task Control

    public func cancel(taskId: String) {
        if let handle = activeTasks[taskId] {
            handle.cancel()
            activeTasks.removeValue(forKey: taskId)
        }

        Task {
            await taskQueue.cancelAll()
        }
    }

    public func cancelAll() {
        for handle in activeTasks.values {
            handle.cancel()
        }
        activeTasks.removeAll()

        Task {
            await taskQueue.cancelAll()
        }
    }

    public var activeTaskCount: Int {
        activeTasks.count
    }

    public func activeTaskIds() -> [String] {
        Array(activeTasks.keys)
    }

    // MARK: - Resource Management

    public func requestResources(_ resources: ResourceRequirement) async throws {
        guard resourceLimits.canAccommodate(resources, currentUsage: resourceUsage) else {
            throw TaskError.resourceUnavailable
        }

        resourceUsage.add(resources)
    }

    public func releaseResources(_ resources: ResourceRequirement) {
        resourceUsage.subtract(resources)
    }

    public var currentUsage: ResourceUsage {
        resourceUsage
    }

    // MARK: - Private Methods

    private func taskCompleted(id: String) {
        activeTasks.removeValue(forKey: id)

        // Process queued tasks
        Task {
            await processQueuedTasks()
        }
    }

    private func processQueuedTasks() async {
        while activeTasks.count < maxConcurrentTasks,
            let nextTask = await taskQueue.dequeue()
        {
            Task {
                nextTask.execute()
            }
        }
    }

    private func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TaskError.timeout
            }

            defer { group.cancelAll() }

            guard let result = try await group.next() else {
                throw TaskError.noResult
            }

            return result
        }
    }
}

// MARK: - Task Queue

actor TaskQueue {
    private var queue: [AnyTaskItem] = []

    func enqueue<T: Sendable>(_ item: TaskItem<T>) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let anyItem = AnyTaskItem(
                item: item,
                continuation: continuation as! CheckedContinuation<Any, Error>,
                execute: {
                    Task {
                        do {
                            let result = try await item.operation()
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            )

            queue.append(anyItem)
            queue.sort { $0.priority > $1.priority }
        }
    }

    func dequeue() -> AnyTaskItem? {
        queue.isEmpty ? nil : queue.removeFirst()
    }

    func cancel(taskId: String) {
        queue.removeAll { $0.id == taskId }
    }

    func cancelAll() {
        queue.removeAll()
    }
}

// MARK: - Supporting Types

struct TaskItem<T: Sendable> {
    let id: String
    let priority: TaskPriority
    let timeout: TimeInterval?
    let retryPolicy: RetryPolicy?
    let operation: @Sendable () async throws -> T
    let timestamp = Date()
}

struct AnyTaskItem {
    let id: String
    let priority: TaskPriority
    let timestamp: Date
    let execute: () -> Void

    init<T: Sendable>(
        item: TaskItem<T>,
        continuation: CheckedContinuation<Any, Error>,
        execute: @escaping () -> Void
    ) {
        self.id = item.id
        self.priority = item.priority
        self.timestamp = item.timestamp
        self.execute = execute
    }
}

extension AnyTaskItem: Comparable {
    static func < (lhs: AnyTaskItem, rhs: AnyTaskItem) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        return lhs.timestamp > rhs.timestamp
    }

    static func == (lhs: AnyTaskItem, rhs: AnyTaskItem) -> Bool {
        lhs.id == rhs.id
    }
}

final class TaskHandle: Sendable {
    let id: String
    private let task: Task<Void, Never>?

    init(id: String, task: Task<Void, Never>? = nil) {
        self.id = id
        self.task = task
    }

    func cancel() {
        task?.cancel()
    }
}

// MARK: - Task Builder

public struct TaskBuilder {
    private var id = UUID().uuidString
    private var priority = TaskPriority.medium
    private var timeout: TimeInterval?
    private var retryPolicy: RetryPolicy?
    private var resources: ResourceRequirement?

    public init() {}

    public func id(_ id: String) -> TaskBuilder {
        var builder = self
        builder.id = id
        return builder
    }

    public func priority(_ priority: TaskPriority) -> TaskBuilder {
        var builder = self
        builder.priority = priority
        return builder
    }

    public func timeout(_ timeout: TimeInterval) -> TaskBuilder {
        var builder = self
        builder.timeout = timeout
        return builder
    }

    public func retry(_ policy: RetryPolicy) -> TaskBuilder {
        var builder = self
        builder.retryPolicy = policy
        return builder
    }

    public func resources(_ requirement: ResourceRequirement) -> TaskBuilder {
        var builder = self
        builder.resources = requirement
        return builder
    }

    public func execute<T: Sendable>(
        on manager: FCITaskManager,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        if let resources = resources {
            try await manager.requestResources(resources)

            do {
                let result = try await manager.execute(
                    id: id,
                    priority: priority,
                    timeout: timeout,
                    retryPolicy: retryPolicy,
                    operation: operation
                )

                Task {
                    await manager.releaseResources(resources)
                }

                return result
            } catch {
                Task {
                    await manager.releaseResources(resources)
                }
                throw error
            }
        }

        return try await manager.execute(
            id: id,
            priority: priority,
            timeout: timeout,
            retryPolicy: retryPolicy,
            operation: operation
        )
    }
}

// MARK: - Task Group Manager

public final class TaskGroupManager<T: Sendable>: Sendable {
    private let groupId: String
    private let maxConcurrency: Int
    private let tasks = ThreadSafeArray<(id: String, operation: @Sendable () async throws -> T)>()

    public init(groupId: String, maxConcurrency: Int) {
        self.groupId = groupId
        self.maxConcurrency = maxConcurrency
    }

    public func addTask(id: String, operation: @Sendable @escaping () async throws -> T) async {
        await tasks.append((id: id, operation: operation))
    }

    public func execute() async throws -> [String: Result<T, Error>] {
        let allTasks = await tasks.allElements()
        var results: [String: Result<T, Error>] = [:]

        try await withThrowingTaskGroup(of: (String, Result<T, Error>).self) { group in
            var taskIterator = allTasks.makeIterator()

            // Start initial tasks
            for _ in 0..<min(maxConcurrency, allTasks.count) {
                if let task = taskIterator.next() {
                    group.addTask {
                        do {
                            let result = try await task.operation()
                            return (task.id, .success(result))
                        } catch {
                            return (task.id, .failure(error))
                        }
                    }
                }
            }

            // Process results and start remaining tasks
            while let (taskId, result) = try await group.next() {
                results[taskId] = result

                if let nextTask = taskIterator.next() {
                    group.addTask {
                        do {
                            let result = try await nextTask.operation()
                            return (nextTask.id, .success(result))
                        } catch {
                            return (nextTask.id, .failure(error))
                        }
                    }
                }
            }
        }

        return results
    }
}

// MARK: - Legacy Compatibility

public typealias QueuerService = FCITaskManager

/// Legacy compatibility wrapper for synchronous API
public final class FCIQueuerLegacy: Sendable {
    private let taskManager = FCITaskManager()

    public init() {}

    public func addOperation<T>(
        _ operation: @escaping @Sendable () throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            let result = await taskManager.executeTaskSafely(id: UUID().uuidString) {
                try operation()
            }
            await MainActor.run {
                completion(result)
            }
        }
    }

    public func addAsyncOperation<T>(
        _ operation: @escaping @Sendable () async throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            let result = await taskManager.executeTaskSafely(
                id: UUID().uuidString, operation: operation)
            await MainActor.run {
                completion(result)
            }
        }
    }

    public func cancelAllOperations() {
        Task {
            await taskManager.cancelAll()
        }
    }

    public func getActiveOperationCount(completion: @escaping (Int) -> Void) {
        Task {
            let count = await taskManager.activeTaskCount
            await MainActor.run {
                completion(count)
            }
        }
    }
}
