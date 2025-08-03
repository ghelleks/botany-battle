import Foundation
import Combine
import AuthenticationServices

enum AuthState: Equatable {
    case notAuthenticated
    case guest
    case gameCenter
    case appleID
}

enum AuthMethod: Equatable {
    case none
    case guest
    case gameCenter
    case appleID
}

@MainActor
class AuthFeature: NSObject, ObservableObject {
    @Published var authState: AuthState = .notAuthenticated
    @Published var isSigningIn = false
    @Published var errorMessage: String?
    
    private(set) var authMethod: AuthMethod = .none
    
    private let gameCenterService: GameCenterService
    private let userDefaultsService: UserDefaultsService
    private var authenticationTask: Task<Void, Never>?
    
    // For testing - allows injection of mock failure
    var shouldFailAppleIDAuth = false
    
    var isAuthenticated: Bool {
        authState != .notAuthenticated
    }
    
    var userDisplayName: String? {
        switch authState {
        case .guest:
            return "Guest"
        case .gameCenter:
            return gameCenterService.playerDisplayName
        case .appleID:
            return "Apple ID User" // In real implementation, would get from Apple ID
        case .notAuthenticated:
            return nil
        }
    }
    
    init(gameCenterService: GameCenterService = GameCenterService(), 
         userDefaultsService: UserDefaultsService = UserDefaultsService()) {
        self.gameCenterService = gameCenterService
        self.userDefaultsService = userDefaultsService
        super.init()
    }
    
    // MARK: - Authentication Methods
    
    func signInAsGuest() async {
        await performAuthentication {
            self.authState = .guest
            self.authMethod = .guest
            self.userDefaultsService.markFirstLaunchComplete()
            self.clearError()
        }
    }
    
    func signInWithGameCenter() async {
        await performAuthentication {
            let success = await self.gameCenterService.authenticate()
            
            if success {
                self.authState = .gameCenter
                self.authMethod = .gameCenter
                self.userDefaultsService.markFirstLaunchComplete()
                self.clearError()
            } else {
                self.authState = .notAuthenticated
                self.authMethod = .none
                self.errorMessage = self.gameCenterService.authenticationError?.localizedDescription ?? 
                                   GameConstants.ErrorMessages.gameCenterError
            }
        }
    }
    
    func signInWithAppleID() async {
        await performAuthentication {
            if self.shouldFailAppleIDAuth {
                self.errorMessage = "Apple ID authentication failed"
                return
            }
            
            // In a real implementation, this would use AuthenticationServices
            // For now, we'll simulate successful authentication
            self.authState = .appleID
            self.authMethod = .appleID
            self.userDefaultsService.markFirstLaunchComplete()
            self.clearError()
        }
    }
    
    func signOut() async {
        authenticationTask?.cancel()
        
        switch authState {
        case .gameCenter:
            gameCenterService.signOut()
        case .appleID, .guest, .notAuthenticated:
            break
        }
        
        authState = .notAuthenticated
        authMethod = .none
        clearError()
        isSigningIn = false
        
        print("🔓 User signed out")
    }
    
    func checkExistingAuthentication() async {
        // Check if Game Center is already authenticated
        if gameCenterService.isAuthenticated {
            authState = .gameCenter
            authMethod = .gameCenter
            return
        }
        
        // Could check for existing Apple ID authentication here
        // For now, we'll default to not authenticated
        authState = .notAuthenticated
        authMethod = .none
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func performAuthentication(_ authBlock: @escaping () async -> Void) async {
        // Cancel any existing authentication
        authenticationTask?.cancel()
        
        // Create new authentication task
        authenticationTask = Task {
            isSigningIn = true
            
            await authBlock()
            
            if !Task.isCancelled {
                isSigningIn = false
            }
        }
        
        await authenticationTask?.value
    }
}

// MARK: - Apple ID Authentication

extension AuthFeature: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func startAppleIDAuthentication() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, 
                               didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Handle successful Apple ID authentication
                authState = .appleID
                authMethod = .appleID
                userDefaultsService.markFirstLaunchComplete()
                clearError()
                isSigningIn = false
                print("✅ Apple ID authentication successful")
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, 
                               didCompleteWithError error: Error) {
        Task { @MainActor in
            authState = .notAuthenticated
            authMethod = .none
            errorMessage = error.localizedDescription
            isSigningIn = false
            print("❌ Apple ID authentication failed: \(error.localizedDescription)")
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // In a real app, this would return the appropriate window
        return ASPresentationAnchor()
    }
}

// MARK: - Convenience Methods

extension AuthFeature {
    var canUseGameCenter: Bool {
        return true // In real implementation, check device capabilities
    }
    
    var canUseAppleID: Bool {
        return true // In real implementation, check iOS version and availability
    }
    
    var isGuest: Bool {
        return authState == .guest
    }
    
    var hasGameCenterAccess: Bool {
        return authState == .gameCenter
    }
    
    var hasCloudSync: Bool {
        return authState != .guest
    }
    
    var hasMultiplayerAccess: Bool {
        return authState == .gameCenter
    }
}