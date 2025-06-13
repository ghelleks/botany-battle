import XCTest
import ComposableArchitecture
@testable import BotanyBattle

@MainActor
final class AuthFlowTests: XCTestCase {
    
    func testSignUpFlow() async {
        let mockAuthService = MockAuthService()
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authService = mockAuthService
        }
        
        // Test signup action
        await store.send(.signup(
            username: "testuser",
            email: "test@example.com",
            password: "password123",
            displayName: "Test User"
        )) {
            $0.isLoading = true
            $0.error = nil
        }
        
        // Simulate successful signup
        await store.receive(.signupSuccess) {
            $0.isLoading = false
            $0.error = nil
        }
        
        XCTAssertTrue(mockAuthService.signUpCalled)
        XCTAssertEqual(mockAuthService.lastSignUpUsername, "testuser")
        XCTAssertEqual(mockAuthService.lastSignUpEmail, "test@example.com")
    }
    
    func testSignUpFailure() async {
        let mockAuthService = MockAuthService()
        mockAuthService.shouldFailSignUp = true
        
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authService = mockAuthService
        }
        
        await store.send(.signup(
            username: "testuser",
            email: "test@example.com",
            password: "weak",
            displayName: "Test User"
        )) {
            $0.isLoading = true
            $0.error = nil
        }
        
        await store.receive(.authError("Sign up failed")) {
            $0.isLoading = false
            $0.error = "Sign up failed"
        }
    }
    
    func testSignInFlow() async {
        let mockUser = User(
            id: "test-id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            avatarURL: nil,
            createdAt: Date(),
            stats: User.UserStats(
                totalGamesPlayed: 0,
                totalWins: 0,
                currentStreak: 0,
                longestStreak: 0,
                eloRating: 1000,
                rank: "Seedling",
                plantsIdentified: 0,
                accuracyRate: 0.0
            ),
            currency: User.Currency(coins: 100, gems: 0, tokens: 0)
        )
        
        let mockAuthService = MockAuthService()
        mockAuthService.mockUser = mockUser
        
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authService = mockAuthService
        }
        
        await store.send(.login(username: "testuser", password: "password123")) {
            $0.isLoading = true
            $0.error = nil
        }
        
        await store.receive(.loginSuccess(mockUser)) {
            $0.isLoading = false
            $0.isAuthenticated = true
            $0.currentUser = mockUser
            $0.error = nil
        }
        
        XCTAssertTrue(mockAuthService.signInCalled)
    }
    
    func testSignInFailure() async {
        let mockAuthService = MockAuthService()
        mockAuthService.shouldFailSignIn = true
        
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authService = mockAuthService
        }
        
        await store.send(.login(username: "wronguser", password: "wrongpass")) {
            $0.isLoading = true
            $0.error = nil
        }
        
        await store.receive(.authError("Invalid credentials")) {
            $0.isLoading = false
            $0.error = "Invalid credentials"
        }
        
        XCTAssertFalse(store.state.isAuthenticated)
        XCTAssertNil(store.state.currentUser)
    }
    
    func testAuthCheckWhenAuthenticated() async {
        let mockUser = User(
            id: "test-id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            avatarURL: nil,
            createdAt: Date(),
            stats: User.UserStats(
                totalGamesPlayed: 5,
                totalWins: 3,
                currentStreak: 2,
                longestStreak: 4,
                eloRating: 1150,
                rank: "Sprout",
                plantsIdentified: 15,
                accuracyRate: 0.75
            ),
            currency: User.Currency(coins: 250, gems: 5, tokens: 0)
        )
        
        let mockAuthService = MockAuthService()
        mockAuthService.mockUser = mockUser
        
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authService = mockAuthService
        }
        
        await store.send(.checkAuthStatus) {
            $0.isLoading = true
        }
        
        await store.receive(.loginSuccess(mockUser)) {
            $0.isLoading = false
            $0.isAuthenticated = true
            $0.currentUser = mockUser
            $0.error = nil
        }
    }
    
    func testAuthCheckWhenNotAuthenticated() async {
        let mockAuthService = MockAuthService()
        mockAuthService.shouldFailGetCurrentUser = true
        
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authService = mockAuthService
        }
        
        await store.send(.checkAuthStatus) {
            $0.isLoading = true
        }
        
        await store.receive(.authCheckComplete) {
            $0.isLoading = false
            $0.isAuthenticated = false
        }
    }
    
    func testLogoutFlow() async {
        let mockUser = User(
            id: "test-id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            avatarURL: nil,
            createdAt: Date(),
            stats: User.UserStats(
                totalGamesPlayed: 0,
                totalWins: 0,
                currentStreak: 0,
                longestStreak: 0,
                eloRating: 1000,
                rank: "Seedling",
                plantsIdentified: 0,
                accuracyRate: 0.0
            ),
            currency: User.Currency(coins: 100, gems: 0, tokens: 0)
        )
        
        let store = TestStore(
            initialState: AuthFeature.State(
                isAuthenticated: true,
                currentUser: mockUser
            )
        ) {
            AuthFeature()
        } withDependencies: {
            $0.authService = MockAuthService()
        }
        
        await store.send(.logout) {
            $0.isLoading = true
        }
        
        await store.receive(.logoutSuccess) {
            $0.isLoading = false
            $0.isAuthenticated = false
            $0.currentUser = nil
            $0.error = nil
        }
    }
    
    func testFormValidation() async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        }
        
        // Test login form validation
        XCTAssertFalse(store.state.loginForm.isValid)
        
        await store.send(.updateLoginForm(username: "testuser", password: nil)) {
            $0.loginForm.username = "testuser"
        }
        XCTAssertFalse(store.state.loginForm.isValid)
        
        await store.send(.updateLoginForm(username: nil, password: "password123")) {
            $0.loginForm.password = "password123"
        }
        XCTAssertTrue(store.state.loginForm.isValid)
        
        // Test signup form validation
        XCTAssertFalse(store.state.signupForm.isValid)
        
        await store.send(.updateSignupForm(
            username: "testuser",
            email: "test@example.com",
            password: "password123",
            confirmPassword: "password123",
            displayName: "Test User"
        )) {
            $0.signupForm.username = "testuser"
            $0.signupForm.email = "test@example.com"
            $0.signupForm.password = "password123"
            $0.signupForm.confirmPassword = "password123"
            $0.signupForm.displayName = "Test User"
        }
        XCTAssertTrue(store.state.signupForm.isValid)
        
        // Test password mismatch
        await store.send(.updateSignupForm(
            username: nil,
            email: nil,
            password: nil,
            confirmPassword: "different",
            displayName: nil
        )) {
            $0.signupForm.confirmPassword = "different"
        }
        XCTAssertFalse(store.state.signupForm.isValid)
    }
    
    func testErrorHandling() async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        }
        
        await store.send(.authError("Network error")) {
            $0.error = "Network error"
        }
        
        await store.send(.clearError) {
            $0.error = nil
        }
    }
}

