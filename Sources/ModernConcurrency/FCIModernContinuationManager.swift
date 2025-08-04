import Foundation

/// Modern continuation management using Swift Concurrency
/// Enhanced version with better safety, reduced duplication, and improved debugging
public actor FCIModernContinuationManager {

    // MARK: - Properties

    private var hasResumed = false
    private var creationInfo: ContinuationInfo?
    private var resumeInfo: ContinuationInfo?

    // MARK: - Initialization

    public init(
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        self.creationInfo = ContinuationInfo(
            file: file,
            line: line,
            function: function,
            timestamp: Date()
        )
    }

    // MARK: - Generic Continuation Handling

    /// Resume continuation with a value using a generic approach
    public func resume<T, E>(
        _ continuation: CheckedContinuation<T, E>,
        with result: ContinuationResult<T, E>,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) where E: Error {
        guard !hasResumed else {
            logDuplicateResume(file: file, line: line, function: function)
            return
        }

        markAsResumed(file: file, line: line, function: function)

        switch result {
        case .value(let value):
            if E.self == Never.self {
                continuation.resume(returning: value)
            } else if let errorContinuation = continuation as? CheckedContinuation<T, Error> {
                errorContinuation.resume(returning: value)
            }
        case .error(let error):
            if let errorContinuation = continuation as? CheckedContinuation<T, Error>,
                let actualError = error
            {
                errorContinuation.resume(throwing: actualError)
            }
        }
    }

    // MARK: - Convenience Methods

    public func resumeWithValue<T>(
        _ continuation: CheckedContinuation<T, Never>,
        value: T,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        resume(continuation, with: .value(value), file: file, line: line, function: function)
    }

    public func resumeWithVoid(
        _ continuation: CheckedContinuation<Void, Never>,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        resume(continuation, with: .value(()), file: file, line: line, function: function)
    }

    public func resumeWithError<T>(
        _ continuation: CheckedContinuation<T, Error>,
        error: Error,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        resume(continuation, with: .error(error), file: file, line: line, function: function)
    }

    public func resumeWithResult<T>(
        _ continuation: CheckedContinuation<T, Error>,
        result: Result<T, Error>,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        switch result {
        case .success(let value):
            resume(continuation, with: .value(value), file: file, line: line, function: function)
        case .failure(let error):
            resume(continuation, with: .error(error), file: file, line: line, function: function)
        }
    }

    // MARK: - State Management

    public var isResumed: Bool {
        hasResumed
    }

    public func reset() {
        hasResumed = false
        resumeInfo = nil
    }

    public var debugInfo: ContinuationDebugInfo {
        ContinuationDebugInfo(
            hasResumed: hasResumed,
            creationInfo: creationInfo,
            resumeInfo: resumeInfo
        )
    }

    // MARK: - Private Methods

    private func markAsResumed(
        file: StaticString,
        line: UInt,
        function: StaticString
    ) {
        hasResumed = true
        resumeInfo = ContinuationInfo(
            file: file,
            line: line,
            function: function,
            timestamp: Date()
        )
    }

    private func logDuplicateResume(
        file: StaticString,
        line: UInt,
        function: StaticString
    ) {
        let currentAttempt = ContinuationInfo(
            file: file,
            line: line,
            function: function,
            timestamp: Date()
        )

        #if DEBUG
            let message = """
                ❌ CRITICAL: Attempted to resume continuation multiple times!
                📍 Creation: \(creationInfo?.description ?? "Unknown")
                ✅ First Resume: \(resumeInfo?.description ?? "Unknown")
                🚫 Duplicate Attempt: \(currentAttempt.description)
                """
            assertionFailure(message)
        #else
            print(
                """
                WARNING: Attempted to resume continuation multiple times
                Creation: \(creationInfo?.description ?? "Unknown")
                First Resume: \(resumeInfo?.description ?? "Unknown")
                Duplicate Attempt: \(currentAttempt.description)
                """)
        #endif
    }
}

// MARK: - Supporting Types

public enum ContinuationResult<T, E: Error> {
    case value(T)
    case error(E?)
}

public struct ContinuationInfo: CustomStringConvertible {
    public let file: StaticString
    public let line: UInt
    public let function: StaticString
    public let timestamp: Date

    public var description: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fileName = "\(file)".split(separator: "/").last ?? ""
        return "\(function) at \(fileName):\(line) [\(formatter.string(from: timestamp))]"
    }
}

