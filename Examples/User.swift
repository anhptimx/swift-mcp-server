// Example Swift file for testing the MCP Server

import Foundation

/// A user model representing a person in the system
public class User {
    // MARK: - Properties
    
    /// The unique identifier for the user
    public let id: UUID
    
    /// The user's full name
    public var name: String
    
    /// The user's email address
    public var email: String
    
    /// The user's age
    public var age: Int
    
    /// Whether the user account is active
    public var isActive: Bool
    
    // MARK: - Initialization
    
    /// Initialize a new user
    /// - Parameters:
    ///   - name: The user's full name
    ///   - email: The user's email address
    ///   - age: The user's age
    public init(name: String, email: String, age: Int) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.age = age
        self.isActive = true
    }
    
    // MARK: - Methods
    
    /// Update the user's information
    /// - Parameters:
    ///   - name: New name (optional)
    ///   - email: New email (optional)
    ///   - age: New age (optional)
    public func updateInfo(name: String? = nil, email: String? = nil, age: Int? = nil) {
        if let name = name {
            self.name = name
        }
        if let email = email {
            self.email = email
        }
        if let age = age {
            self.age = age
        }
    }
    
    /// Deactivate the user account
    public func deactivate() {
        isActive = false
    }
    
    /// Activate the user account
    public func activate() {
        isActive = true
    }
    
    /// Check if the user is an adult
    /// - Returns: True if age >= 18
    public func isAdult() -> Bool {
        return age >= 18
    }
    
    /// Get user's initials
    /// - Returns: The first letter of each name component
    public func getInitials() -> String {
        return name.split(separator: " ")
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }
}

// MARK: - User + CustomStringConvertible

extension User: CustomStringConvertible {
    public var description: String {
        return "User(id: \(id), name: \(name), email: \(email), age: \(age), active: \(isActive))"
    }
}

// MARK: - User + Equatable

extension User: Equatable {
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - UserRepository Protocol

/// Protocol for user data persistence
public protocol UserRepository {
    /// Save a user to the repository
    /// - Parameter user: The user to save
    /// - Throws: Repository errors
    func save(_ user: User) throws
    
    /// Find a user by ID
    /// - Parameter id: The user ID
    /// - Returns: The user if found, nil otherwise
    /// - Throws: Repository errors
    func findById(_ id: UUID) throws -> User?
    
    /// Find users by email
    /// - Parameter email: The email to search for
    /// - Returns: Array of matching users
    /// - Throws: Repository errors
    func findByEmail(_ email: String) throws -> [User]
    
    /// Get all users
    /// - Returns: Array of all users
    /// - Throws: Repository errors
    func getAllUsers() throws -> [User]
    
    /// Delete a user
    /// - Parameter id: The user ID to delete
    /// - Throws: Repository errors
    func delete(_ id: UUID) throws
}

// MARK: - In-Memory User Repository

/// Simple in-memory implementation of UserRepository
public class InMemoryUserRepository: UserRepository {
    private var users: [UUID: User] = [:]
    private let queue = DispatchQueue(label: "user.repository.queue", attributes: .concurrent)
    
    public init() {}
    
    public func save(_ user: User) throws {
        queue.async(flags: .barrier) {
            self.users[user.id] = user
        }
    }
    
    public func findById(_ id: UUID) throws -> User? {
        return queue.sync {
            return users[id]
        }
    }
    
    public func findByEmail(_ email: String) throws -> [User] {
        return queue.sync {
            return users.values.filter { $0.email == email }
        }
    }
    
    public func getAllUsers() throws -> [User] {
        return queue.sync {
            return Array(users.values)
        }
    }
    
    public func delete(_ id: UUID) throws {
        queue.async(flags: .barrier) {
            self.users.removeValue(forKey: id)
        }
    }
}

// MARK: - UserService

/// Service class for user business logic
public class UserService {
    private let repository: UserRepository
    
    /// Initialize the service with a repository
    /// - Parameter repository: The user repository to use
    public init(repository: UserRepository) {
        self.repository = repository
    }
    
    /// Create a new user
    /// - Parameters:
    ///   - name: User's name
    ///   - email: User's email
    ///   - age: User's age
    /// - Returns: The created user
    /// - Throws: Service errors
    public func createUser(name: String, email: String, age: Int) throws -> User {
        // Validate input
        guard !name.isEmpty else {
            throw UserServiceError.invalidName
        }
        
        guard isValidEmail(email) else {
            throw UserServiceError.invalidEmail
        }
        
        guard age >= 0 && age <= 150 else {
            throw UserServiceError.invalidAge
        }
        
        // Check if email already exists
        let existingUsers = try repository.findByEmail(email)
        guard existingUsers.isEmpty else {
            throw UserServiceError.emailAlreadyExists
        }
        
        // Create and save user
        let user = User(name: name, email: email, age: age)
        try repository.save(user)
        
        return user
    }
    
    /// Update an existing user
    /// - Parameters:
    ///   - id: User ID
    ///   - name: New name (optional)
    ///   - email: New email (optional)
    ///   - age: New age (optional)
    /// - Returns: The updated user
    /// - Throws: Service errors
    public func updateUser(id: UUID, name: String? = nil, email: String? = nil, age: Int? = nil) throws -> User {
        guard let user = try repository.findById(id) else {
            throw UserServiceError.userNotFound
        }
        
        // Validate new email if provided
        if let email = email, !isValidEmail(email) {
            throw UserServiceError.invalidEmail
        }
        
        // Validate new age if provided
        if let age = age, age < 0 || age > 150 {
            throw UserServiceError.invalidAge
        }
        
        // Update user
        user.updateInfo(name: name, email: email, age: age)
        try repository.save(user)
        
        return user
    }
    
    /// Get all active users
    /// - Returns: Array of active users
    /// - Throws: Service errors
    public func getActiveUsers() throws -> [User] {
        let allUsers = try repository.getAllUsers()
        return allUsers.filter { $0.isActive }
    }
    
    /// Get all adult users (age >= 18)
    /// - Returns: Array of adult users
    /// - Throws: Service errors
    public func getAdultUsers() throws -> [User] {
        let allUsers = try repository.getAllUsers()
        return allUsers.filter { $0.isAdult() }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - UserServiceError

/// Errors that can occur in UserService
public enum UserServiceError: Error, LocalizedError {
    case invalidName
    case invalidEmail
    case invalidAge
    case emailAlreadyExists
    case userNotFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Name cannot be empty"
        case .invalidEmail:
            return "Invalid email format"
        case .invalidAge:
            return "Age must be between 0 and 150"
        case .emailAlreadyExists:
            return "Email already exists"
        case .userNotFound:
            return "User not found"
        }
    }
}