// MARK: - Mock Auth Service
final class MockAuthService: AuthServiceProtocol {
    var signInCalled = false
    var signUpCalled = false
    var signOutCalled = false
    var getCurrentUserCalled = false
    var refreshSessionCalled = false
    
    var shouldFailSignIn = false
    var shouldFailSignUp = false
    var shouldFailSignOut = false
    var shouldFailGetCurrentUser = false
    var shouldFailRefreshSession = false
    
    var mockUser: User?
    var lastSignUpUsername: String?
    var lastSignUpEmail: String?
    
    func signIn(username: String, password: String) async throws -> User {
        signInCalled = true
        
        if shouldFailSignIn {
            throw AuthError.signInFailed
        }
        
        guard let user = mockUser else {
            throw AuthError.userNotFound
        }
        
        return user
    }
    
    func signUp(username: String, email: String, password: String, displayName: String?) async throws {
        signUpCalled = true
        lastSignUpUsername = username
        lastSignUpEmail = email
        
        if shouldFailSignUp {
            throw AuthError.signUpFailed
        }
    }
    
    func signOut() async throws {
        signOutCalled = true
        
        if shouldFailSignOut {
            throw AuthError.sessionInvalid
        }
    }
    
    func getCurrentUser() async throws -> User {
        getCurrentUserCalled = true
        
        if shouldFailGetCurrentUser {
            throw AuthError.userNotFound
        }
        
        guard let user = mockUser else {
            throw AuthError.userNotFound
        }
        
        return user
    }
    
    func refreshSession() async throws {
        refreshSessionCalled = true
        
        if shouldFailRefreshSession {
            throw AuthError.sessionInvalid
        }
    }
}

// Extend AuthError for testing
extension AuthError {
    var localizedDescription: String {
        switch self {
        case .signInFailed:
            return "Invalid credentials"
        case .signUpFailed:
            return "Sign up failed"
        case .sessionInvalid:
            return "Session invalid"
        case .userNotFound:
            return "User not found"
        }
    }
}