public struct ContinuationDebugInfo: CustomStringConvertible {
    public let hasResumed: Bool
    public let creationInfo: ContinuationInfo?
    public let resumeInfo: ContinuationInfo?

    public var description: String {
        """
        Continuation Debug Info:
          Status: \(hasResumed ? "Resumed" : "Pending")
          Created: \(creationInfo?.description ?? "Unknown")
          Resumed: \(resumeInfo?.description ?? "Unknown")
        """
    }
}

// MARK: - Continuation Builder

public struct SafeContinuation {

    /// Create a safe continuation with automatic tracking
    public static func withCheckedContinuation<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        body: @Sendable @escaping (CheckedContinuation<T, Never>) async -> Void
    ) async -> T {
        let _ = FCIModernContinuationManager(file: file, line: line, function: function)

        return await _Concurrency.withCheckedContinuation { continuation in
            Task {
                await body(continuation)
                // Manager tracks completion automatically
            }
        }
    }

    /// Create a safe throwing continuation with automatic tracking
    public static func withCheckedThrowingContinuation<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        body: @Sendable @escaping (CheckedContinuation<T, Error>) async -> Void
    ) async throws -> T {
        let _ = FCIModernContinuationManager(file: file, line: line, function: function)

        return try await _Concurrency.withCheckedThrowingContinuation { continuation in
            Task {
                await body(continuation)
                // Manager tracks completion automatically
            }
        }
    }

    /// Create a safe continuation with timeout and retry support
    public static func withTimeoutAndRetry<T>(
        timeout: TimeInterval,
        retryCount: Int = 0,
        retryDelay: TimeInterval = 1.0,
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        body: @Sendable @escaping (CheckedContinuation<T, Error>) async -> Void
    ) async throws -> T {
        var lastError: Error = ContinuationError.timeout

        for attempt in 0...retryCount {
            do {
                return try await withTimeout(
                    timeout: timeout,
                    function: function,
                    file: file,
                    line: line,
                    body: body
                )
            } catch {
                lastError = error
                if attempt < retryCount {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }

        throw lastError
    }

    private static func withTimeout<T>(
        timeout: TimeInterval,
        function: StaticString,
        file: StaticString,
        line: UInt,
        body: @Sendable @escaping (CheckedContinuation<T, Error>) async -> Void
    ) async throws -> T {
        let _ = FCIModernContinuationManager(file: file, line: line, function: function)

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await _Concurrency.withCheckedThrowingContinuation { continuation in
                    Task {
                        await body(continuation)
                        // Manager tracks completion automatically
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ContinuationError.timeout
            }

            defer { group.cancelAll() }

            guard let result = try await group.next() else {
                throw ContinuationError.noResult
            }

            return result
        }
    }
}

// MARK: - Error Types

public enum ContinuationError: LocalizedError {
    case timeout
    case alreadyResumed
    case cancelled
    case noResult

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Continuation timed out"
        case .alreadyResumed:
            return "Continuation was already resumed"
        case .cancelled:
            return "Continuation was cancelled"
        case .noResult:
            return "No result available from continuation"
        }
    }
}

// MARK: - Continuation Extensions

extension CheckedContinuation {
    /// Resume with automatic error handling
    public func resumeSafely(
        with result: Result<T, E>,
        using manager: FCIModernContinuationManager,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) async {
        await manager.resumeWithResult(
            self as! CheckedContinuation<T, Error>,
            result: result as! Result<T, Error>,
            file: file,
            line: line,
            function: function
        )
    }
}

// MARK: - Legacy Compatibility

/// Backward compatibility wrapper for existing code
public final class ContinuationChecker: Sendable {
    private let manager: FCIModernContinuationManager

    public init(
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        self.manager = FCIModernContinuationManager(
            file: file,
            line: line,
            function: function
        )
    }

    public func resume<T>(
        _ continuation: CheckedContinuation<T, Never>,
        returning value: T,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        Task {
            await manager.resumeWithValue(
                continuation,
                value: value,
                file: file,
                line: line,
                function: function
            )
        }
    }

    public func resume<T>(
        _ continuation: CheckedContinuation<T, Error>,
        returning value: T,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        Task {
            await manager.resume(
                continuation,
                with: .value(value),
                file: file,
                line: line,
                function: function
            )
        }
    }

    public func resume<T>(
        _ continuation: CheckedContinuation<T, Error>,
        throwing error: Error,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        Task {
            await manager.resumeWithError(
                continuation,
                error: error,
                file: file,
                line: line,
                function: function
            )
        }
    }
}
