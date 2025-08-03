import XCTest
import Combine
@testable import BotanyBattle

@MainActor
final class AuthFeatureTests: XCTestCase {
    
    var sut: AuthFeature!
    var mockGameCenterService: MockGameCenterService!
    var mockUserDefaultsService: MockUserDefaultsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        mockGameCenterService = MockGameCenterService()
        mockUserDefaultsService = MockUserDefaultsService()
        sut = AuthFeature(
            gameCenterService: mockGameCenterService,
            userDefaultsService: mockUserDefaultsService
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockGameCenterService = nil
        mockUserDefaultsService = nil
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Given & When & Then
        XCTAssertEqual(sut.authState, .notAuthenticated)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertFalse(sut.isSigningIn)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.authMethod, .none)
    }
    
    // MARK: - Guest Authentication Tests
    
    func testSignInAsGuest_Success() async {
        // Given
        XCTAssertEqual(sut.authState, .notAuthenticated)
        
        // When
        await sut.signInAsGuest()
        
        // Then
        XCTAssertEqual(sut.authState, .guest)
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .guest)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(mockUserDefaultsService.isFirstLaunch)
    }
    
    func testSignInAsGuest_UpdatesUserDefaults() async {
        // Given
        XCTAssertTrue(mockUserDefaultsService.isFirstLaunch)
        
        // When
        await sut.signInAsGuest()
        
        // Then
        XCTAssertFalse(mockUserDefaultsService.isFirstLaunch)
        XCTAssertEqual(mockUserDefaultsService.markFirstLaunchCompleteCallCount, 1)
    }
    
    // MARK: - Game Center Authentication Tests
    
    func testSignInWithGameCenter_Success() async {
        // Given
        mockGameCenterService.shouldSucceedAuthentication = true
        
        // When
        await sut.signInWithGameCenter()
        
        // Then
        XCTAssertEqual(sut.authState, .gameCenter)
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .gameCenter)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(mockGameCenterService.authenticateCalled)
    }
    
    func testSignInWithGameCenter_Failure() async {
        // Given
        mockGameCenterService.shouldSucceedAuthentication = false
        mockGameCenterService.authenticationError = NSError(
            domain: "GameKitErrorDomain", 
            code: 1, 
            userInfo: [NSLocalizedDescriptionKey: "Authentication failed"]
        )
        
        // When
        await sut.signInWithGameCenter()
        
        // Then
        XCTAssertEqual(sut.authState, .notAuthenticated)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .none)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.errorMessage, "Authentication failed")
    }
    
    func testSignInWithGameCenter_ShowsLoadingState() async {
        // Given
        let expectation = XCTestExpectation(description: "Loading state observed")
        mockGameCenterService.shouldSucceedAuthentication = true
        mockGameCenterService.authenticationDelay = 0.1
        
        var loadingStates: [Bool] = []
        sut.$isSigningIn
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await sut.signInWithGameCenter()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(loadingStates[0], false) // Initial state
        XCTAssertEqual(loadingStates[1], true)  // Loading state
    }
    
    // MARK: - Apple ID Authentication Tests
    
    func testSignInWithAppleID_Success() async {
        // Given
        // Apple ID authentication will be mocked to succeed
        
        // When
        await sut.signInWithAppleID()
        
        // Then
        XCTAssertEqual(sut.authState, .appleID)
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .appleID)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSignInWithAppleID_Failure() async {
        // Given
        sut.shouldFailAppleIDAuth = true
        
        // When
        await sut.signInWithAppleID()
        
        // Then
        XCTAssertEqual(sut.authState, .notAuthenticated)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOut_FromGameCenter() async {
        // Given
        await sut.signInWithGameCenter()
        XCTAssertTrue(sut.isAuthenticated)
        
        // When
        await sut.signOut()
        
        // Then
        XCTAssertEqual(sut.authState, .notAuthenticated)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .none)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSignOut_FromGuest() async {
        // Given
        await sut.signInAsGuest()
        XCTAssertTrue(sut.isAuthenticated)
        
        // When
        await sut.signOut()
        
        // Then
        XCTAssertEqual(sut.authState, .notAuthenticated)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .none)
    }
    
    // MARK: - Auto-Authentication Tests
    
    func testCheckExistingAuthentication_GameCenterAlreadyAuthenticated() async {
        // Given
        mockGameCenterService.isAuthenticated = true
        
        // When
        await sut.checkExistingAuthentication()
        
        // Then
        XCTAssertEqual(sut.authState, .gameCenter)
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .gameCenter)
    }
    
    func testCheckExistingAuthentication_NoExistingAuth() async {
        // Given
        mockGameCenterService.isAuthenticated = false
        
        // When
        await sut.checkExistingAuthentication()
        
        // Then
        XCTAssertEqual(sut.authState, .notAuthenticated)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.authMethod, .none)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError() {
        // Given
        sut.errorMessage = "Test error"
        XCTAssertNotNil(sut.errorMessage)
        
        // When
        sut.clearError()
        
        // Then
        XCTAssertNil(sut.errorMessage)
    }
    
    func testMultipleSignInAttempts_CancelsExisting() async {
        // Given
        mockGameCenterService.authenticationDelay = 0.2
        
        // When
        async let firstAttempt = sut.signInWithGameCenter()
        async let secondAttempt = sut.signInAsGuest()
        
        let _ = await [firstAttempt, secondAttempt]
        
        // Then
        XCTAssertEqual(sut.authState, .guest) // Second attempt should win
        XCTAssertFalse(sut.isSigningIn)
    }
    
    // MARK: - State Publisher Tests
    
    func testAuthStatePublisher_EmitsChanges() async {
        // Given
        let expectation = XCTestExpectation(description: "Auth state changes")
        expectation.expectedFulfillmentCount = 2
        
        var authStates: [AuthState] = []
        sut.$authState
            .sink { state in
                authStates.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        await sut.signInAsGuest()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(authStates[0], .notAuthenticated)
        XCTAssertEqual(authStates[1], .guest)
    }
    
    // MARK: - User Info Tests
    
    func testUserDisplayName_GameCenter() async {
        // Given
        mockGameCenterService.playerDisplayName = "TestPlayer"
        await sut.signInWithGameCenter()
        
        // When
        let displayName = sut.userDisplayName
        
        // Then
        XCTAssertEqual(displayName, "TestPlayer")
    }
    
    func testUserDisplayName_Guest() async {
        // Given
        await sut.signInAsGuest()
        
        // When
        let displayName = sut.userDisplayName
        
        // Then
        XCTAssertEqual(displayName, "Guest")
    }
    
    // MARK: - Performance Tests
    
    func testAuthenticationPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Auth performance")
            
            Task {
                await sut.signInAsGuest()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Mock Classes

@MainActor
class MockGameCenterService: ObservableObject {
    @Published var isAuthenticated = false
    var authenticationError: Error?
    var shouldSucceedAuthentication = true
    var authenticationDelay: TimeInterval = 0
    var authenticateCalled = false
    var playerDisplayName: String?
    
    func authenticate() async -> Bool {
        authenticateCalled = true
        
        if authenticationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(authenticationDelay * 1_000_000_000))
        }
        
        if shouldSucceedAuthentication {
            isAuthenticated = true
            return true
        } else {
            return false
        }
    }
    
    func signOut() {
        isAuthenticated = false
    }
}

class MockUserDefaultsService: ObservableObject {
    var isFirstLaunch = true
    var markFirstLaunchCompleteCallCount = 0
    
    func markFirstLaunchComplete() {
        isFirstLaunch = false
        markFirstLaunchCompleteCallCount += 1
    }
}