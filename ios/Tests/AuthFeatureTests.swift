import XCTest
import ComposableArchitecture
@testable import BotanyBattle

@MainActor
final class AuthFeatureTests: XCTestCase {
    
    func testLoginFormUpdates() async {
        let store = TestStore(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        )
        
        await store.send(.updateLoginForm(username: "testuser", password: nil)) {
            $0.loginForm.username = "testuser"
        }
        
        await store.send(.updateLoginForm(username: nil, password: "testpass")) {
            $0.loginForm.password = "testpass"
        }
        
        XCTAssertTrue(store.state.loginForm.isValid)
    }
    
    func testSignupFormUpdates() async {
        let store = TestStore(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        )
        
        await store.send(.updateSignupForm(username: "testuser", email: nil, password: nil, confirmPassword: nil, displayName: nil)) {
            $0.signupForm.username = "testuser"
        }
        
        await store.send(.updateSignupForm(username: nil, email: "test@example.com", password: nil, confirmPassword: nil, displayName: nil)) {
            $0.signupForm.email = "test@example.com"
        }
        
        await store.send(.updateSignupForm(username: nil, email: nil, password: "password123", confirmPassword: nil, displayName: nil)) {
            $0.signupForm.password = "password123"
        }
        
        await store.send(.updateSignupForm(username: nil, email: nil, password: nil, confirmPassword: "password123", displayName: nil)) {
            $0.signupForm.confirmPassword = "password123"
        }
        
        XCTAssertTrue(store.state.signupForm.isValid)
    }
    
    func testClearError() async {
        let store = TestStore(
            initialState: AuthFeature.State(error: "Test error"),
            reducer: { AuthFeature() }
        )
        
        await store.send(.clearError) {
            $0.error = nil
        }
    }
}