import Foundation

/// Thread-safe box for holding values
private class ValueBox<Value> {
    var value: Value?
    private let lock = NSLock()
    
    init(_ value: Value?) {
        self.value = value
    }
    
    func set(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
    
    func get() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Modern Thread Safety using Swift Concurrency
/// Actor-based thread safety with improved async support
public protocol ThreadSafeStorageProtocol: Actor {
    func setValue<T>(_ value: T, forKey key: String) async
    func getValue<T>(forKey key: String, as type: T.Type) async -> T?
    func removeValue(forKey key: String) async
    func getAllKeys() async -> [String]
    func clear() async
}

// MARK: - Main Thread Safety Actor

public actor FCIModernThreadSafety: ThreadSafeStorageProtocol {

    // MARK: - Properties

    private var storage: [String: Any] = [:]
    private let storageObservers = ObserverStorage()
    
    // MARK: - Initialization
    
    public init() {
        // Initialize with empty storage
    }

    // MARK: - Storage Operations

    public func setValue<T>(_ value: T, forKey key: String) {
        let oldValue = storage[key]
        storage[key] = value

        Task {
            await storageObservers.notifyObservers(
                key: key,
                oldValue: oldValue,
                newValue: value
            )
        }
    }

    public func getValue<T>(forKey key: String, as type: T.Type) -> T? {
        storage[key] as? T
    }

    public func removeValue(forKey key: String) {
        let oldValue = storage[key]
        storage.removeValue(forKey: key)

        Task {
            await storageObservers.notifyObservers(
                key: key,
                oldValue: oldValue,
                newValue: nil
            )
        }
    }

    public func getAllKeys() -> [String] {
        Array(storage.keys)
    }

    public func clear() {
        storage.removeAll()

        Task {
            await storageObservers.clearObservers()
        }
    }

    // MARK: - Batch Operations

    public func setMultipleValues(_ values: [String: Any]) {
        for (key, value) in values {
            storage[key] = value
        }
    }

    public func getMultipleValues<T>(
        forKeys keys: [String],
        as type: T.Type
    ) -> [String: T] {
        keys.reduce(into: [:]) { result, key in
            if let value = storage[key] as? T {
                result[key] = value
            }
        }
    }

    // MARK: - Async Operations

    public func performOperation<T>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await operation()
    }

    public func performOperationWithResult<T>(
        _ operation: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Observers

    public func addObserver(
        forKey key: String,
        handler: @escaping @Sendable (Any?, Any?) async -> Void
    ) async -> ObserverToken {
        await storageObservers.addObserver(forKey: key, handler: handler)
    }

    public func removeObserver(_ token: ObserverToken) async {
        await storageObservers.removeObserver(token)
    }
}

// MARK: - Observer Support

actor ObserverStorage {
    private var observers: [String: [ObserverToken: (@Sendable (Any?, Any?) async -> Void)]] = [:]

    func addObserver(
        forKey key: String,
        handler: @escaping @Sendable (Any?, Any?) async -> Void
    ) -> ObserverToken {
        let token = ObserverToken()

        if observers[key] == nil {
            observers[key] = [:]
        }

        observers[key]?[token] = handler
        return token
    }

    func removeObserver(_ token: ObserverToken) {
        for key in observers.keys {
            observers[key]?.removeValue(forKey: token)
        }
    }

    func notifyObservers(key: String, oldValue: Any?, newValue: Any?) async {
        guard let keyObservers = observers[key] else { return }

        await withTaskGroup(of: Void.self) { group in
            for (_, handler) in keyObservers {
                group.addTask {
                    await handler(oldValue, newValue)
                }
            }
        }
    }

    func clearObservers() {
        observers.removeAll()
    }
}

public struct ObserverToken: Hashable {
    private let id = UUID()
}

// MARK: - Thread-Safe Classes

/// ActorIsolated class for thread-safe access
/// Uses "Isolated" terminology following Swift's actor isolation conventions
/// Note: Use the async methods getValue() and setValue() for proper actor isolation
public final class ActorIsolated<T: Sendable>: @unchecked Sendable {
    private let storage: IsolatedStorage<T>

    public init(wrappedValue: T) {
        self.storage = IsolatedStorage(wrappedValue)
    }

    /// Projected value provides async access
    public var projectedValue: ActorIsolated<T> {
        self
    }

    /// Async getter - Preferred method
    public func getValue() async -> T {
        await storage.value
    }

    /// Async setter - Preferred method
    public func setValue(_ newValue: T) async {
        await storage.setValue(newValue)
    }

    public func update(_ transform: @Sendable (T) async throws -> T) async rethrows {
        try await storage.update(transform)
    }
}

/// IsolatedStorage - Actor that provides isolated storage for values
/// Uses "Storage" to clearly indicate this is for storing and modifying values
/// "Isolated" follows Swift actor isolation terminology
private actor IsolatedStorage<T: Sendable> {
    var value: T

    init(_ initialValue: T) {
        self.value = initialValue
    }

    func setValue(_ newValue: T) {
        self.value = newValue
    }

    func update(_ transform: @Sendable (T) async throws -> T) async rethrows {
        self.value = try await transform(value)
    }
}

// MARK: - Thread-Safe Collections

/// ThreadSafeArray - Thread-safe array implementation using actor isolation
/// Uses "ThreadSafe" prefix to explicitly indicate the type of safety provided
/// Following industry standard naming conventions
public actor ThreadSafeArray<Element: Sendable> {
    private var array: [Element] = []

    public init(_ elements: [Element] = []) {
        self.array = elements
    }

    // MARK: - Basic Operations

    public func append(_ element: Element) {
        array.append(element)
    }

    public func append(contentsOf elements: [Element]) {
        array.append(contentsOf: elements)
    }

    public func insert(_ element: Element, at index: Int) {
        guard index >= 0 && index <= array.count else { return }
        array.insert(element, at: index)
    }

    @discardableResult
    public func remove(at index: Int) -> Element? {
        guard index >= 0 && index < array.count else { return nil }
        return array.remove(at: index)
    }

    @discardableResult
    public func removeLast() -> Element? {
        array.isEmpty ? nil : array.removeLast()
    }

    @discardableResult
    public func removeFirst() -> Element? {
        array.isEmpty ? nil : array.removeFirst()
    }

    public func removeAll(keepingCapacity: Bool = false) {
        array.removeAll(keepingCapacity: keepingCapacity)
    }

    // MARK: - Access Operations

    public var count: Int {
        array.count
    }

    public var isEmpty: Bool {
        array.isEmpty
    }

    public func element(at index: Int) -> Element? {
        guard index >= 0 && index < array.count else { return nil }
        return array[index]
    }

    public var first: Element? {
        array.first
    }

    public var last: Element? {
        array.last
    }

    public func allElements() -> [Element] {
        array
    }

    // MARK: - Functional Operations

    public func contains(where predicate: (Element) throws -> Bool) rethrows -> Bool {
        try array.contains(where: predicate)
    }

    public func first(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        try array.first(where: predicate)
    }

    public func filter(_ isIncluded: (Element) throws -> Bool) rethrows -> [Element] {
        try array.filter(isIncluded)
    }

    public func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        try array.map(transform)
    }

    public func compactMap<T>(_ transform: (Element) throws -> T?) rethrows -> [T] {
        try array.compactMap(transform)
    }

    public func reduce<Result>(
        _ initialResult: Result,
        _ nextPartialResult: (Result, Element) throws -> Result
    ) rethrows -> Result {
        try array.reduce(initialResult, nextPartialResult)
    }

    // MARK: - Batch Operations

    public func updateAll(_ transform: (Element) throws -> Element) rethrows {
        array = try array.map(transform)
    }

    public func removeAll(where shouldRemove: (Element) throws -> Bool) rethrows {
        try array.removeAll(where: shouldRemove)
    }

    // MARK: - Sorting and Reversing

    public func sort(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows {
        try array.sort(by: areInIncreasingOrder)
    }

    public func sorted(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows
        -> [Element]
    {
        try array.sorted(by: areInIncreasingOrder)
    }

    public func reverse() {
        array.reverse()
    }

    public func reversed() -> [Element] {
        array.reversed()
    }
}

/// ThreadSafeDictionary - Thread-safe dictionary implementation using actor isolation
/// Uses "ThreadSafe" prefix to explicitly indicate the type of safety provided
/// Following industry standard naming conventions
public actor ThreadSafeDictionary<Key: Hashable & Sendable, Value: Sendable> {
    private var dictionary: [Key: Value] = [:]

    public init(_ dict: [Key: Value] = [:]) {
        self.dictionary = dict
    }

    // MARK: - Basic Operations

    public func setValue(_ value: Value?, forKey key: Key) {
        dictionary[key] = value
    }

    public func getValue(forKey key: Key) -> Value? {
        dictionary[key]
    }

    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        dictionary.removeValue(forKey: key)
    }

    public func removeAll(keepingCapacity: Bool = false) {
        dictionary.removeAll(keepingCapacity: keepingCapacity)
    }

    // MARK: - Access Operations

    public var count: Int {
        dictionary.count
    }

    public var isEmpty: Bool {
        dictionary.isEmpty
    }

    public var keys: [Key] {
        Array(dictionary.keys)
    }

    public var values: [Value] {
        Array(dictionary.values)
    }

    public func allItems() -> [Key: Value] {
        dictionary
    }

    public func contains(key: Key) -> Bool {
        dictionary[key] != nil
    }

    // MARK: - Batch Operations

    public func merge(
        _ other: [Key: Value], uniquingKeysWith combine: (Value, Value) throws -> Value
    ) rethrows {
        try dictionary.merge(other, uniquingKeysWith: combine)
    }

    public func compactMapValues<T>(_ transform: (Value) throws -> T?) rethrows -> [Key: T] {
        try dictionary.compactMapValues(transform)
    }

    public func mapValues<T>(_ transform: (Value) throws -> T) rethrows -> [Key: T] {
        try dictionary.mapValues(transform)
    }

    public func filter(_ isIncluded: (Key, Value) throws -> Bool) rethrows -> [Key: Value] {
        try dictionary.filter { try isIncluded($0.key, $0.value) }
    }
}

// MARK: - Global Actors

@globalActor
public actor FCIBackgroundActor {
    public static let shared = FCIBackgroundActor()
    private init() {}
}

@globalActor
public actor FCIDataActor {
    public static let shared = FCIDataActor()
    private init() {}
}

// MARK: - Thread Safety Utilities

public struct ThreadSafetyUtilities {

    /// Execute an operation on a specific actor
    public static func onActor<T>(
        _ actor: isolated any Actor,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await operation()
    }

    /// Execute an operation on the main actor if needed
    @MainActor
    public static func onMainActor<T>(
        _ operation: @Sendable @MainActor () async throws -> T
    ) async rethrows -> T {
        try await operation()
    }

    /// Execute an operation on a background actor
    @FCIBackgroundActor
    public static func onBackgroundActor<T>(
        _ operation: @Sendable @FCIBackgroundActor () async throws -> T
    ) async rethrows -> T {
        try await operation()
    }
}

// MARK: - Legacy Compatibility

public typealias ThreadSafetyManager = FCIModernThreadSafety

/// @deprecated Use ThreadSafeArray<T> instead for better clarity about thread safety
public typealias SafeArray<T: Sendable> = ThreadSafeArray<T>

/// @deprecated Use ThreadSafeDictionary<K, V> instead for better clarity about thread safety
public typealias SafeDictionary<K: Hashable & Sendable, V: Sendable> = ThreadSafeDictionary<K, V>

/// Legacy compatibility wrapper for synchronous API
public final class FCIThreadSafetyLegacy: Sendable {
    private let actor = FCIModernThreadSafety()

    public init() {}

    public func setValue<T>(_ value: T, forKey key: String, completion: @escaping () -> Void = {}) {
        Task {
            await actor.setValue(value, forKey: key)
            await MainActor.run {
                completion()
            }
        }
    }

    public func getValue<T>(forKey key: String, as type: T.Type, completion: @escaping (T?) -> Void)
    {
        Task {
            let value = await actor.getValue(forKey: key, as: type)
            await MainActor.run {
                completion(value)
            }
        }
    }

    public func performOperation<T>(
        _ operation: @escaping () throws -> T, completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            let result = await actor.performOperationWithResult {
                try operation()
            }
            await MainActor.run {
                completion(result)
            }
        }
    }

    public func clear(completion: @escaping () -> Void = {}) {
        Task {
            await actor.clear()
            await MainActor.run {
                completion()
            }
        }
    }
}

// MARK: - Async Atomic Property Wrapper

/// Thread-safe atomic class
/// Access values using async operations
public final class AsyncAtomic<T: Sendable>: @unchecked Sendable {
    private let storage: IsolatedStorage<T>

    public init(_ initialValue: T) {
        self.storage = IsolatedStorage(initialValue)
    }

    /// Async read
    public func read() async -> T {
        await storage.value
    }

    /// Async write
    public func write(_ newValue: T) async {
        await storage.setValue(newValue)
    }

    /// Async modify with result
/// Thread-safe box for holding values
private class ValueBox<Value> {
    var value: Value?
    private let lock = NSLock()
    
    init(_ value: Value?) {
        self.value = value
    }
    
    func set(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
    
    func get() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Result container actor for safely capturing results in concurrent operations
private actor ResultContainer<R> {
    private var value: R?
    
    func setValue(_ newValue: R) {
        value = newValue
    }
    
    func getValue() -> R! {
        return value
    }
}

    @discardableResult
    public func modify<R>(_ transform: @Sendable (T) async throws -> (T, R)) async rethrows -> R {
        // Use actor isolation to safely capture the result
        let resultContainer = ResultContainer<R>()
        try await storage.update { currentValue in
            let (newValue, result) = try await transform(currentValue)
            await resultContainer.setValue(result)
            return newValue
        }
        return await resultContainer.getValue()
    }
}

